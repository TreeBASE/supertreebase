#!/usr/bin/perl
use strict;
use warnings;
use URI::Escape;
use Getopt::Long;
use Bio::Phylo::Factory;
use Bio::Phylo::IO 'unparse';

# Usage example: 
# perl fetch_treebase_trees.pl --query="dcterms.contributor=Maddison" \
# --format=nexus --section=study

# process command line arguments
my ( $query, $format, $section, $help );
GetOptions(
	'query=s'   => \$query,
	'format=s'  => \$format,
	'section=s' => \$section,
	'help|?'    => \$help,
);
die "Usage: $0 -q \"dcterms.contributor=Maddison\" -f nexus -s study\n";

# instantiate factory
my $fac = Bio::Phylo::Factory->new;

# instantiate client
my $client = $fac->create_client(
	'-base_uri'  => 'http://purl.org/phylo/treebase/phylows/',
	'-authority' => 'TB2',
);

# run query on client
my $desc = $client->get_query_result(
	'-query'   => uri_escape($query),
	'-section' => $section,
);

# iterate over resulting resources
for my $res ( @{ $desc->get_entities } ) {

	# fetch resource data
    my $proj = $client->get_record( '-guid' => $res->get_guid );
    
    # print output
    print unparse(
    	'-phylo'  => $proj,
    	'-format' => $format,
    ), "\n";
}


