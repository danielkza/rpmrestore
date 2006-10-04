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

use Getopt::Long;    # arg analysis
use Pod::Usage;
use POSIX qw(strftime);

use Data::Dumper;

my $fh_log;

###############################################################################
# get all info about files from a package
# and populate a hash of hash
sub get_rpm_infos($) {
	my $package = shift(@_);
	my @info =
`rpm -q --queryformat "[%6.6{FILEMODES:octal} %{FILEUSERNAME} %{FILEGROUPNAME} %{FILEMTIMES} %{FILESIZES} %{FILENAMES}\n]" $package `;

	my %h;
	foreach my $elem (@info) {
		my ( $mode, $user, $group, $mtime, $size, $name ) = split ' ', $elem;
		my %h2 =
		  ( mode => $mode, user => $user, group => $group, mtime => $mtime, size => $size );
		$h{$name} = \%h2;
	}
	return %h;
}
###############################################################################
sub print_version($) {
	my $version = shift(@_);
	print "$0 version $version\n";
	return;
}
###############################################################################
sub ask($$$$$$$) {
	my $opt_dry_run = shift(@_);
	my $opt_batch = shift(@_);
	my $action = shift(@_);		# sub closure
	my $filename = shift(@_);
	my $type = shift(@_);
	my $orig = shift(@_);
	my $current = shift(@_);

	display($filename, $type, $orig, $current);

	if ( !$opt_dry_run ) {
		if ( ! $opt_batch ) {
			# interactive mode
			# ask to confirm
			print "want to restore (y/n) ? ";
			my $rep = <STDIN>;
			chomp($rep);

			return unless (lc($rep) eq 'y' );
		}
		# apply
		&$action;
		print "change $type on $filename\n";
		writelog($filename, $type, $orig, $current);
	}
	return;
}
###############################################################################
sub display($$$$) {
	my $filename = shift(@_);
	my $param = shift(@_);
	my $orig = shift(@_);
	my $current = shift(@_);

	print "$filename $param orig $orig current $current\n";
	return;
}
###############################################################################
sub writelog($$$$) {
	my $filename = shift(@_);
	my $param = shift(@_);
	my $orig = shift(@_);
	my $current = shift(@_);

	print $fh_log "$filename $param orig $orig current $current\n" if ($fh_log);
	return;
}
###############################################################################
# todo : write action
sub readlog($) {
	my $log = shift(@_);

	my $fh_roll;
	open($fh_roll, '<', $log) or die "can not open $log : $!\n";

	while(<$fh_roll>) {
		chomp;
		my ($fic, $param, $orig, $current);
		if (m/^(\S+) (\w+) orig (.*) current (.*)/ ){
			$fic = $1;
			$param = $2;
			$orig = $3;
			$current = $4;

			if ($param eq 'user' ) {
				if ($orig =~ m/^(\d+)/ ){
					my $uid = $1;
					 print "chown $uid, -1, $fic;\n";
				}
			} elsif ($param eq 'group') {
				if ($orig =~ m/^(\d+)/ ){
					my $gid = $1;
					 print "chown -1, $gid, $fic;\n";
				}
			}elsif ($param eq 'mtime') {
				print "system(\"touch -m -t $orig $fic\")\n";
			}elsif ($param eq 'mode') {
				print "chmod ". oct($orig) .", $fic\n";
			} else {
			}
		}
	}

	close $fh_roll;

	return;
}
###############################################################################
#                             main
###############################################################################
my $Version = '0.1';

my $opt_help;
my $opt_man;
my $opt_verbose;
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
Getopt::Long::Configure('no_ignore_case');
GetOptions(
		'help|?'    => \$opt_help,
		'man'    => \$opt_man,
		'file=s'    => \$opt_file,
		'package=s'    => \$opt_package,
		'verbose' => \$opt_verbose,
		'version|V' => \$opt_version,
		'batch'   => \$opt_batch,
		'dryrun|n'  => \$opt_dryrun,
		'all'     => \$opt_flag_all,
		'user'    => \$opt_flag_user,
		'group'   => \$opt_flag_group,
		'mode'    => \$opt_flag_mode,
		'time'    => \$opt_flag_time,
		'size'    => \$opt_flag_size,
		'log=s'	  => \$opt_log,
		'rollback=s' => \$opt_rollback,
	) or pod2usage(2);

if ($opt_help) {
	pod2usage(1);
} elsif ($opt_man) {
	pod2usage(-verbose => 2);
} elsif ($opt_version) {
	print_version($Version);
	exit;
}

if ($opt_rollback) {
	# todo parse log file and restore attributes
	readlog($opt_rollback);

	exit;
}

if ($opt_flag_all) {
	$opt_flag_user  = 1;
	$opt_flag_group = 1;
	$opt_flag_mode  = 1;
	$opt_flag_time  = 1;
	$opt_flag_size  = 1;
}

