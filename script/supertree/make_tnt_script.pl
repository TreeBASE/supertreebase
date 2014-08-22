#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use List::Util 'sum';

# emits the header for a TNT command file, including the
# number of characters (as computed earlier) and the number
# of taxa (as computed from the species file). this script
# is executed by the 'make tntscript' target, whose recipe
# includes additional steps to specify which files to include
# and to define the TNT command file's footer.

# process command line arguments
my ( $ncharfile, $speciesfile );
GetOptions(
	'ncharfile=s'   => \$ncharfile,
	'speciesfile=s' => \$speciesfile,
);

# compute number of overall characters
my $nchar;
{
	my %nchars;
	open my $fh, '<', $ncharfile or die $!;
	while(<$fh>) {
		chomp;
		my @line = split /\t/, $_;
		$nchars{$line[0]} = $line[1];
	}
	close $fh;
	$nchar = sum(values %nchars);
}

# compute number of overall taxa
my $ntax;
{
	my %ntax;
	open my $fh, '<', $speciesfile or die $!;
	while(<$fh>) {
		chomp;
		my @line = split /\t/, $_;
		my @taxa = split /,/, $line[1];
		$ntax{$_} = 1 for @taxa;
	}
	close $fh;

	# add 1 to allow for the hypothetical MRP outgroup
	$ntax = scalar(keys %ntax) + 1;
}

print <<"HERE";
macro=;
/* execute me be starting up TNT and then type 'proc <scriptname> ;' */
/* note that you will need to increase memory to at least 50Gb! */
/* memory is increased in megabytes, e.g. using 'mxram 50000 ;' */
nstates 2;
xread 
$nchar $ntax
HERE
