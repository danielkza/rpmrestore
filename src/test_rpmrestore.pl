#!/usr/bin/perl
###############################################################################
#   test_rpmrestore.pl
#
#    Copyright (C) 2006 by Eric Gerbier
#    Bug reports to: gerbier@users.sourceforge.net
#    $Id: rpmrestore.pl 28 2006-11-13 14:39:50Z gerbier $
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
# test of rpmrestore software

use strict;
use warnings;
use English qw(-no_match_vars);
use Test::More qw(no_plan);
use Data::Dumper;

## no critic (ProhibitBacktickOperators)
###############################################################################
sub search_command($) {
	my $prog = shift @_;

	foreach ( split /:/, $ENV{'PATH'} ) {
		if ( -x "$_/$prog" ) {
			return "$_/$prog";
		}
	}
	return 0;
}
###############################################################################
# rem some tests are made on rpmrestore packages / files
my $file = '/usr/bin/rpmrestore';

# arguments test
my $cmd = './rpmrestore.pl';

# 1 no arguments
my $out = `$cmd 2>&1`;
like( $out, qr/need a target/, 'no parameter' );

# 2 version
$out = `$cmd --version 2>&1`;
like( $out, qr/rpmrestore\.pl version/, 'version' );

# 3 help
$out = `$cmd --help`;
like( $out, qr/Usage:/, 'help' );

# 4 man
$out = `$cmd --man`;
like( $out, qr/User Contributed Perl Documentation/, 'man' );

# old deprecated syntaxe
########################
# 5 bad package
$out = `$cmd -p tototo 2>&1`;
like( $out, qr/package does not exists/, 'no package (deprecated)' );

# 6 bad file name
$out = `$cmd -f tototo 2>&1`;
like( $out, qr/is not a valid file/, 'no file (deprecated)' );

# 7 file not from package
$out = `$cmd -f Todo 2>&1`;
like( $out, qr/is not owned by any package/, 'not from rpm (deprecated)' );

# 8 no changes on package
$out = `$cmd -p rpmrestore 2>&1`;
like( $out, qr/0 changes detected/, 'package no changes (deprecated)' );

# 9 no changes on file
$out = `$cmd -f $file 2>&1`;
like( $out, qr/0 changes detected/, 'file no changes (deprecated)' );

# new syntax
############
# 10 bad package
$out = `$cmd tototo 2>&1`;
like( $out, qr/package does not exists/, 'no package (new)' );

# 11 file not from package
$out = `$cmd Todo 2>&1`;
like( $out, qr/is not owned by any package/, 'not from rpm (new)' );

# 12 no changes on package
$out = `$cmd rpmrestore 2>&1`;
like( $out, qr/0 changes detected/, 'package no changes (new)' );

# 13 no changes on file
$out = `$cmd $file 2>&1`;
like( $out, qr/0 changes detected/, 'file no changes (new)' );

# change only on root user
if ( $EFFECTIVE_USER_ID == 0 ) {

	# change mtime
	system("touch $file");

	# 14 no changes on attribute
	$out = `$cmd -mode -n -f $file 2>&1`;
	like( $out, qr/0 changes detected/, 'attribute no changes' );

	# 15 test attribute change
	$out = `$cmd -t -n -f $file 2>&1`;
	like( $out, qr/$file mtime orig/, 'attribute changes' );

	my $log = 'log';
	unlink $log if ( -e $log );

	# 16 restore attribute change
	$out = `$cmd -t -b -f $file -log $log 2>&1`;
	like( $out, qr/change mtime on $file/, 'restore attribute' );

	# 17 check restore
	$out = `$cmd -t -n -f $file 2>&1`;
	like( $out, qr/0 changes detected/, 'check restore' );

	# 18 rollback 1
	$out = `$cmd -mode -b -r $log 2>&1`;
	like( $out, qr/rollback 0 attributes/, 'no rollback' );

	# 19 rollback 2
	$out = `$cmd -t -b -r $log 2>&1`;
	like( $out, qr/rollback 1 attributes/, 'rollback attribute' );

	# 20 interactive change
	$out = `echo 'n' | $cmd -f $file  2>&1`;
	like( $out, qr/0 changes applied/, 'interactive no changes' );

	# 21 interactive change
	$out = `echo 'y' | $cmd -f $file  2>&1`;
	like( $out, qr/1 changes applied/, 'interactive changes' );

	unlink $log;

	# capability (works on fedora)
	# test for getcap
	my $getcap = search_command('setcap');
	if ($getcap) {

		# will work on ping
		my $filecap = '/usr/bin/ping';

		# 22 no changes
		$out = `$cmd -capability -n -f $filecap 2>&1`;
		like( $out, qr/0 changes detected/, 'capability no changes' );

		# 23 remove capability
		system "setcap -r $filecap";
		$out = `$cmd -capability -n -f $filecap 2>&1`;
		like( $out, qr/$filecap capability orig/, 'capability changes' );

		# 24 restore
		$out = `$cmd -capability -b -f $filecap 2>&1`;
		like( $out, qr/change capability on $filecap/, 'restore capability' );

		# 25 no changes
		$out = `$cmd -capability -n -f $filecap 2>&1`;
		like( $out, qr/0 changes detected/, 'capability no changes' );
	}
}
else {
	diag('you should be root to run other tests');
}

__END__

=head1 NAME

test_rpmrestore - test rpmrestore software

=head1 DESCRIPTION

this is designed to check if rpmrestore software is working :
test for options
test if detect changes
test if restore changes
test of rollback
test interactive mode

=head1 SEE ALSO

=for man
\fIrpmrestore\fR\|(1) for rpmrestore call

=head1 COPYRIGHT

Copyright (C) 2006 by Eric Gerbier
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=head1 AUTHOR

Eric Gerbier

you can report any bug or suggest to gerbier@users.sourceforge.net

=cut
