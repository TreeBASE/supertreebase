#!/usr/bin/perl
use strict;
use warnings;
use IO::Handle;
use Getopt::Long;
use List::Util 'sum';
use Bio::DB::Taxonomy;
use Bio::Phylo::Factory;
use Bio::Phylo::Util::Logger ':levels';

# this hack is here so that the NCBI taxonomy indexes aren't deleted
# when the $db object is destroyed
BEGIN { *Bio::DB::Taxonomy::flatfile::DESTROY = sub {} }

# given the table 'representation.txt', writes out the following
# circos tracks:
# - bands.txt   - dummy single line of "chromosomal bands"
# - scatter.txt - scatter plot track with taxon sampling density
# - <taxon>.txt and <taxon>-span.txt - labelled and unlabelled track for focal taxon,
#                                    - where taxon starts at $tiplevel and proceeds
#                                    - through all levels defined by @levels 

# logging verbosity
my $verbosity;

# working directory and outfiles
my $workdir;      # e.g. metadata/circos
my $bandstrack;   # e.g. metadata/circos/bands.txt
my $scattertrack; # e.g. metadata/circos/scatter.txt
my $table;        # e.g. metadata/circos/representation.txt

# files and dir for NCBI taxonomy
my $taxadir;   # e.g. data/taxdmp/tmp
my $namesfile; # e.g. data/taxdmp/names.dmp
my $nodesfile; # e.g. data/taxdmp/nodes.dmp

# taxonomic levels of interest. these will result in circos tracks,
# i.e. class.txt and class-span.txt, phylum.txt and phylum-span.txt, etc.

my $tiplevel = 'class';
my @levels = qw(class phylum superkingdom);

GetOptions( 
	'verbose+'       => \$verbosity,	
	'workdir=s'      => \$workdir,
	'bandstrack=s'   => \$bandstrack,
	'scattertrack=s' => \$scattertrack,
	'table=s'        => \$table,	
	'taxadir=s'      => \$taxadir,	
	'namesfile=s'    => \$namesfile,
	'nodesfile=s'    => \$nodesfile,
	'tiplevel=s'     => \$tiplevel,
	'level=s'        => \@levels,
);

# instantiate helper objects
my $log = Bio::Phylo::Util::Logger->new(
	'-level' => $verbosity,
	'-class' => 'main',
);
my $db = Bio::DB::Taxonomy->new(
	'-source'    => 'flatfile',
	'-nodesfile' => $nodesfile,
	'-namesfile' => $namesfile,
	'-directory' => $taxadir,	
);
my $fac = Bio::Phylo::Factory->new;

# read file representation.txt, created by representation.pl
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
		my $id = $record{'ID'};
		
		# pseudo objects with data from table
		$Node{$id} = \%record;
	}
	close $fh;
	$log->info("done reading $table");
}

# build simplified version of taxonomy tree
my %seen;
my $tree = $fac->create_tree;
for my $id ( grep { $Node{$_}->{'Rank'} eq $tiplevel } keys %Node ) {

	# fetch taxon from database
	$log->info("going to build path for $id");
	my $taxon = $db->get_taxon( '-taxonid' => $id );
	
	# instantiate bio::phylo node
	my $node  = $fac->create_node(
		'-guid'    => $id,
		'-name'    => $Node{$id}->{'Name'},
		'-generic' => $Node{$id},
	);
	$tree->insert($node);
	
	# traverse to all ancestors
	ANCESTOR : while ( my $ancestor = $taxon->ancestor ) {
		my $ancestor_id = $ancestor->id;
		my $parent = $seen{$ancestor_id}; # check cache
		$log->info("ancestor: $ancestor_id");
		
		# for the first tip we will need to travel all the way
		# to the root. Then, less so.
		if ( not $parent ) {
		
			# create parent node
			$parent = $fac->create_node(
				'-guid'    => $ancestor_id,
				'-name'    => $Node{$ancestor_id}->{'Name'},
				'-generic' => $Node{$ancestor_id},
			);
			$tree->insert($parent);
			$node->set_parent($parent);			
			$seen{$ancestor_id} = $parent; # store in cache
			
			# continue traversal
			$node  = $parent;
			$taxon = $ancestor;			
		}
		else {
			$log->info("done building path for $id");
			$node->set_parent($parent);
			last ANCESTOR;
		}
	}
}
$tree->remove_unbranched_internals;
$tree->remove_orphans;

# open handles to write to
my %handles = ( 'bands' => undef, 'scatter' => undef );
open $handles{'bands'},   '>', $bandstrack   or die $!;
open $handles{'scatter'}, '>', $scattertrack or die $!;
for my $l ( @levels ) {
	open $handles{$l}, '>', "${workdir}/${l}.txt" or die $!;
	open $handles{"${l}-span"}, '>', "${workdir}/${l}-span.txt" or die $!;
}

# this writes repetitive labels so that we can align 
# the radial tree with the circos viz
sub write_label {
	my ( $handle, $start, $end, $name ) = @_;
	if ( $name ) {
		$handle->print( "tol $start $end $name\n" );
	}
	else {
		$handle->print( "tol $start $end\n" );
	}
}

# write circos scatter track
sub write_scatter {
	my ( $handle, $location, $studies ) = @_;
	my $start = $location - 1;
	my $end   = $location + 1;
	$handle->print( "tol $start $end $studies\n" );
}

# traverse the tree to write circos bands
my $tipcounter = 0;
my %precount;
traverse( $tree->get_root );

sub traverse {
	my $node = shift;
	my @children = @{ $node->get_children };
	
	# node is terminal
	if ( not @children ) {
		$tipcounter += 2;	
		my $studies_per_species = ( $node->get_generic('Studies') || 1 ) / ( $node->get_generic('ChildCount') || 1 );
		my $log = log($studies_per_species) / log(10);
		write_scatter( $handles{'scatter'}, $tipcounter, $log );		
	}
	
	# store current tip count
	my $guid = $node->get_guid;	
	$precount{$guid} = $tipcounter;	
	
	# traverse further
	traverse($_) for @children;
	
	# write label
	my $rank = $node->get_generic('Rank');
	if ( $rank && exists $handles{$rank} ) {
		my $start = @children ? $precount{$guid} + 2 : $precount{$guid};
		
		# write the label track
		my $fh = $handles{$rank};		
		write_label( $fh, $start, $tipcounter, $node->get_name );
		
		# write the span track
		my $spanfh = $handles{"${rank}-span"};
		write_label( $spanfh, $start, $tipcounter );
	}	
}

# add one more step for even spacing
$tipcounter++;
$handles{'bands'}->print( "chr - tol tol 1 $tipcounter black\n" );
