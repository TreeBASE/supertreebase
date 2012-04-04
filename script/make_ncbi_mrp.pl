#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::DB::Taxonomy;
use Bio::Phylo::Factory;
use Bio::Phylo::Util::Logger ':levels';

# process command line arguments
my ( $nodesfile, $namesfile, $directory, $rootid, $verbosity );
GetOptions(
    'nodesfile=s' => \$nodesfile,
    'namesfile=s' => \$namesfile,
    'directory=s' => \$directory,
    'rootid=i'    => \$rootid,
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
my $proj   = $fac->create_project;
my $forest = $fac->create_forest;
my $tree   = $fac->create_tree;
$proj->insert($forest);
$forest->insert($tree);
my %node_for_id; # stores Bio::Phylo nodes keyed on NCBI ids

# build the ncbi tree from here
$log->info("going to look up ncbi taxon id $rootid");
my $ncbi_root = $db->get_Taxonomy_Node( '-taxonid' => $rootid );
my $tipcounter = 1;
recurse($ncbi_root,undef);

# creates and prints MRP matrix
$forest->make_matrix->visit(sub {
	my $row  = shift;
	my $data = $row->get_char;
	my $name = $row->get_name;
	print $name, "\t", $data, "\n";
});

sub recurse {
	my ( $ncbinode, $ncbiparent ) = @_;
	my $id = $ncbinode->id;
	my @name = @{ $ncbinode->name('scientific') };
	$log->info("processing @name ($id)");
	
	# mirror ncbi node to Bio::Phylo node
	my $node = $fac->create_node( '-name' => $id );
	$node_for_id{$id} = $node;
	$tree->insert($node);
	
	# attach to parent, if exists
	if( my $ncbiparent ) {
		my $parent = $node_for_id{$ncbiparent->id};
		$node->set_parent($parent);
	}
	
	# don't recurse below species level
	if ( $ncbinode->rank eq 'species' ) {
		$log->info("have reached species level $tipcounter time(s), returning");
		$tipcounter++;
		return; 
	}
	else {
		for my $ncbichild ( $db->each_Descendent($ncbinode) ) {
			recurse( $ncbichild, $ncbinode );
		}
	}
}





