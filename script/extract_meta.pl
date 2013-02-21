#!/usr/bin/perl
use strict;
use warnings;
use XML::Twig;
use Getopt::Long;

no warnings 'uninitialized';

# Interesting metadata that can be extracted from TreeBASE files
my @predicates = (
	# document level annotations
	'prism:publicationDate', # publication year

	# annotations on each matrix
	'tb:type.matrix',  # data type, e.g. 'DNA'
	'tb:nchar.matrix', # number of characters
	'tb:ntax.matrix',  # number of taxa

	# annotations on each tree
	'tb:ntax.tree',    # number of taxa
	'tb:quality.tree', # tree quality, e.g. 'Unrated'
	'tb:type.tree',    # tree type, e.g. 'Single'
	'tb:kind.tree',    # tree kind, e.g. 'Species Tree'
);

# the input file or url
my ( $url, $infile );

# process command line arguments
GetOptions(
	'predicates=s' => \@predicates,
	'infile=s'      => \$infile,
	'url=s'        => \$url,
);

# brief usage example
unless( $infile xor $url ) {
	die "Usage: $0 -url <url> [-i <infile>] [-p <predicate>]\n";
}

# this will hold the metadata so we can write it out later
my %meta = (
	'nex:nexml'  => {},
	'characters' => {},
	'tree'       => {},
);

# instantiate the twig object
my $twig = XML::Twig->new(
	'twig_handlers' => {
		'nex:nexml'  => \&nexml_handler,
		'characters' => \&characters_handler,
		'tree'       => \&tree_handler,
	}
);

# parse the input
if ( $url ) {
	$twig->parseurl($url);
}
else {
	$twig->parsefile($infile);
}

# write the output
print join("\t", @predicates), "\n";
my $year = $meta{'nex:nexml'}->{'prism:publicationDate'};
for my $block ( qw(characters tree) ) {
	for my $id ( keys %{ $meta{$block} } ) {
		my @data = map { $meta{$block}->{$id}->{$_} } @predicates;
		$data[0] = $year;
		print join("\t", @data), "\n";
	}
}

# extracts metadata out of the document
sub nexml_handler {
	my ( $twig, $elt ) = @_;
	my @applicable_predicates = grep { $_ !~ /(:?tree|matrix)$/ } @predicates;
	for my $p ( @applicable_predicates ) {
		for my $child ( $elt->children('meta') ) {
			if ( $child->att('property') eq $p ) {
				$meta{ $elt->tag }->{ $p } = $child->att('content');
			}
		}		
	}
}

# extracts metadata out of each characters element
sub characters_handler {
	my ( $twig, $elt ) = @_;
	my $meta = {};
	my @applicable_predicates = grep { /matrix$/ } @predicates;
	for my $p ( @applicable_predicates ) {
		for my $child ( $elt->children('meta') ) {
			if ( $child->att('property') eq $p ) {
				$meta->{ $p } = $child->att('content');
			}
		}
	}
	$meta{ $elt->tag }->{ $elt->att('id') } = $meta;
}

# extracts metatdata out of each tree element
sub tree_handler {
	my ( $twig, $elt ) = @_;
	my $meta = {};
	my @applicable_predicates = grep { /tree$/ } @predicates;
	for my $p ( @applicable_predicates ) {
		for my $child ( $elt->children('meta') ) {
			if ( $child->att('property') eq $p ) {
				$meta->{ $p } = $child->att('content');
			}
		}
	}
	$meta{ $elt->tag }->{ $elt->att('id') } = $meta;
}
