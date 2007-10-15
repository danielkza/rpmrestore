#!/usr/bin/perl
###############################################################################
#   rpmrestore.pl
#
#    Copyright (C) 2006 by Eric Gerbier
#    Bug reports to: gerbier@users.sourceforge.net
#    $Id$
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
###############################################################################
use strict;
use warnings;

use English qw(-no_match_vars);

use Getopt::Long;    # arg analysis
use Pod::Usage;      # man page
use POSIX qw(strftime);
use Digest::MD5;
use File::stat;

use Data::Dumper;    # debug

my $fh_log;          # file handle to log file

###############################################################################
{

	# to avoid a global variable
	my $nb_change_made = 0;

	# is called at end of operations to display some stats
	sub get_nb_change_made() {
		return $nb_change_made;
	}

	# is used in ask subroutine to count changes
	sub add_change() {
		$nb_change_made++;
		return;
	}
}

# whe should use only this subroutines, and no direct call to print
###############################################################################
# change debug subroutine by pointing to other anonymous sub
# this way seems better than previous one as
# - it does not need any "global" verbose variable
# - it suppress any verbose test (quicker)
sub init_debug($) {
	my $verbose = shift @_;

	# to avoid error messages
	no warnings 'redefine';

	if ($verbose) {
		*debug = sub { my $text = $_[0]; print "debug $text\n"; };
	}
	else {
		*debug = sub { };
	}

	use warnings 'all';
	return;
}
###############################################################################
# display a warning message
sub warning($) {
	my $text = shift @_;
	warn "WARNING $text\n";
	return;
}
###############################################################################
# display a "normal" message
sub info($) {
	my $text = shift @_;
	print "$text\n";
	return;
}
###############################################################################
# input : time format
# output : concatenated date/time
sub touch_fmt($) {
	my $time_fmt = shift @_;

	return strftime '%Y%m%d%H%M%S', localtime $time_fmt;
}
###############################################################################
# get all info about files from a package
# and populate a hash of hash
sub get_rpm_infos($) {
	my $package = shift @_;

	# use space as field separator : see below
	# md5 is the last field because it may not exists (directories)
	my @info =
`rpm -q --queryformat "[%6.6{FILEMODES:octal} %{FILEUSERNAME} %{FILEGROUPNAME} %{FILEMTIMES} %{FILESIZES} %{FILENAMES} %{FILEMD5S}\n]" $package `;

	my %h;
	my $space = q{ };
	foreach my $elem (@info) {
		my ( $mode, $user, $group, $mtime, $size, $name, $md5 ) =
		  split /$space/, $elem;
		chomp $md5;
		my %h2 = (
			mode  => $mode,
			user  => $user,
			group => $group,
			mtime => $mtime,
			size  => $size,
			md5   => $md5,
		);
		$h{$name} = \%h2;
	}
	return %h;
}
###############################################################################
# just print a line on current version
sub print_version($) {
	my $version = shift @_;
	info("$0 version $version");
	return;
}
###############################################################################
# this sub will select interactive/batch/dryrun mode
sub ask($$$$$$$) {
	my $opt_dry_run = shift @_;    # dryrun option
	my $opt_batch   = shift @_;    # batch option
	my $action      = shift @_;    # sub closure
	my $filename    = shift @_;    # file name
	my $type        = shift @_;    # parameter name
	my $orig        = shift @_;    # original value
	my $current     = shift @_;    # current value

	display( $filename, $type, $orig, $current );

	if ( !$opt_dry_run ) {

		# "change" mode
		if ( !$opt_batch ) {

			# interactive mode
			# ask to confirm
			print 'want to restore (y/n) ? ';
			my $rep = lc <>;
			chomp $rep;

			return unless ( $rep eq 'y' );
		}

		# apply changes
		&{$action};
		info("change $type on $filename");
		writelog( $filename, $type, $orig, $current );
		add_change();
	}
	else {
		debug('dryrun mode : no changes');
	}
	return;
}
###############################################################################
# just show the differences
sub display($$$$) {
	my $filename = shift @_;    # file name
	my $param    = shift @_;    # parameter name
	my $orig     = shift @_;    # initial value (rpm)
	my $current  = shift @_;    # current value

	info("$filename $param orig $orig current $current");
	return;
}
###############################################################################
# write on log file for rollback
# this is also read by rollback subroutine
sub writelog($$$$) {
	my $filename = shift @_;
	my $param    = shift @_;
	my $orig     = shift @_;
	my $current  = shift @_;

	print {$fh_log} "$filename $param from $current to $orig\n" if ($fh_log);
	return;
}
###############################################################################
# file info are numeric in a computer
# but human prefer another print
# we also print the 2 forms
# raw_val is numeric
# human_val is decoded
sub set_val($$) {
	my $raw_val   = shift @_;
	my $human_val = shift @_;

	return "$raw_val ($human_val)";
}
###############################################################################
sub get_val($) {
	my $val = shift @_;

	if ( $val =~ m/^(\d+) \(([^)])/ ) {
		my $raw_val   = $1;
		my $human_val = $2;
		return ( $raw_val, $human_val );
	}
	else {
		return;
	}
}
###############################################################################
sub rollback_user($$$$$$$) {
	my $opt_batch  = shift @_;
	my $opt_dryrun = shift @_;
	my $fic        = shift @_;
	my $line       = shift @_;
	my $to         = shift @_;
	my $from       = shift @_;
	my $cur_stat   = shift @_;

	my $nb_rollback = 0;

	my ( $to_uid, $to_user ) = get_val($to);

	# check log format
	if ( defined $to_uid ) {

		# check if current value is same than $to

		my $cur_uid = $cur_stat->uid();
		if ( $cur_uid != $to_uid ) {
			warning(
"current uid $cur_uid does not match rollback value : $to_uid (line $line)"
			);
		}
		else {
			my ( $from_uid, $from_user ) = get_val($from);

			# check log format
			if ( defined $from_uid ) {
				my $action = sub { change_user( $from_uid, $fic ); };
				ask( $opt_dryrun, $opt_batch, $action, $fic, 'user', $from,
					$to );
				$nb_rollback = 1;
			}
			else {
				warning("bad log format for 'from' field : $from (line $line)");
			}
		}
	}
	else {
		warning("bad log format for 'to' field : $to (line $line)");
	}
	return $nb_rollback;
}
###############################################################################
sub rollback_group($$$$$$$) {
	my $opt_batch  = shift @_;
	my $opt_dryrun = shift @_;
	my $fic        = shift @_;
	my $line       = shift @_;
	my $to         = shift @_;
	my $from       = shift @_;
	my $cur_stat   = shift @_;

	my $nb_rollback = 0;
	my ( $to_gid, $to_group ) = get_val($to);

	# check log format
	if ( defined $to_gid ) {

		# check if current value is same than $to

		my $cur_gid = $cur_stat->gid();
		if ( $cur_gid != $to_gid ) {
			warning(
"current gid $cur_gid does not match rollback value : $to_gid (line $line)"
			);
		}
		else {
			my ( $from_gid, $from_group ) = get_val($from);

			# check log format
			if ( defined $from_gid ) {
				my $action = sub { change_group( $from_gid, $fic ); };
				ask( $opt_dryrun, $opt_batch, $action, $fic, 'group', $from,
					$to );
				$nb_rollback++;
			}
			else {
				warning("bad log format for 'from' field : $from (line $line)");
			}
		}
	}
	else {
		warning("bad log format for 'to' field : $to (line $line)");
	}

	return $nb_rollback;
}
###############################################################################
sub rollback_mode($$$$$$$) {
	my $opt_batch  = shift @_;
	my $opt_dryrun = shift @_;
	my $fic        = shift @_;
	my $line       = shift @_;
	my $to         = shift @_;
	my $from       = shift @_;
	my $cur_stat   = shift @_;

	my $nb_rollback = 0;
	my $cur_mode    = $cur_stat->mode();

	my $to_mode = $to;
	if ( $to_mode != $cur_mode ) {
		warning(
"current mode $cur_mode does not match rollback value : $to_mode (line $line)"
		);
	}
	else {
		my $action = sub { change_mode( $from, $fic ); };
		ask( $opt_dryrun, $opt_batch, $action, $fic, 'mode', $from, $to );
		$nb_rollback++;
	}

	return $nb_rollback;
}
###############################################################################
sub rollback_time($$$$$$$) {
	my $opt_batch  = shift @_;
	my $opt_dryrun = shift @_;
	my $fic        = shift @_;
	my $line       = shift @_;
	my $to         = shift @_;
	my $from       = shift @_;
	my $cur_stat   = shift @_;

	my $nb_rollback = 0;
	my ( $to_epoch, $to_mtime ) = get_val($to);

	# check log format
	if ( defined $to_epoch ) {

		# check if current value is same than $to

		my $cur_epoch = $cur_stat->mtime();
		if ( $cur_epoch != $to_epoch ) {
			warning(
"current mtime $cur_epoch does not match rollback value : $to_epoch (line $line)"
			);
		}
		else {
			my ( $from_epoch, $from_mtime ) = get_val($from);

			# check log format
			if ( defined $from_epoch ) {
				my $action = sub { change_time( $from_epoch, $fic ); };
				ask( $opt_dryrun, $opt_batch, $action, $fic, 'mtime', $from,
					$to );
				$nb_rollback = 1;
			}
			else {
				warning("bad log format for 'from' field : $from (line $line)");
			}
		}
	}
	else {
		warning("bad log format for 'to' field : $to (line $line)");
	}

	return $nb_rollback;
}
###############################################################################
# use log file to revert change
# it looks very similar to main code
sub rollback($$$$$$$) {
	my $log        = shift @_;
	my $opt_batch  = shift @_;
	my $opt_dryrun = shift @_;
	my $opt_user   = shift @_;
	my $opt_group  = shift @_;
	my $opt_mode   = shift @_;
	my $opt_time   = shift @_;

	open( my $fh_roll, '<', $log )
	  or die "can not open rollback file $log : $!\n";

	info("rollaback from $log");

	my $line        = 0;
	my $nb_rollback = 0;
  ROLLBACK: while (<$fh_roll>) {
		$line++;
		chomp;
		if (m/^(\S+) (\w+) from (.*) to (.*)/) {
			my ( $fic, $param, $from, $to );
			$fic   = $1;
			$param = $2;
			$from  = $3;
			$to    = $4;

			if ( !-e $fic ) {
				warning("file $fic is missing");
				next ROLLBACK;
			}

			# get current values
			# to check if current value is equal to $to ?
			my $cur_stat = stat $fic;

			# param will be restored to $from

			if ( $param eq 'user' ) {
				if ($opt_user) {
					$nb_rollback +=
					  rollback_user( $opt_batch, $opt_dryrun, $fic, $line, $to,
						$from, $cur_stat );
				}
			}
			elsif ( $param eq 'group' ) {
				if ($opt_group) {
					$nb_rollback +=
					  rollback_group( $opt_batch, $opt_dryrun, $fic, $line, $to,
						$from, $cur_stat );
				}
			}
			elsif ( $param eq 'mtime' ) {
				if ($opt_time) {
					$nb_rollback +=
					  rollback_time( $opt_batch, $opt_dryrun, $fic, $line, $to,
						$from, $cur_stat );
				}
			}
			elsif ( $param eq 'mode' ) {
				if ($opt_mode) {
					$nb_rollback +=
					  rollback_mode( $opt_batch, $opt_dryrun, $fic, $line, $to,
						$from, $cur_stat );

				}
			}
			else {
				warning("bad parameter $param on line $line : $_");
			}
		}
		else {
			warning("bad log line $line : $_");
		}
	}
	close $fh_roll;

	# stats
	info "rollback $nb_rollback attributes";
	info( get_nb_change_made() . ' changes applied' );

	return;
}
################################################################################
# read all existing rc file from general to local :
# host, home, local directory
sub readrc($) {

	my $rh_list = shift @_;    # list of available parameters

	# can use local rc file, home rc file, host rc file
	my @list_rc =
	  ( '/etc/rpmrestorerc', $ENV{HOME} . '/.rpmrestorerc', '.rpmrestorerc', );

	foreach my $rcfile (@list_rc) {

		if ( -f $rcfile ) {

			if ( open( my $fh_rc, '<', $rcfile ) ) {

				# perl cookbook, 8.16
				my $line = 1;
			  RC: while (<$fh_rc>) {
					chomp;
					s/#.*//;     # comments
					s/^\s+//;    # skip spaces
					s/\s+$//;
					next RC unless length;
					my ( $key, $value ) = split /\s*=\s*/, $_, 2;
					if ( defined $key ) {
						if ( exists $rh_list->{$key} ) {
							${ $rh_list->{$key} } = $value;
							init_debug($value) if ( $key eq 'verbose' );
							debug(
"rcfile : found $key parameter with $value value"
							);
						}
						else {
							warning(
"bad $key parameter in line $line in $rcfile file"
							);
						}
					}
					else {
						warning("bad line $line in $rcfile file");
					}
					$line++;
				}
				close $fh_rc;
			}
			else {
				warning("can not open rcfile $rcfile : $!");
			}
		}
		else {
			debug("no rcfile $rcfile found");
		}
	}
	return;
}
###############################################################################
sub change_user($$) {
	my $new_uid  = shift @_;
	my $filename = shift @_;

	chown $new_uid, -1, $filename;
	return;
}
###############################################################################
sub change_group($$) {
	my $new_gid  = shift @_;
	my $filename = shift @_;

	chown -1, $new_gid, $filename;
	return;
}
###############################################################################
sub change_mode($$) {
	my $new_mode = shift @_;
	my $filename = shift @_;

	chmod oct($new_mode), $filename;
	return;
}
###############################################################################
sub change_time($$) {
	my $new_time = shift @_;
	my $filename = shift @_;

	# use utime to rewrite in full perl
	my $st    = stat $filename;
	my $atime = $st->atime();

	utime $atime, $new_time, ($filename);
	return;
}
###############################################################################
#                             main
###############################################################################
my $version = '1.2';

