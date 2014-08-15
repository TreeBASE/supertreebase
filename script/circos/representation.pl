#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::DB::Taxonomy;
use Bio::Phylo::Util::Logger ':levels';

# this hack is here so that the NCBI taxonomy indexes aren't deleted
# when the $db object is destroyed
BEGIN { *Bio::DB::Taxonomy::flatfile::DESTROY = sub {} }

# this script writes out for each taxon in how many
# studies it is represented. Usage:
# $0 -nodes data/taxdmp/nodes.dmp -names data/taxdmp/names.dmp \
# -d data/taxdmp/tmp -i data/treebase/taxa.txt > metadata/circos/representation.txt

# The magic of NCBI's multiple origins...
my @roots = (
	2157,  # Archaea
	2,     # Bacteria
	2759,  # Eukaryota
#	12884, # Viroids
#	10239, # Viruses
#	28384, # "other sequences"
#	12908, # "unclassified"
);

# unclassified taxa to ignore, e.g.:
my %block = (
	'1130266' => 1,
	'1154676' => 1,
	'1154675' => 1,
	'447827'  => 1,
	'1297'    => 1,
	'42452'   => 1,
	'2323'    => 1,
);

# process command line arguments
my $verbosity;
my $nodesfile; # e.g. data/taxdmp/nodes.dmp
my $namesfile; # e.g. data/taxdmp/names.dmp
my $directory; # e.g. data/taxdmp/tmp
my $infile;    # e.g. data/treebase/taxa.txt
GetOptions(
	'infile=s'    => \$infile, # taxa.txt
	'verbose+'    => \$verbosity,
	'namesfile=s' => \$namesfile,
	'nodesfile=s' => \$nodesfile,
	'directory=s' => \$directory,
);

# instantiate helper objects
my $log = Bio::Phylo::Util::Logger->new(
	'-class' => 'main',
	'-level' => $verbosity,
);
$log->info("connecting to flatfile DB");
$log->info("nodes = $nodesfile");
$log->info("names = $namesfile");
$log->info("dir   = $directory");
my $dbt = Bio::DB::Taxonomy->new(
	'-source'    => 'flatfile',
	'-nodesfile' => $nodesfile,
	'-namesfile' => $namesfile,
	'-directory' => $directory,	
);
$log->info("instantiated connection to NCBI flat file db");

# read list of taxon IDs
my %taxon;
{
	$log->info("going to read from $infile");
	open my $fh, '<', $infile or die $!;

	# each line consists of occurrence and taxon ID
	LINE: while(<$fh>) {
		chomp;
		if ( /^\s*(\d+)\s+(\d+)/ ) {
			my ( $count, $id ) = ( $1, $2 );
			if ( $block{$id} ) {
				$log->info("ignoring unclassified taxon $id");
				next LINE;
			}
			$taxon{$id} = $count;
		}
		else {
			$log->warn("unexpected pattern in $infile: $!");
		}
	}
	$log->info("read ".scalar(keys(%taxon))." taxon IDs");
}

# print header
print "ID\tName\tRank\tStudies\tChildCount\tPhylum\tPos\n";
$|++;

# temp variables
my ( $in_treebase, $pos, %before_treebase, $phylum ) = ( 0, 0 );

# iterate over ncbi roots
for my $root ( @roots ) {
	$log->info("starting at root $root");

	# get the NCBI root node object
	my $rootnode = $dbt->get_taxon( '-taxonid' => $root );
	$log->info("root node object: $rootnode");
	
	# start recursing
	recurse($rootnode);

}

sub recurse {
	my $node  = shift;
	my $id    = $node->id;
	my $name  = $node->scientific_name;
	my $rank  = $node->rank;
	my $count = 0;
	$phylum = $id if $rank eq 'phylum';

	# fetch immediate children
	my @children = $dbt->each_Descendent($node);	
	
	# node is internal
	if ( @children ) {
		
		# cache tip counts before further recursion
		$before_treebase{$id} = $in_treebase;
		
		# recurse further
		recurse($_) for @children;
		
		# compute count of subtended TreeBASE tips
		$count = $in_treebase - $before_treebase{$id};
			
	}
	else {

		# number of studies for focal tip
		$count = $taxon{$id} || 0;
		
		# counter for post-order diff computation
		$in_treebase += $count;
	}

	# maybe ignore environmental samples, etc.
	if ( $block{$id} ) {
		$log->info("skipping blacklisted id $id");
	}
	else {
        	print  
                	$id, "\t",
                	$name, "\t",
                	$rank, "\t",
                	$count, "\t",
			scalar(@children), "\t",
			$phylum, "\t",
			++$pos, "\n";
		$log->info("ID: $id, NAME: $name, COUNT: $count") if $rank eq 'phylum';
	}
}
