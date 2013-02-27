#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::DB::Taxonomy;
use Bio::Phylo::Factory;
use Bio::Phylo::Treedrawer;
use Bio::Phylo::Util::Logger ':levels';

# process command line options
my $scale        = 1000;
my $verbosity    = WARN;
my $outfile      = 'metadata/bands.txt';
my $labeltrack   = 'metadata/labels.txt';
my $scattertrack = 'metadata/scatter.txt';
my $figure       = 'metadata/radial.svg';
my $table        = 'metadata/representation.txt';
my $namesfile    = 'data/taxdmp/names.dmp';
my $nodesfile    = 'data/taxdmp/nodes.dmp';
my $directory    = 'data/taxdmp/';
GetOptions( 
	'scale=i'        => \$scale,
	'verbose+'       => \$verbosity,
	'outfile=s'      => \$outfile,	
	'labeltrack=s'   => \$labeltrack,
	'scattertrack=s' => \$scattertrack,
	'figure=s'       => \$figure,
	'table=s'        => \$table,	
	'namesfile=s'    => \$namesfile,
	'nodesfile=s'    => \$nodesfile,
	'directory=s'    => \$directory,
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
	$log->info("going to read data from $table");
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
	$log->info("done reading $table");
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
$tree->remove_unbranched_internals;
$tree->remove_orphans;

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
				       grep { $Node{$_}->{Phylum} == $id && $Node{$_}->{ChildCount} == 0 } 
				       keys %Node;
			my $count = int( scalar(@tips) / $scale ) || 1;
			
			# add tips
 			for my $i ( 1 .. $count ) {
 				my $child = $fac->create_node( 
 					'-branch_color'  => 'white', 				
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
		  scalar(@tips) || 1, " ",
			         'black', "\n";

			# write circos label track
			print   $lfh $id, " ",
			               0, " ",
		  scalar(@tips) || 1, " ",
			           $name, "\n";

			# write circos scatter track
			for my $i ( 0 .. $#tips ) {
				my $studies = $Node{$tips[$i]}->{Studies};
				if ( $studies ) {
					my $log = log($studies) / log(10);
					print $sfh $id, " ",
					            $i, " ",
                	            $i, " ",
		        	          $log, "\n";
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
$td->set_tree($tree);
open my $figfh, '>', $figure or die $!;
print $figfh $td->draw;