if ($opt_file) {
	# get rpm from file
	$opt_package = `rpm -qf --queryformat "%{NAME}" $opt_file `;
	print "package is $opt_package\n";
}

if ( !defined $opt_package ) {
	pod2usage('missing rpm package name');
}

# check
my @check = `rpm -V --nomd5 $opt_package`;

#print Dumper(@check);

if ( !@check ) {
	print "ras\n";
	exit;
}
my %infos = get_rpm_infos($opt_package);

if ( $opt_log ) {
	# open log file
	open ($fh_log, '>', $opt_log ) or warn "can not open $opt_log : $!\n";
}
#print Dumper(%infos);
# we can act on some changes :
# U user
# G group
# T mtime
# M mode

foreach my $elem (@check) {
	next if ( $elem =~ m/^missing/ );

	my ( $change, $config, $filename ) = split( ' ', $elem );

	if ( $config ne 'c' ) {
		$filename = $config;
	}
	if ($opt_file) {
		next if ( $filename ne $opt_file);
	}

	# get current info
	my (
		$dev,  $ino,   $mode,  $nlink, $uid,     $gid, $rdev,
		$size, $atime, $mtime, $ctime, $blksize, $blocks
	) = stat($filename);

	# rpm info
	my $rpm_info = $infos{$filename};

	if ( ($opt_flag_user) and ( $change =~ m/U/ ) ) {
		my $rpm_user = $rpm_info->{user};
		my $rpm_uid  = getpwnam($rpm_user);
		my $user     = getpwuid($uid);

		my $action = sub { chown $rpm_uid, -1, $filename; };
		ask($opt_dryrun, $opt_batch, $action, $filename, 'user', "$rpm_uid ($rpm_user))", "$uid ($user)" );
	}
	if ( ($opt_flag_group) and ( $change =~ m/G/ ) ) {
		my $rpm_group = $rpm_info->{group};
		my $rpm_gid   = getgrnam($rpm_group);
		my $group     = getgrgid($gid);

		my $action = sub { chown -1, $rpm_gid, $filename; };
		ask($opt_dryrun, $opt_batch, $action, $filename, 'group', "$rpm_gid ($rpm_group)", "$gid ($group)" );
	}
	if ( ($opt_flag_time) and ( $change =~ m/T/ ) ) {
		my $rpm_mtime   = $rpm_info->{mtime};
		my $rpm_h_mtime = strftime "%Y%m%d%H%M.%S", localtime($rpm_mtime);
		my $h_mtime     = strftime "%Y%m%d%H%M.%S", localtime($mtime);

		my $action = sub { system("touch -m -t $rpm_h_mtime $filename"); };
		ask($opt_dryrun, $opt_batch, $action, $filename, 'mtime', $rpm_h_mtime, $h_mtime);

	}
	if ( ($opt_flag_mode) and ( $change =~ m/M/ ) ) {
		my $rpm_mode = $rpm_info->{mode};
		my $h_mode = sprintf "%lo", $mode;

		my $action = sub { chmod oct($rpm_mode), $filename; };
		ask($opt_dryrun, $opt_batch, $action, $filename, 'mode', $rpm_mode, $h_mode );
	}
	if ( ($opt_flag_size) and ( $change =~ m/S/ ) ) {
		my $rpm_size = $rpm_info->{size};

		display($filename, 'size', $rpm_size, $size );
		
		# no fix action on this parameter
	}
}
close ($fh_log ) if ( $opt_log );

__END__

=head1 NAME

rpmrestore - restore attributes from rpm database

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
   -batch		batch mode (ask no questions)
   -n, --dry-run	do not perform any change
   -verbose		verbose
   -V, --version	print version
   -log logfile		log action in logfile

  -all		apply on all parameters
  -user		apply on user
  -group	apply on group
  -mode		apply on mode
  -time		apply on mtime
  -size		apply on size (just display)

=head1 OPTIONS

=head1 USE

the rpm command to control changes 
 
rpm -V rpm

same effect (just display) but more detailed (display values)

rpmrestore.pl -a -n -p rpm

interactive change mode, on time attribute

rpmrestore.pl -t -p rpm

batch change mode (DANGEROUS) on mode attribute

rpmrestore.pl -a -b rpm

interactive change of mode attribute on file /etc/motd

rpmrestore.pl -m -l /tmp/log -f /etc/motd

rollback changes from /tmp/log

rpmrestore.pl -r /tmp/log

=head1 NOTES

you should be superuser to use this program

on batch mode, we recommend to use log file

=head1 SEE ALSO

=for man
\fIrpm\fR\|(1) for rpm call

=head1 COPYRIGHT

Copyright (C) 2006 by Eric Gerbier
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=head1 AUTHORS

Eric Gerbier

you can report any bug or suggest to gerbier@users.sourceforge.net

=cut
