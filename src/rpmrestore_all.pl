#!/usr/bin/perl
###############################################################################
#   rpmrestore_all.pl
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
# restore all attributes on all files (as possible)
use strict;
use warnings;

use English qw(-no_match_vars);
use Getopt::Long;    # arg analysis
use Pod::Usage;      # man page

my $version = '0.1';

# allow pass args to rpmrestore
my $args = join q{ }, @ARGV;

my %opt;
Getopt::Long::Configure('no_ignore_case');

# to avoid warnings from Getopt
my $save = $SIG{__WARN__};
$SIG{__WARN__} = sub { };
if ( GetOptions( \%opt, 'help|?', 'man', 'version', ) ) {

	# help for this program
	if ( $opt{'help'} ) {
		pod2usage(1);
	}
	elsif ( $opt{'man'} ) {
		pod2usage( -verbose => 2 );
	}
	elsif ( $opt{'version'} ) {
		print "$PROGRAM_NAME version $version\n";
		exit;
	}
}

# restore handler
$SIG{__WARN__} = $save;

# get list of all modified packages
## no critic (ProhibitTwoArgOpen)
if ( open my $fh, 'rpm -Va |' ) {
	my %list;
	while (<$fh>) {
		chomp;

		# file name is the last field of the line
		my @tab = split / /, $_;
		## no critic (RequireNegativeIndices)
		my $filename = $tab[$#tab];

		# get package from filename
		## no critic (ProhibitBacktickOperators)
		my $pac = `rpm -qf $filename`;
		print "debug $filename to $pac\n";

		if ( exists $list{$pac} ) {

			# already seen package
		}
		else {

			# mark as seen
			$list{$pac} = 1;

			# restore attributes
			system "rpmrestore.pl $args $pac";
		}
	}
	## no critic(RequireCheckedClose,RequireCheckedSyscalls)
	close $fh;
}
else {
	warn "can not get list of modified packages : $ERRNO\n";
}

__END__

=head1 NAME

rpmrestore_all.pl - restore all attributes from rpm database

=head1 DESCRIPTION

The rpm database store user, group, time, mode for all files,
and offer a command (rpm -V ) to display a summary of the changes between 
install state (database) and current disk state. 
Rpmrestore can display detailed changes and can restore install attributes.

=head1 SYNOPSIS

rpmrestore_all.pl [options]

options:

   -help		brief help message
   -man			full documentation
   -V, --version	print version

   -verbose		verbose
   -batch		batch mode (ask no questions)
   -n, --dry-run	do not perform any change
   -log logfile		log action in logfile
   -rollback logfile	restore attributes from logfile (written by -log)

  -all		apply on all attributes
  -user		apply on user
  -group	apply on group
  -mode		apply on mode
  -time		apply on mtime
  -size		apply on size (just display)
  -md5		apply on md5 (just display)

=head1 REQUIRED ARGUMENTS

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

=item B<-capability>

capability means for posix capability. This is not available on all linux distributions.
You can look getcap/setcap man pages for more informations.

=back

=head1 USAGE

interactive change mode, only on time attribute

  rpmrestore_all.pl -time 

interactive change mode, on all attributes except time attribute

  rpmrestore_all.pl -all -notime

batch change mode (DANGEROUS) on mode attribute with log file

  rpmrestore_all.pl -batch -log /tmp/log

interactive change of mode attribute on file /etc/motd

  rpmrestore_all.pl -mode 

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
