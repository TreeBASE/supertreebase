#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::IO 'parse';
use Bio::Phylo::Util::Logger ':levels';
use Bio::Phylo::Util::CONSTANT ':objecttypes';
use Bio::Phylo::Util::Exceptions 'throw';

# given a NeXML file, emits an MRP table as a tab-delimited
# table with three columns:
# 1. NCBI taxon ID
# 2. taxon name
# 3. MRP character state string
# this script therefore results in MRP tables whose rows
# might represent any taxonomic level. This script is 
# executed by the 'make tb2mrp_taxa' target.

# process command line arguments
my ( $infile, $verbosity );
GetOptions(
	'infile=s' => \$infile,
	'verbose+' => \$verbosity,
);

# instantiate logger
my $log = Bio::Phylo::Util::Logger->new(
	'-class' => 'main',
	'-level' => $verbosity,
);

# parse infile, trap exceptions
my $proj;
eval {
	$proj = parse(
		'-format'     => 'nexml',
		'-file'       => $infile,
		'-as_project' => 1,
		'-skip'       => [ _MATRIX_ ],
	)
};

# this is where we could otherwise die in a
# way that upsets the enviroment (=make),
# just log an error and exit instead
if ( $@ ) {
	$log->error( ref $@ ? $@->error : $@ );
	exit 0;
}
else {
	$log->info("successfully parsed $infile");
}

# fetch the taxa blocks
my $taxa_blocks = $proj->get_taxa;

# delete taxa without NCBI identifiers, rename those with to the ID
for my $taxa ( @{ $taxa_blocks } ) {
	for my $taxon ( @{ $taxa->get_entities } ) {
		my $id;
		my $name = $taxon->get_name;
		
		# here we're reading semantic annotations from the NeXML
		META: for my $meta ( @{ $taxon->get_meta('skos:closeMatch') } ) {
			my $object = $meta->get_object;
			
			# the object should be a uniprot uri for the NCBI taxonomy
			if ( $object =~ m/.+uniprot.+?(\d+)/ ) {
				$id = $1;			
				last META;
			}
		}
		
		
		# rows in the final MRP table must be labeled
		# with NCBI ids, not TB2 labels, so we rename
		# all the tips in trees that point to this taxon
		# and rename them
		if ( $id ) {
			$log->debug("keeping $name ($id)");
			$taxon->set_name( $id );
			for my $node ( @{ $taxon->get_nodes } ) {
				$node->set_name( $id );
			}
		}
		
		# we will prune out all taxa that don't have NCBI id annotations
		else {
			$log->info("*** pruning $name");
			$taxa->delete($taxon);
			for my $node ( @{ $taxon->get_nodes } ) {
				my $tree = $node->get_tree;
				$tree->prune_tips([$node]);
			}
		}
	}
}

# print results
for my $forest ( @{ $proj->get_forests } ) {
	my $matrix = $forest->make_matrix;
	my $id = $forest->get_xml_id;
	ROW: for my $row ( @{ $matrix->get_entities } ) {
		my $name = $row->get_name;
		my $char = $row->get_char;
		if ( $char =~ /^\?+$/ ) {
			$log->warn("only missing data for taxon $name from tree block $id in file $infile");
			next ROW;
		}
		print $id, "\t", $name, "\t", $char, "\n";
	}
}


