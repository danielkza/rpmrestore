#!/usr/bin/perl
# restore all attributes on all files (as possible)
use strict;
use warnings;

# allow pass args to rpmrestore
my $args = join ' ', @ARGV;

# get list of all modified packages
if (open my $fh, 'rpm -Va |') {
	my %list;
	while (<$fh>) {
		# file name is the last field of the line
		my @tab = split / /, $_;
		my $filename = $tab[ $#tab ];
		$list{ $filename } ++;
	}
	close $fh;
	
	# restore all packages in batch mode
	my @packages = sort keys %list;
	foreach my $pac (@packages) {
		system("rpmrestore.pl --batch $args $pac");
	}
} else {
	warn "can not get list of modified packages : $!\n";
}
