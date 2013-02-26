#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::DB::Taxonomy;
use Bio::Phylo::Factory;
use Bio::Phylo::Treedrawer;
use Bio::Phylo::Util::Logger ':levels';

# process command line options
my ( $scale, $verbosity ) = ( 1000, WARN );
my $outfile    = 'metadata/bands.txt';
my $labeltrack = 'metadata/labels.txt';
my $figure     = 'metadata/radial.svg';
my ( $table, $namesfile, $nodesfile, $directory );
GetOptions( 
	'table=s'      => \$table,
	'scale=i'      => \$scale,
	'verbose+'     => \$verbosity,
	'namesfile=s'  => \$namesfile,
	'nodesfile=s'  => \$nodesfile,
	'directory=s'  => \$directory,	
	'outfile=s'    => \$outfile,
	'labeltrack=s' => \$labeltrack,
	'figure=s'     => \$figure,
);

# instantiate helper objects
my $fac = Bio::Phylo::Factory->new(
	'node' => 'Bio::Phylo::Forest::DrawNode',
	'tree' => 'Bio::Phylo::Forest::DrawTree',
);
my $log = Bio::Phylo::Util::Logger->new(
	'-level' => $verbosity,
	'-class' => 'main',
);
my $db = Bio::DB::Taxonomy->new(
	'-source'    => 'flatfile',
    '-nodesfile' => $nodesfile,
    '-namesfile' => $namesfile,
    '-directory' => $directory,	
);
my $td = Bio::Phylo::Treedrawer->new(
    '-width'  => 1600,
    '-height' => 1600,
    '-shape'  => 'radial',
    '-mode'   => 'phylo',
    '-format' => 'svg'
);

# read table
my ( %Node );
{
	open my $fh, '<', $table or die $!;
	LINE: while(<$fh>) {
		chomp;
		my ( $id, $name, $rank, $treebase, $ncbi ) = split /\t/, $_;
		next LINE if $id eq 'ID'; # header
		
		# pseudo objects with data from table
		$Node{$id} = {
			'name' => $name,
			'rank' => $rank,
			'ncbi' => $ncbi,
			'tb2'  => $treebase,			
		};
		$log->debug("$name => $ncbi");
	}
	close $fh;
}

my %seen;
my %root;
my $tree = $fac->create_tree;
for my $id ( keys %Node ) {

	# fetch taxon from database
	$log->info("ID: $id");
	my $taxon = $db->get_taxon( '-taxonid' => $id );
	
	# instantiate bio::phylo node
	my $node  = $fac->create_node(
		'-guid' => $id,
		'-name' => $Node{$id}->{'name'},
		'-generic' => {
			'rank' => $Node{$id}->{'name'},
			'ncbi' => $Node{$id}->{'ncbi'},
			'tb2'  => $Node{$id}->{'tb2'},			
		},
	);
	$tree->insert($node);
	
	# traverse to all ancestors
	ANCESTOR : while( my $ancestor = $taxon->ancestor ) {
		my $ancestor_id = $ancestor->id;
		my $parent = $seen{$ancestor_id};
		$log->info("ANCESTOR: $ancestor_id");
		
		# for the first tip we will travel all the way
		# to the root. Then, less so.
		if ( not $parent ) {
		
			# create parent node
			$parent = $fac->create_node(
				'-guid' => $ancestor_id,
				'-name' => $ancestor->scientific_name,
			);
			$tree->insert($parent);
			$node->set_parent($parent);			
			$seen{$ancestor_id} = $parent; # cache
			
			# continue traversal
			$node  = $parent;
			$taxon = $ancestor;			
		}
		else {
			$log->info("DONE");
			$node->set_parent($parent);
			last ANCESTOR;
		}
	}
}
$log->info("ROOTS: " . join " ", keys %root);

# make branches initially length 1, then stretch 
# tips to make them line up
$tree->remove_unbranched_internals;
$tree->visit(sub{ shift->set_branch_length(1) });
$tree->ultrametricize;

open my $fh,  '>', $outfile or die $!;
open my $lfh, '>', $labeltrack or die $!;
my $tipcounter = 1;

# now add as many tips as needed to make the width to size
$tree->visit_depth_first(
	'-post' => sub{
		my $node = shift;
		if ( $node->is_terminal ) {
			my $id   = $node->get_guid;			
			my $name = $node->get_name;		
			
			# compute number of tips to add
			my $count = int( $node->get_generic('ncbi') / $scale ) || 1;
			
			# add tips
 			for my $i ( 1 .. $count ) {
# 				my $label = $i == int($count/2) ? $name : '';
 				my $child = $fac->create_node( 
 					'-branch_length' => 0, 
 					'-name'          => '', 
 				);
 				$child->set_parent($node);
 				$tree->insert($child);
 			}
			
			# write circos karyotype track
			print  $fh "chr", " ", 
			             '-', " ", 
			             $id, " ", 
			             $id, " ",
			               0, " ",
			          $count, " ",
			         'black', "\n";

			# write circos label track
			print   $lfh $id, " ",
			               0, " ",
			          $count, " ",
			           $name, "\n";

			# report progress
			$log->info("seen tip $name: " . $tipcounter++);
		}
		else {
			$node->set_name();
		}
	}
);
#$tree->ladderize;
#print $tree->to_newick( '-nodelabels' => 1 );
$td->set_tree($tree);
open my $figfh, '>', $figure or die $!;
print $figfh $td->draw;
