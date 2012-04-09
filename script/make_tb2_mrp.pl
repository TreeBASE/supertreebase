#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::IO 'parse';
use Bio::Phylo::Util::Logger ':levels';
use Bio::Phylo::Util::CONSTANT ':objecttypes';
use Bio::Phylo::Util::Exceptions 'throw';

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

# fetch all taxon objects
my $taxa = $proj->get_items(_TAXON_);

# collect those without NCBI identifiers, rename those with to the ID
my @delete;
for my $taxon ( @{ $taxa } ) {
	my $id;
	
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
		$taxon->set_name( $id );
		for my $node ( @{ $taxon->get_nodes } ) {
			$node->set_name( $id );
		}
	}
	
	# we will prune out all taxa that don't have NCBI id annotations
	else {
		push @delete, $taxon;
	}
}

# let's say a project could be multiple forests, though I doubt it for TB2
my $forests = $proj->get_items(_FOREST_);

# prune non-anchored taxa, make MRP from the rest
for my $forest ( @{ $forests } ) {
	
	# for each tree in the tree block, delete the un-annotated tips/taxa
	$forest->visit(sub{
		my $tree = shift;
		$tree->prune_tips(\@delete);
	});
	
	# make an MRP matrix and iterate over the rows
	eval {
		my $matrix = $forest->make_matrix;
		$matrix->visit(sub{
			my $row  = shift;
			my $char = $row->get_char;
			my $name = $row->get_name;
			
			# this is the format of the final MRP data row:
			# NCBI identifier, tab stop, a string of 0's and 1's, line break
			print $name, "\t", $char, "\n";
		})
	};
	if ( $@ ) {
		throw 'API' => ref $@ ? $@->error : $@;
	}
	else {
		$log->info("successfully processed $infile");
	}
}

