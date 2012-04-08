#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::DB::Taxonomy;
use Bio::Phylo::Factory;
use Bio::Phylo::Util::Logger ':levels';

# process command line arguments
my ( $nodesfile, $namesfile, $directory, $taxafile, $verbosity );
GetOptions(
    'nodesfile=s' => \$nodesfile,
    'namesfile=s' => \$namesfile,
    'directory=s' => \$directory,
    'taxafile=s'  => \$taxafile,
	'verbose+'    => \$verbosity,
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
my $fac    = Bio::Phylo::Factory->new;
my $forest = $fac->create_forest;
my $tree   = $fac->create_tree;
$forest->insert($tree);

# read taxon IDs that were encountered in treebase
$log->info("going to read treebase taxon ids from $taxafile");
my @ids;
{
	open my $fh, '<', $taxafile or die $!;
	while(<$fh>) {
		chomp;
		push @ids, $_ if $_;
	}
	close $fh;
}

# for each tip, walk up the taxonomy to the point where we
# reach a previously seen ancestor (i.e. one that was reached
# through another path), then move onto the next tip, building
# the common tree in the process
my %node_for_id; # stores Bio::Phylo nodes keyed on NCBI ids
for my $id ( sort { $a <=> $b } @ids ) {
	my $ncbi_node = $db->get_Taxonomy_Node( '-taxonid' => $id );
	
	# mirror the focal tip
	$node_for_id{$id} = $fac->create_node( '-name' => $id );
	$tree->insert($node_for_id{$id});
	
	# recurse up the tree
	PARENT: while( my $ncbi_parent = $db->ancestor($ncbi_node) ) {
		my $parent_id = $ncbi_parent->id;
		
		# already seen parent, just add this child and quit traversal
		if ( my $bp_parent = $node_for_id{$parent_id} ) {
			$node_for_id{$ncbi_node->id}->set_parent($bp_parent);
			$log->info("already seen ancestor $parent_id");
			last PARENT;
		}
		
		# create new parent
		else {
			my $bp_parent = $fac->create_node( '-name' => $parent_id );
			$tree->insert($bp_parent);
			$node_for_id{$parent_id} = $bp_parent;
			$node_for_id{$ncbi_node->id}->set_parent($bp_parent);
			
			# prepare for next iteration
			$ncbi_node = $ncbi_parent;
		}
	}
}

# we must have crossed internal nodes that point to splits for which
# we have no representatives (i.e. unbranched internals), so remove these
$tree->remove_unbranched_internals;

# creates and prints MRP matrix
$forest->make_matrix->visit(sub {
	my $row  = shift;
	my $data = $row->get_char;
	my $name = $row->get_name;
	print $name, "\t", $data, "\n";
});





