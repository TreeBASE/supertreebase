#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::DB::Taxonomy;
use Bio::Phylo::Factory;
use Bio::Phylo::Util::Logger ':levels';

# creates TNT-compatible monophyly constraint commands for levels
# in the NCBI taxonomy. 

# process command line arguments
my $root = 2759;
my ( $nodesfile, $namesfile, $directory, $speciesfile, $verbosity );
GetOptions(
    'nodesfile=s'   => \$nodesfile,
    'namesfile=s'   => \$namesfile,
    'directory=s'   => \$directory,
    'speciesfile=s' => \$speciesfile,
    'verbose+'      => \$verbosity,
    'root=i'        => \$root,
);

# instantiate logger
my $log = Bio::Phylo::Util::Logger->new(
	'-level' => $verbosity,
	'-class' => 'main',
);

# instantiate database object
$log->info("nodesfile => $nodesfile");
$log->info("namesfile => $namesfile");
$log->info("directory => $directory");
my $db = Bio::DB::Taxonomy->new(
    '-source'    => 'flatfile',
    '-nodesfile' => $nodesfile,
    '-namesfile' => $namesfile,
    '-directory' => $directory,
);

# instantiate factory, create Bio::Phylo objects to mirror NCBI tree
my $fac  = Bio::Phylo::Factory->new;
my $tree = $fac->create_tree;

# read species IDs that were encountered in treebase
$log->info("going to read treebase species ids from $speciesfile");
my %species;
{
	open my $fh, '<', $speciesfile or die $!;
	while(<$fh>) {
		chomp;
		my @line = split /\t/, $_;
		my @species = split /,/, $line[1];
		$species{$_} = 1 for @species;
	}
	close $fh;
}
$log->info("done reading $speciesfile");

# depth-first recursion through the NCBI taxonomy. if the focal node
# is a species seen in TreeBASE, cache it. if the focal node is a 
# higher taxon, cache all the TreeBASE species it subtends and print
# out the constraint statement if it groups two or more species.
my %desc;
sub recurse {
	my $taxon = shift;
	for my $child ( $taxon->each_Descendent ) {
		recurse($child);
	}
	my $id = $taxon->id;
	if ( $species{$id} ) {
		$desc{$id} = { $id => 1 };
	}
	else {
		my %cdesc;
		for my $child ( $taxon->each_Descendent ) {
			my $cid = $child->id;
			if ( my $href = $desc{$cid} ) {
				for my $key ( keys %{ $href } ) {
					$cdesc{$key} = 1;
				}
			}
		}
		if ( %cdesc ) {
			$desc{$id} = \%cdesc;
			my $count = scalar keys %cdesc;
			if ( $count >= 2 ) {
				my $name = $taxon->node_name;
				my $rank = $taxon->rank;
				$log->info("rank $name subtends $count species in TreeBASE");
				print 'force = ( ', join( ' ', keys %cdesc ), " ) ; \n";
			}
		}
	}
}

# do the recursion
$log->info("going to traverse taxonomy");
recurse( $db->get_taxon($root) );
$log->info("done");