$OUTPUT_AUTOFLUSH = 1;

my $opt_verbose = 0;
my $opt_help;
my $opt_man;
my $opt_version;
my $opt_batch;
my $opt_dryrun;
my $opt_log;
my $opt_rollback;

my $opt_file;
my $opt_package;

my $opt_flag_all;
my $opt_flag_mode;
my $opt_flag_time;
my $opt_flag_user;
my $opt_flag_group;
my $opt_flag_size;
my $opt_flag_md5;

# list of  parameter available in rcfile
# and ref to opt variables
my %opt = (
	'help'     => \$opt_help,
	'man'      => \$opt_man,
	'verbose'  => \$opt_verbose,
	'file'     => \$opt_file,
	'package'  => \$opt_package,
	'version'  => \$opt_version,
	'batch'    => \$opt_batch,
	'dry-run'  => \$opt_dryrun,
	'all'      => \$opt_flag_all,
	'user'     => \$opt_flag_user,
	'group'    => \$opt_flag_group,
	'mode'     => \$opt_flag_mode,
	'time'     => \$opt_flag_time,
	'size'     => \$opt_flag_size,
	'md5'      => \$opt_flag_md5,
	'log'      => \$opt_log,
	'rollback' => \$opt_rollback,
);

# set debug before any code
init_debug($opt_verbose);

