#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::DB::Taxonomy;
use Bio::Phylo::Factory;
use Bio::Phylo::Util::Logger ':levels';

# creates a backbone MRP matrix of the NCBI common tree for all
# species encountered in TreeBASE. this script is executed by the
# 'make ncbimrp' target.

# process command line arguments
my ( $nodesfile, $namesfile, $directory, $speciesfile, $verbosity, $workdir );
GetOptions(
    'nodesfile=s'   => \$nodesfile,
    'namesfile=s'   => \$namesfile,
    'directory=s'   => \$directory,
    'speciesfile=s' => \$speciesfile,
    'verbose+'      => \$verbosity,
    'workdir=s'     => \$workdir,
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
my @ids;
{
	my %species;
	open my $fh, '<', $speciesfile or die $!;
	while(<$fh>) {
		chomp;
		my @line = split /\t/, $_;
		my @species = split /,/, $line[1];
		$species{$_} = 1 for @species;
	}
	@ids = keys %species;
	close $fh;
}

# handy to know for logging purposes
my $ntax = scalar @ids;

{
	# for each tip, walk up the taxonomy to the point where we
	# reach a previously seen ancestor (i.e. one that was reached
	# through another path), then move onto the next tip, building
	# the common tree in the process
	my %node_for_id; # stores Bio::Phylo nodes keyed on NCBI ids
	my $i = 1;
	for my $id ( sort { $a <=> $b } @ids ) {
		$log->info("*** ($i / $ntax) going to build path for $id");
		$i++;	
		my $ncbi_node = $db->get_Taxonomy_Node( '-taxonid' => $id );
		
		# mirror the focal tip
		$node_for_id{$id} = $fac->create_node( '-name' => $id );	
		$tree->insert($node_for_id{$id});
		
		# recurse up the tree
		PARENT: while( $ncbi_node and my $ncbi_parent = $db->ancestor($ncbi_node) ) {
			my $parent_id = $ncbi_parent->id;
			
			# already seen parent, just add this child and quit traversal
			if ( my $bp_parent = $node_for_id{$parent_id} ) {
				$node_for_id{$ncbi_node->id}->set_parent($bp_parent);
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
}

# create a lookup from taxon label to index, i.e. the order in which it was encountered
# in the input files.
my %lookup;
{
	$log->info("going to lookup taxon indexes in $workdir");
	my $i = 0;
	opendir my $dh, $workdir or die $!;
	while( my $entry = readdir $dh ) {

		# S12622.dat.Tb17032.tnt
		if ( $entry =~ /\.tnt$/ ) {
			open my $fh, '<', "${workdir}/${entry}" or die $!;
			while(<$fh>) {
				if ( /^(\d+)\s/ ) {
					my $id = $1;
					$lookup{$id} = $i++ if not defined $lookup{$id};
				}
			}
		}
	}
}

# print the constraints, skip over unbranched internals
print 'force = ';
$tree->visit_depth_first(
	'-pre' => sub {
		my $node = shift;
		my @children = @{ $node->get_children };
		print '(' if scalar(@children) >= 2;
	},
	'-post' => sub {
		my $node = shift;
		my @children = @{ $node->get_children };
		if ( scalar(@children) == 0 ) {
			my $id = $node->get_name;
			print $lookup{$id}, ' ';
		}
		else {
			print ')' if scalar(@children) >= 2;
		}
	},
);
print " ; constrain = ;\nproc/;\n";
