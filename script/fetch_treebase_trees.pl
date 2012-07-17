#!/usr/bin/perl
use strict;
use warnings;
use URI::Escape;
use Getopt::Long;
use Bio::Phylo::Factory;
use Bio::Phylo::IO 'unparse';

# process command line arguments
my ( $query, $format, $section, $help, $recordSchema );
GetOptions(
	'query=s'        => \$query,
	'format=s'       => \$format,
	'section=s'      => \$section,
	'recordSchema=s' => \$recordSchema,
	'help|?'         => \$help,
);
die "Usage: $0 -q 'dcterms.title==\"Homo sapiens\"' -f newick -s taxon -r tree\n" if $help;

# instantiate factory
my $fac = Bio::Phylo::Factory->new;

# instantiate client
my $client = $fac->create_client(
	'-base_uri'  => 'http://purl.org/phylo/treebase/phylows/',
	'-authority' => 'TB2',
);

# run query on client
my $desc = $client->get_query_result(
	'-query'        => uri_escape($query),
	'-section'      => $section,
	'-recordSchema' => $recordSchema,
);

# iterate over resulting resources
for my $res ( @{ $desc->get_entities } ) {

	# fetch resource data
	$client->set_section($recordSchema);
    my $proj = $client->get_record( '-guid' => $res->get_guid );
    
    # print output
    print unparse(
    	'-phylo'  => $proj,
    	'-format' => $format,
    ), "\n";
}