# get options from optionnal rcfile
readrc( \%opt );

Getopt::Long::Configure('no_ignore_case');
GetOptions(
	\%opt,       'help|?',  'man',       'file=s',
	'package=s', 'verbose', 'version|V', 'batch',
	'dry-run|n', 'all',     'user!',     'group!',
	'mode!',     'time!',   'size!',     'md5!',
	'log=s',     'rollback=s',
) or pod2usage(2);

# set debug from argument line
init_debug($opt_verbose);

if ($opt_help) {
	pod2usage(1);
}
elsif ($opt_man) {
	pod2usage( -verbose => 2 );
}
elsif ($opt_version) {
	print_version($version);
	exit;
}

# if no attributes defined, apply on all
if (   ( !defined $opt_flag_user )
	&& ( !defined $opt_flag_group )
	&& ( !defined $opt_flag_mode )
	&& ( !defined $opt_flag_time )
	&& ( !defined $opt_flag_size )
	&& ( !defined $opt_flag_md5 ) )
{
	$opt_flag_all = 1;
}

if ($opt_flag_all) {

	# just set undefined attributes to allow negative attribute (-all -notime)
	$opt_flag_user  = ( !defined $opt_flag_user )  ? 1 : $opt_flag_user;
	$opt_flag_group = ( !defined $opt_flag_group ) ? 1 : $opt_flag_group;
	$opt_flag_mode  = ( !defined $opt_flag_mode )  ? 1 : $opt_flag_mode;
	$opt_flag_time  = ( !defined $opt_flag_time )  ? 1 : $opt_flag_time;
	$opt_flag_size  = ( !defined $opt_flag_size )  ? 1 : $opt_flag_size;
	$opt_flag_md5   = ( !defined $opt_flag_md5 )   ? 1 : $opt_flag_md5;
}

