#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::Util::Logger ':levels';

# this script traverses all the normalized MRP matrices 
# (i.e. the *.dat files in the data/treebase folder that
# are produced by the target 'make tb2mrp_species' in ../supertree) and
# builds the links between studies on the basis of their taxonomic overlap.
# the graph that is implied by these links is printed at in GraphViz/dot
# syntax. this script is executed by the 'make cliques' target.

# process command line arguments
my ( $ext, $verbosity, $dir ) = ( 'dat' );
GetOptions(
	'dir=s'    => \$dir,
	'verbose+' => \$verbosity,
);

# instantiate logger
my $log = Bio::Phylo::Util::Logger->new(
	'-class' => 'main',
	'-level' => $verbosity,
);

# will hold taxon IDs per study
my %Study;

# iterate over dir contents
$log->info("going to read $ext files from dir $dir");
opendir my $dh, $dir or die $!;
while( my $file = readdir $dh ) {
	
	# file has the right extension
	if ( $file =~ /\.$ext/ && $file ne "ncbi.${ext}" ) {
		my $id = $file;
		$id =~ s/\.$ext$//;
		$Study{$id} = [];		

		# open file handle
		$log->debug("going to read contents from $dir/$file");
		open my $fh, '<', "$dir/$file" or die $!;
		while( <$fh> ) {
			chomp;
			if ( /^Tb[0-9]+\t(\d+)\t.+$/ ) {
				my $taxon = $1;
				push @{ $Study{$id} }, $taxon;
			}
			else {
				$log->warn("unexpected pattern in $file: $_");
			}
		}
	}
}
$log->info("done reading studies");

# these are all study IDs
my @ids = sort { $a cmp $b } keys %Study;

# do all pairwise comparisons
print "graph TreeBASE {\n";
for my $i ( 0 .. $#ids ) {
	my $focal_id = $ids[$i];
	$log->info("computing distance from $focal_id");
	
	# lookup table to count overlaps with other studies
	my %taxa = map { $_ => 1 } @{ $Study{$focal_id} };

	# will hold taxon overlap with other studies
	my %weights;

	# compare with not-yet-seen studies
	for my $j ( $i + 1 .. $#ids ) {
		my $other_id = $ids[$j];
		$log->debug("computing distance to $other_id");

		# counts number of taxa seen in both studies
		my $overlap = scalar grep { $taxa{$_} } @{ $Study{$other_id} };
		$weights{$other_id} = $overlap if $overlap;
	}

	# print result in dot syntax
	for my $other_id ( keys %weights ) {
		my $weight = $weights{$other_id};
		print "\t$focal_id -- $other_id [weight=$weight]\n";
	}

	# also print completely unconnected trees
	if ( not scalar keys %weights ) {
		$log->warn("$focal_id is completely unconnected");
		print "\t$focal_id\n";
	}
}
print "}\n";
