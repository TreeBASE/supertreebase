#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Bio::Phylo::Factory;
use Bio::Phylo::Forest::Tree;
use Bio::Phylo::Util::Logger ':levels';
use Bio::Phylo::IO qw'parse_tree unparse';

# The name of this script is a misnomer. In fact it re-assembles trees from MRP matrices.
# the input is a matrix of the form:
# BLOCK_ID <TAB> TAXON_ID <TAB> CHARACTERS

# process command line arguments
my $infile;
my $verbosity = WARN;
my $equal;
GetOptions(
	'infile=s' => \$infile,
	'verbose+' => \$verbosity,
	'equal'    => \$equal,
);

# instantiate helper objects
my $fac = Bio::Phylo::Factory->new;
my $log = Bio::Phylo::Util::Logger->new(
	'-level' => $verbosity,
	'-class' => 'main',
);

# start reading the file
my $block;
my %data;
open my $fh, '<', $infile or die $!;
while(<$fh>) {
	chomp;
	my ( $tb, $name, $char ) = split /\t/, $_;
	if ( not $block ) {
		$block = $tb;
		$data{$name} = $char;
	}
	else {
		if ( $block ne $tb ) {
			$log->info("going to analyze block $block");
			analyze_block( %data );
			%data = ( $name => $char );
			$block = $tb;
		}
		else {
			$data{$name} = $char;
		}	
	}
}
$log->info("going to analyze last block $block");
$log->debug(Dumper(\%data));
analyze_block( %data );

sub analyze_block {
	my %rows = @_;
	
	# make outgroup if needed
	my ($row) = values %rows;
	my $nchar = length $row;
	my ($out) = grep { /outgroup/ } keys %rows;
	if ( not $out ) {
		$out = 'myoutgroup';
		$rows{$out} = '0' x $nchar;
		$log->info("creating outgroup with $nchar characters");
	}
	
	# find the partitions
	my $previous = 0;
	for my $i ( 0 .. ( $nchar - 1 ) ) {
		my %c;
		ROW: for my $row ( keys %rows ) {
			next ROW if $row eq $out;
			my $c = substr $rows{$row}, $i, 1;
			$c{$c} = 1;
		}
		
		# first column is also all 1's but we don't care
		if ( $i != 0 ) {
		
			# found next column with all 1's
			if ( 1 == scalar keys %c ) {
				$log->info("going to analyze matrix $previous..$i");
				analyze_matrix( $previous, $i, %rows );			
				$previous = $i;		
			}
			
			# reached end of data
			elsif ( $i == ( $nchar - 1 ) ) {
				$log->info("going to analyze final matrix $previous..$nchar");
				analyze_matrix( $previous, $nchar, %rows );
			}
		}
	}
}

sub analyze_matrix {
	my ( $start, $end, %data ) = @_;
	
	# populate matrix
	my %matrix;
	my $nchar = ( $end - $start );
	for my $row ( keys %data ) {
		my $char = substr $data{$row}, $start, ( $end - $start );
		$matrix{$row} = [ split //, $char ];
	}	
	
	# sort columns
	my @indices;
	for my $i ( 0 .. $nchar - 1 ) {
		my $total = 0;
		$total += $matrix{$_}->[$i] for keys %matrix;
		push @indices, [ $i, $total ];
	}
	my @sorted = sort { $a->[1] <=> $b->[1] } @indices;
	
	# start building the tree
	my $tree = $fac->create_tree;
	my %tips = map { $_ => $fac->create_node( '-name' => $_ ) } keys %matrix;
	my $root = $fac->create_node;
	$_->set_parent($root) for values %tips;
	$tree->insert($root);
	$tree->insert($_) for values %tips;
	COL: for my $col ( @sorted ) {
		my @tips  = grep { $matrix{$_}->[ $col->[0] ] } keys %matrix; # labels
		my @nodes = @tips{@tips}; # node objects
		my %uniq  = map { $_->get_id => $_ } @nodes;
		@nodes = values %uniq;
		next COL if scalar(@nodes) < 2;
		
		# instantiate new parent
		my $parent = $fac->create_node;
		$_->set_parent($parent) for @nodes;
		$parent->set_parent($root);
		$tree->insert($parent);
		$tips{$_} = $parent for @tips;
	}
	$tree->remove_unbranched_internals;
	my @nameless = grep { $_->get_name eq '' } @{ $tree->get_terminals };
	$tree->prune_tips(\@nameless);
	make_tree_output($tree);
}

sub make_tree_output {
	my $tree = shift;
	$log->info("going to make distance matrix");
	my ($out) = grep { $_->get_name =~ /outgroup/ } @{ $tree->get_terminals };
	$out->set_root_below;
	$tree->prune_tips([$out]);
	$tree->visit(sub{
		my $n = shift;
		if ( $n->is_root ) {
			$n->set_branch_length();
		}
		else {
			$n->set_branch_length(1);
		}
	});
	
	# make ultrametric instead of equal lengths
	if ( not $equal ) {
		my $tallest = 0;
		for my $tip ( @{ $tree->get_terminals } ) {
			my $anc  = $tip->get_ancestors;
			my $len  = scalar @$anc;
			$tallest = $len if $len > $tallest;			
			$tip->set_generic( 'heights' => [ $len ], 'added' => 0 );
			for my $n ( @$anc ) {
				my $heights = $n->get_generic('heights') || [];
				push @$heights, $len;
				$n->set_generic( 'heights' => $heights, 'added' => 0 );
			}
		}
		$tree->visit_depth_first(
			'-pre' => sub {
				my $node = shift;
				if ( not $node->is_root ) {
					my $added = 0;
					if ( my $p = $node->get_parent ) {
						$added = $p->get_generic('added');
					}
					my ($tall) = sort { $b <=> $a } @{ $node->get_generic('heights') };
					my $diff = ( $tallest - $tall ) - $added;
					if ( $diff > 0 ) {
						my $newl = $node->get_branch_length + $diff;
						$node->set_branch_length($newl);
						$node->set_generic( 'added' => $added + $diff );
					}
				}
			}
		);
	}
	
	print $tree->to_newick, "\n";
}

