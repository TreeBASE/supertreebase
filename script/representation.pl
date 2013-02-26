#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::DB::Taxonomy;
use Bio::Phylo::Util::Logger ':levels';

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

# unclassified taxa to ignore
my %block = (
	'1130266' => 1,
	'1154676' => 1,
	'1154675' => 1,
	'447827'  => 1,
	'1297'    => 1,
);

# process command line arguments
my ( $verbosity, $nodesfile, $namesfile, $directory, $infile ) = ( WARN );
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
	LINE: while(<$fh>) {
		chomp;
		if ( $block{$_} ) {
			$log->info("ignoring unclassified taxon $_");
			next LINE;
		}
		$taxon{$_} = 1;
	}
	$log->info("read ".scalar(keys(%taxon))." taxon IDs");
}

# print header
print "ID\tName\tRank\tTreeBASE\tNCBI\n";
$|++;

# temp variables
my ( $in_treebase, $in_ncbi, %before_ncbi, %before_treebase ) = ( 0, 0 );

# iterate over ncbi roots
for my $root ( @roots ) {
	$log->info("starting at root $root");

	# get the NCBI root node object
	my $rootnode = $dbt->get_taxon( '-taxonid' => $root );
	
	# start recursing
	recurse($rootnode);

}

sub recurse {
	my $node = shift;
	my $id   = $node->id;
	$log->debug($id);
	my @children = $dbt->each_Descendent($node);
	
	# node is internal
	if ( @children ) {
		
		# cache tip counts before further recursion
		$before_treebase{$id} = $in_treebase;
		$before_ncbi{$id} = $in_ncbi;
		
		# recurse further
		recurse($_) for @children;
		
		# going to go by phyla
		my $rank = $node->rank;
		
		# if count exceeds threshold, print result
		if ( $rank eq 'phylum' ) {

			# compute count of subtended NCBI tips
			my $ncbi_tips = $in_ncbi - $before_ncbi{$id};
		
			# compute count of subtended TreeBASE tips
			my $treebase_tips = $in_treebase - $before_treebase{$id};
			
			# print result
			if ( $block{$id} ) {
				$log->info("skipping unclassified id $id");
			}
			else {
				my $name = $node->scientific_name;
				print 
					$id, "\t", 
					$name, "\t", 
					$rank, "\t", 
					$treebase_tips, "\t", 
					$ncbi_tips, "\n";
			}
		}
	}
	else {
		
		# increment counter for every NCBI tip	
		$in_ncbi++;
		
		# only increment counter for TreeBASE tip if seen
		$in_treebase++ if $taxon{$id};
	}
}