# test for superuser
if ( ( !$opt_dryrun ) and ( $EFFECTIVE_USER_ID != 0 ) ) {
	warning('do not run on superuser : forced to dry-run');
	$opt_dryrun = 1;
}

if ($opt_verbose) {
	debug('dump options');
	print Dumper( \%opt );
}

if ($opt_log) {

	# open log file
	my $open_mode;
	if ( -f $opt_log ) {
		$open_mode = '>>';
		info("log on existing file $opt_log");
	}
	else {
		$open_mode = '>';
		debug("log on new file $opt_log");
	}
	open( $fh_log, $open_mode, $opt_log )
	  or warning("can not open log file $opt_log : $!");
}

if ($opt_rollback) {

	rollback(
		$opt_rollback,   $opt_batch,     $opt_dryrun, $opt_flag_user,
		$opt_flag_group, $opt_flag_mode, $opt_flag_time
	);

	exit;
}

if ($opt_file) {

	# check if file exists
	if ( -e $opt_file ) {

		# get rpm from file
		$opt_package = `rpm -qf --queryformat "%{NAME}" $opt_file `;

	   # test result
	   # localisation will prevent to test for keyword as :
	   #if ( $opt_package =~ m/is not owned by any package/) {
	   # so another way is : a good answer is only one package, so only one word
		my @rep = split /\s/, $opt_package;
		if ( scalar(@rep) == 1 ) {
			info("package is $opt_package");
		}
		else {
			pod2usage("$opt_package is not owned by any package");
		}
	}
	else {
		pod2usage("can not find $opt_file file");
	}
}

