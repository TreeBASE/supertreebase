#!/usr/bin/perl
use strict;
use warnings;
use XML::Twig;
use Getopt::Long;
use Bio::DB::Taxonomy;
use Bio::Phylo::Util::Logger ':levels';

# this hack is here so that the NCBI taxonomy indexes aren't deleted
# when the $db object is destroyed
BEGIN { *Bio::DB::Taxonomy::flatfile::DESTROY = sub {} }

# given an input NeXML file, this script fetches all the taxa in it and
# looks up to which Class (i.e. the taxonomic level) they belong. prints
# to STDOUT a tab-separated table with the following columns:
# 1. study ID
# 2. class ID (in NCBI taxonomy)
# 3. number of species in that class
# the idea is that for each XML file in the data folder there will be a
# corresponding .class file that contains this table

# classes seen in the focal file
my %Classes;

# process command line arguments
my ( $infile, $verbosity, $taxadir, $namesfile, $nodesfile );
GetOptions(
	'infile=s'    => \$infile,
	'verbose+'    => \$verbosity,
	'taxadir=s'   => \$taxadir,
	'namesfile=s' => \$namesfile,
	'nodesfile=s' => \$nodesfile,
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
my $twig = XML::Twig->new(
	'twig_handlers' => {
		'nex:nexml/otus/otu/meta' => \&handle_meta,
	}
);

# process the file
eval { $twig->parsefile($infile) };
if ( $@ ) {
	$log->warn("problem parsing $infile: $@");
	exit(0);
}

# print results
my $study_id = $infile;
$study_id =~ s/.+\/(S[0-9]+)\.xml/$1/;
for my $class ( keys %Classes ) {
	print $study_id, "\t", $class, "\t", $Classes{$class}, "\n";
}

sub handle_meta {
	my ( $twig, $elt ) = @_;
	my $href = $elt->att('href');
	if ( $href && $href =~ /purl\.uniprot\.org.+?(\d+)$/ ) {
		my $taxonid = $1;
		$log->info("taxon ID is $taxonid");
		if ( my $class = get_class( $taxonid ) ) {
			$log->info("class for taxon ID $taxonid is $class");
			$Classes{$class}++;
		}
		else {
			$log->warn("no class for $taxonid");
		}
	}
}

sub get_class {
	my $taxonid = shift;
	my $node = $db->get_taxon( '-taxonid' => $taxonid );
	if ( not $node ) {
		$log->warn("no node for $taxonid");
	}
	else {
		no warnings 'uninitialized';
		while( $node && $node->rank ne 'class' ) {
			$node = $node->ancestor;
			if ( $node ) {
				$log->debug("node ".$node->id." has rank ".$node->rank);
			}
		}
		if ( $node && $node->rank eq 'class' ) {
			return $node->id;
		}
	}
	return undef;
}
