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
use Test::More qw(no_plan);
use Data::Dumper;

# arguments test
my $cmd = './rpmrestore.pl';

# 1 no arguments
my $out = `$cmd 2>&1`;
like( $out, qr/missing rpm package name/, 'no parameter' );

# 2 version
$out = `$cmd --version 2>&1`;
like( $out, qr/rpmrestore\.pl version/, 'version' );

# 3 help
$out = `$cmd --help`;
like( $out, qr/Usage:/, 'help' );

# 4 man
$out = `$cmd --man`;
like( $out, qr/User Contributed Perl Documentation/, 'man' );

# 5 bad package
$out = `$cmd -p tototo 2>&1`;
like( $out, qr/package does not exists/, 'no package' );

# 6 bad file name
$out = `$cmd -f tototo 2>&1`;
like( $out, qr/can not find .* file/, 'no file' );

# 7 file not from package
$out = `$cmd -f Todo 2>&1`;
like( $out, qr/is not owned by any package/, 'not from rpm' );

# 8 no changes on package
$out = `$cmd -p rpmrestore 2>&1`;
like( $out, qr/0 changes detected/, 'package no changes' );

# we work on rpm package, so the rpm should exist
my $file = '/bin/rpm';
if ( -e $file ) {

	# 9 no changes on file
	$out = `$cmd  -n -f $file 2>&1`;
	like( $out, qr/0 changes detected/, 'file no changes' );
}
else {
	diag("can not find $file file");
	exit;
}

# change only on root user
if ( $> == 0 ) {

	# change mtime
	system("touch $file");

	# 10 no changes on attribute
	$out = `$cmd -mode -n -f $file 2>&1`;
	like( $out, qr/0 changes detected/, 'attribute no changes' );

	# 11 test attribute change
	$out = `$cmd -t -n -f $file 2>&1`;
	like( $out, qr/$file mtime orig/, 'attribute changes' );

	my $log = 'log';
	unlink $log if ( -e $log );

	# 12 restore attribute change
	$out = `$cmd -t -b -f $file -log $log 2>&1`;
	like( $out, qr/change mtime on $file/, 'restore attribute' );

	# 13 check restore
	$out = `$cmd -t -n -f $file 2>&1`;
	like( $out, qr/0 changes detected/, 'check restore' );

	# 14 rollback 1
	$out = `$cmd -mode -b -r $log 2>&1`;
	like( $out, qr/rollback 0 attributes/, 'no rollback' );

	# 15 rollback 2
	$out = `$cmd -t -b -r $log 2>&1`;
	like( $out, qr/rollback 1 attributes/, 'rollback attribute' );

	# 16 interactive change
	$out = `echo 'n' | $cmd -f $file  2>&1`;
	like( $out, qr/0 changes applied/, 'interactive no changes' );

	# 17 interactive change
	$out = `echo 'y' | $cmd -f $file  2>&1`;
	like( $out, qr/1 changes applied/, 'interactive changes' );

	unlink $log;
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

=head1 AUTHORS

Eric Gerbier

you can report any bug or suggest to gerbier@users.sourceforge.net

=cut
