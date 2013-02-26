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
my $outfile      = 'metadata/bands.txt';
my $labeltrack   = 'metadata/labels.txt';
my $scattertrack = 'metadata/scatter.txt';
my $figure       = 'metadata/radial.svg';
my $table        = 'metadata/representation.txt';
my ( $namesfile, $nodesfile, $directory );
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
my %Node;
{
	my @header;
	open my $fh, '<', $table or die $!;
	LINE: while(<$fh>) {
		chomp;

		# create header row
		if ( not @header ) {
			@header = split /\t/, $_;
			next LINE;
		}
		my @fields = split /\t/, $_;
		my %record = map { $header[$_] => $fields[$_] } 0 .. $#header;
		my $id = delete $record{'ID'};
		
		# pseudo objects with data from table
		$Node{$id} = \%record;
	}
	close $fh;
}

my %seen;
my %root;
my $tree = $fac->create_tree;
for my $id ( grep { $Node{$_}->{Rank} eq 'phylum' } keys %Node ) {

	# fetch taxon from database
	$log->info("ID: $id");
	my $taxon = $db->get_taxon( '-taxonid' => $id );
	
	# instantiate bio::phylo node
	my $node  = $fac->create_node(
		'-guid'    => $id,
		'-name'    => $Node{$id}->{'Name'},
		'-generic' => $Node{$id},
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
#$tree->visit(sub{ shift->set_branch_length(1) });
#$tree->ultrametricize;

open my $fh,  '>', $outfile or die $!;
open my $lfh, '>', $labeltrack or die $!;
open my $sfh, '>', $scattertrack or die $!;
my $tipcounter = 1;

# now add as many tips as needed to make the width to size
$tree->visit_depth_first(
	'-post' => sub{
		my $node = shift;
		if ( $node->is_terminal ) {
			my $id   = $node->get_guid;			
			my $name = $node->get_name;		
			
			# compute number of tips to add
			my @tips = sort { $Node{$a}->{Pos} <=> $Node{$b}->{Pos} }  
				   grep { $Node{$_}->{Phylum} == $id && $Node{$_}->{ChildCount} == 0 } keys %Node;
			my $count = int( scalar(@tips) / $scale ) || 1;
			
			# add tips
 			for my $i ( 1 .. $count ) {
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
			   scalar(@tips), " ",
			         'black', "\n";

			# write circos label track
			print   $lfh $id, " ",
			               0, " ",
			   scalar(@tips), " ",
			           $name, "\n";

			# write circos scatter track
			for my $i ( 0 .. $#tips ) {
				my $studies = $Node{$tips[$i]}->{Studies};
				if ( $studies ) {
					print $sfh $id, " ",
					            $i, " ",
                	                            $i, " ",
		        	              $studies, "\n";
				}
			}

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
