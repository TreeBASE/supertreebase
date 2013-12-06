#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::DB::Taxonomy;
use Bio::Phylo::Factory;
use Bio::Phylo::Util::Logger ':levels';

# process command line arguments
my ( $nodesfile, $namesfile, $directory, $speciesfile, $verbosity );
GetOptions(
    'nodesfile=s'   => \$nodesfile,
    'namesfile=s'   => \$namesfile,
    'directory=s'   => \$directory,
    'speciesfile=s' => \$speciesfile,
	'verbose+'      => \$verbosity,
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

# read taxon IDs that were encountered in treebase
$log->info("going to read treebase taxon ids from $speciesfile");
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

{
	# custom code for building the MRP
	$log->info("going to build MRP matrix");
	my $char = 0;
	my @tips;
	$tree->visit_depth_first(
		'-pre' => sub {
			my $node = shift;
			
			# we don't need to do anything for terminal nodes because
			# those MRP splits are trivial (though we do want to store
			# the objects for later usage)
			if ( $node->is_internal ) {
				my $seq = $node->get_generic('seq') || {};
				my $name = $node->get_name;
				$log->info("building MRP splits for node $name");				
				my @children = @{ $node->get_children };
				
				# skip over unbranched internals
				if ( scalar(@children) > 1 ) {
					
					# copy the parent's seq hash by value (not by ref!)
					for my $child ( @children ) {
						my %seq = %{ $seq };
						$child->set_generic( 'seq' => \%seq );
					}
					
					# now add all splits to the seq arrays
					for my $ingroup ( @children ) {
						
						# set ingroup to 1
						my $ingroup_seq = $ingroup->get_generic('seq');
						$ingroup_seq->{$char} = 1;
						$ingroup->set_generic( 'seq' => $ingroup_seq );
						
						# set outgroups to 0
						my $ingroup_id = $ingroup->get_id;
						OUTGROUP : for my $outgroup ( @children ) {
							next OUTGROUP if $outgroup->get_id == $ingroup_id;
							my $outgroup_seq = $outgroup->get_generic('seq');
							$outgroup_seq->{$char} = 0;
							$outgroup->set_generic( 'seq' => $outgroup_seq );
						}
						$char++;
					}
				}
			}
			
			# we build a growing list of tips so we don't have to query
			# the tree for it later on (and so we can log more informatively)
			else {
				push @tips, $node;
				my $tipcount = scalar @tips;
				$log->info("*** $tipcount / $ntax tip in pre-order traversal");				
			}
		}
	);
	
	# print the result
	for my $tip ( @tips ) {
		my $name = $tip->get_name;
		$log->info("writing MRP seq for $name");
		print $name, "\t";
		my $seq = $tip->get_generic('seq');
		
		# at this point the arrays are sparse in that they have no
		# defined value if the tip is a "deep" outgroup
		print ( $seq->{$_} || 0 ) for 0 .. $char;
		print "\n";		
	}
}