if ( !$opt_package ) {
	pod2usage('missing rpm package name');
}

# check if package exists
debug("test if package $opt_package exists");
system "rpm -q $opt_package > /dev/null";
if ( $CHILD_ERROR != 0 ) {
	pod2usage("$opt_package : package does not exists");
}

# LC_ALL is set to POSIX by setlocale at top of program
# to avoid any localisation problem with test in CHANGE loop
my @check = `export LC_ALL=POSIX; rpm -V $opt_package`;

print Dumper(@check) if ($opt_verbose);

if ( !@check ) {
	info('0 changes detected : exit');
	exit;
}
my %infos = get_rpm_infos($opt_package);

#print Dumper(%infos);
# we can act on some changes :
# U user
# G group
# T mtime
# M mode

my $nb_changes = 0;
CHANGE: foreach my $elem (@check) {

	# this search depends upon localisation
	next CHANGE if ( $elem =~ m/^missing/ );
	next CHANGE if ( $elem =~ m/^Unsatisfied/ );

   # rpm -V output can have 2 or 3 fields :
   # S.?....T c /etc/afick.conf
   # missing  c /etc/logrotate.d/afick
   # S.5....T   /usr/bin/afick.pl
   # S.5....T g /var/lib/afick/archive
   # ? is get when rpmrestore does not have any perm to the file (user not root)
	my ( $change, $config, $filename ) = split /\s+/, $elem;

	if ( !$filename ) {
		$filename = $config;
	}
	if ($opt_file) {
		next CHANGE if ( $filename ne $opt_file );
	}
	debug("change=$change filename=$filename");

	# get current info
	my $cur_stat = stat $filename;

	# rpm info
	my $rpm_info = $infos{$filename};

	if ( ($opt_flag_user) and ( $change =~ m/U/ ) ) {
		my $rpm_user = $rpm_info->{user};
		my $rpm_uid  = getpwnam $rpm_user;
		my $uid      = $cur_stat->uid();
		my $user     = getpwuid $uid;

		my $action = sub { change_user( $rpm_uid, $filename ); };
		ask(
			$opt_dryrun, $opt_batch, $action, $filename, 'user',
			set_val( $rpm_uid, $rpm_user ),
			set_val( $uid,     $user )
		);
		$nb_changes++;
	}
	if ( ($opt_flag_group) and ( $change =~ m/G/ ) ) {
		my $rpm_group = $rpm_info->{group};
		my $rpm_gid   = getgrnam $rpm_group;
		my $gid       = $cur_stat->gid();
		my $group     = getgrgid $gid;

		my $action = sub { change_group( $rpm_gid, $filename ); };
		ask(
			$opt_dryrun, $opt_batch, $action, $filename, 'group',
			set_val( $rpm_gid, $rpm_group ),
			set_val( $gid,     $group )
		);
		$nb_changes++;
	}
	if ( ($opt_flag_time) and ( $change =~ m/T/ ) ) {
		my $rpm_mtime   = $rpm_info->{mtime};
		my $rpm_h_mtime = touch_fmt($rpm_mtime);
		my $cur_mtime   = $cur_stat->mtime();
		my $cur_h_mtime = touch_fmt($cur_mtime);

		my $action = sub { change_time( $rpm_mtime, $filename ); };
		ask(
			$opt_dryrun, $opt_batch, $action, $filename, 'mtime',
			set_val( $rpm_mtime, $rpm_h_mtime ),
			set_val( $cur_mtime, $cur_h_mtime )
		);
		$nb_changes++;
	}
	if ( ($opt_flag_mode) and ( $change =~ m/M/ ) ) {
		my $rpm_mode = $rpm_info->{mode};
		my $h_mode = sprintf '%lo', $cur_stat->mode();

		my $action = sub { change_mode( $rpm_mode, $filename ); };
		ask( $opt_dryrun, $opt_batch, $action, $filename, 'mode', $rpm_mode,
			$h_mode );
		$nb_changes++;
	}
	if ( ($opt_flag_size) and ( $change =~ m/S/ ) ) {
		my $rpm_size = $rpm_info->{size};
		my $size     = $cur_stat->size();

		display( $filename, 'size', $rpm_size, $size );

		# no fix action on this parameter
		$nb_changes++;
	}
	if ( ($opt_flag_md5) and ( $change =~ m/5/ ) ) {
		debug('md5');
		my $rpm_md5 = $rpm_info->{md5};

		my $ctx = Digest::MD5->new;

		my $cur_md5;
		if ( open( my $fh_fic, '<', $filename ) ) {
			$ctx->addfile($fh_fic);
			$cur_md5 = $ctx->hexdigest();
			close $fh_fic;
		}
		else {
			warning("can not open $filename for md5 : $!");
			$cur_md5 = q{};
		}

		display( $filename, 'md5', $rpm_md5, $cur_md5 );

		# no fix action on this parameter
		$nb_changes++;
	}
}
close $fh_log if ($opt_log);

