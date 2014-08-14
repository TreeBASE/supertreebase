#!/usr/bin/perl
use strict;
use warnings;
use XML::Twig;
use Getopt::Long;
use Bio::Phylo::Util::CONSTANT '_NS_TB2PURL_';

# This script reads the sitemap.xml file from TreeBASE (which contains a full list
# of all publicly reachable studies in the database) and extracts for each link
# in the site map the study ID (an integer). For each ID for which no corresponding
# URL file has been written it then creates on containing the PhyloWS location that
# returns NeXML. (A URL file is a simple text file with a URL in it. The extension
# .url makes it so that this is a clickable link under OSX.) As this script only
# creates files for IDs that have not been seen yet it can be used incrementally, 
# e.g. by running the 'make purls' target.

# permanent url for treebase phylows
my $PURLBASE = _NS_TB2PURL_;

# process command line arguments
my ( $infile, $outdir, $force );
GetOptions(
	'infile=s' => \$infile,
	'outdir=s' => \$outdir,
	'force+'   => \$force,
);

# instantiate twig, this includes defining a code block that
# is triggered every time a 'loc' element is encountered in
# the site map xml
my $twig = XML::Twig->new(
	'twig_handlers' => {
		
		# process the loc element in a sitemap
		'loc' => sub {
			my ( $twig, $elt ) = @_;
			
			# this is an old-style URL, not a PURL, ending in the study id
			my $url = $elt->text;
			if ( $url =~ m/(\d+)$/ ) {
				my $id = $1;
				my $idstring = 'S' . $id;
				
				# this becomes a clickable (and parseable) web link file
				my $outfile  = "${outdir}/${idstring}.url";
				
				# turn it into a purl that returns NeXML
				my $purl = $PURLBASE . "study/TB2:${idstring}?format=nexml";
				
				# write to file
				if ( not -e $outfile or $force ) {
					open my $fh, '>', $outfile or die $!;
					print $fh $purl;
					close $fh;
				}
			}
		}
	}
);

# now parse the sitemap
$twig->parsefile($infile);