# stats
info("$nb_changes changes detected");
info( get_nb_change_made() . ' changes applied' );

__END__

=head1 NAME

rpmrestore.pl - restore attributes from rpm database

=head1 DESCRIPTION

The rpm database store user, group, time, mode for all files,
and offer a command to display the changes between install state (database)
and current disk state. rpmrestore will help you to restore install attributes

=head1 SYNOPSIS

rpmrestore [options] [ target ]

target:

   -package package	apply on designed package
   -file filename	apply on designed file
   -rollback logfile	restore attributes from logfile (written by -log)

options:

   -help		brief help message
   -man			full documentation
   -V, --version	print version

   -verbose		verbose
   -batch		batch mode (ask no questions)
   -n, --dry-run	do not perform any change
   -log logfile		log action in logfile

  -all		apply on all attributes
  -user		apply on user
  -group	apply on group
  -mode		apply on mode
  -time		apply on mtime
  -size		apply on size (just display)
  -md5		apply on md5 (just display)

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Print the manual page and exits.

=item B<-version>

Print the program release and exit.

=item B<-verbose>

The program works and print debugging messages.

=item B<-batch>

The program works without interactive questions (the default mode is interactive)

=item B<-dryrun>

The program just show the changes but not perform any restore

=item B<-log>

The program write the changes in designed log file. This file can be used for rollback.

=item B<-package>

The program works on designed installed rpm package.

=item B<-file>

The program works on designed file, which should be a part from a rpm package.

=item B<-rollback>

The program works from designed log file, and rollback (revert) the changes.

=item B<-all>

If no attribute are specified, the program work on all, as if this flag is set.
It is the same as  : -user -group -mode -time -size -md5

=item B<-user>

This is the owner attribute

=item B<-group>

This is the group attribute

=item B<-mode>

This is the file permissions : read-write-execute for user, group, other

=item B<-time>

This attribute is the date of last changes on file.

=item B<-size>

This is the file size attribute. This is a "read-only" attribute : it can not be restored by the program.

=item B<-md5>

md5 is a checksum (a kind of fingerprint) : if the file content is changed, the checksum will change too.
A difference on this attribute means the file content was changed. This is a "read-only" attribute : 
it can not be restored by the program.

=back

=head1 USE

the rpm command to control changes 
 
rpm -V rpm

same effect (just display) but more detailed (display values)

rpmrestore.pl -n -package rpm

interactive change mode, only on time attribute

rpmrestore.pl -time -package rpm

interactive change mode, on all attributes except time attribute

rpmrestore.pl -all -notime -package rpm

batch change mode (DANGEROUS) on mode attribute with log file

rpmrestore.pl -batch -package rpm -log /tmp/log

interactive change of mode attribute on file /etc/motd

rpmrestore.pl -mode -file /etc/motd

interactive rollback from /tmp/log

rpmrestore.pl -rollback /tmp/log

batch rollback user changes from /tmp/log

rpmrestore.pl -batch -user -rollback /tmp/log

=head1 CONFIGURATION

the program can read rcfile if some exists.
it will load in order 

/etc/rpmrestorerc

~/.rpmrestorerc

.rpmrestorerc

In this file, 

# are comments, 

and parameters are stored in the following format :
parameter = value

example :

verbose = 0

dry-run = 1

batch = 0

=head1 NOTES

you should be superuser to restore attributes, other users can only check changes

on batch mode, we recommend to use log file

=head1 DIAGNOSTICS

(to be filled)

=head1 EXIT STATUS

the program should allways exit with code 0

=head1 DEPENDENCIES

this program uses "standard" perl modules (distributed with perl core) : 
POSIX
Digest::MD5
English
Getopt::Long
Pod::Usage
POSIX
Digest::MD5
File::stat
Data::Dumper

=head1 INCOMPATIBILITIES

none is known

=head1 BUGS AND LIMITATIONS

this program can revert changes on user, group, time, properties,
but not on size and md5 : it can only show the differences

=head1 SEE ALSO

=for man
\fIrpm\fR\|(1) for rpm call

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2006 by Eric Gerbier
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=head1 AUTHOR

Eric Gerbier

you can report any bug or suggest to gerbier@users.sourceforge.net

=cut
