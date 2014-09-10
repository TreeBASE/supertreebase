#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::DB::Taxonomy;
use Bio::Phylo::Util::Logger ':levels';

# process command line arguments
my ( $infile, $workdir, $nodesfile, $namesfile, $directory, $verbosity, $labels, $tnt );
GetOptions(
	'infile=s'    => \$infile,
	'workdir=s'   => \$workdir,
	'nodesfile=s' => \$nodesfile,
	'namesfile=s' => \$namesfile,
	'directory=s' => \$directory,
	'verbose+'    => \$verbosity,
	'labels'      => \$labels, # set to true to use labels instead of IDs
	'tnt'         => \$tnt,
);

# instantiate helper objects
my $log = Bio::Phylo::Util::Logger->new(
        '-level' => $verbosity,
        '-class' => 'main',
);

# instantiate database object
$log->info("nodesfile => $nodesfile");
$log->info("namesfile => $namesfile");
$log->info("directory => $directory");
my $db = Bio::DB::Taxonomy->new(
	'-source'    => 'flatfile',
	'-nodesfile' => $nodesfile,
	'-namesfile' => $namesfile,
	'-directory' => $directory,
	'-force'     => 1, # XXX this should NOT!!!! be needed
);

# strip the TNT commands from their tree format
my $string;
{
	$log->info("going to read TNT tree from $infile");
	open my $fh, '<', $infile or die $!;
	while(<$fh>){
		chomp;
		next unless /^\(/;
		$string .= $_;
	}
	$log->info("done reading TNT tree");
}

# create a lookup from taxon label to index, i.e. the order in which it was encountered
# in the input files.
my %lookup;
my %name_for_id;
{
	$log->info("going to read taxon IDs from files in $workdir");
	my $i = 0;
	opendir my $dh, $workdir or die $!;
	while( my $entry = readdir $dh ) {

		# S12622.dat.Tb17032.tnt
		if ( $entry =~ /\.tnt$/ ) {
			open my $fh, '<', "${workdir}/${entry}" or die $!;
			LINE: while(<$fh>) {
				if ( /^(\d+)\s/ ) {
					my $id = $1;

					# only lookup this name the first time this ID is seen
					if ( not $name_for_id{$id} ) {

						# mrp_outgroup
						if ( $id eq '00000' ) {
							$name_for_id{$id} = 'mrp_outgroup';
							my $index = $i++;
							$lookup{$index} = 'mrp_outgroup';
						}

						# fetch the binomial if not yet done so
						elsif ( my $taxon = $db->get_Taxonomy_Node( '-taxonid' => $id ) ) {
							my $name = $taxon->scientific_name;
	
							# lordy lordy, what's in a name? In any case, avoid
							# unsafe characters: ,(); and replace spaces with 
							# underscores
							$name =~ s/ /_/g;      # replaces spaces w underscores
							$name =~ s/\(.+?\)//g; # strip taxonomic authority suffix
							$name =~ s/[,;]/./g;   # commas and semicolons become periods
							$name_for_id{$id} = $name;
							
							# only increment the index for distinct names
							my $index = $i++;
							$index += 1 if not $tnt; # tnt nexus uses 1-based index
							$lookup{$index} = $labels ? $name : $id;
							$log->info("looked up name $i ($name)") unless $i % 1000;
						}
						else {
							$log->warn("no taxon for $id");
						}
					}
				}
			}
		}
	}
	$log->info("done reading taxon IDs");
}

# the string now holds escaped NCBI taxon binomials
$string =~ s/(\d+)/$lookup{$1}/g;

# convert TNT tree string to newick
if ( $tnt ) {

	# replace all spaces with commas
	$string =~ s/\s/,/g;

	# replace )( with ),(
	$string =~ s/\)\(/),(/g;

	# replace ",)" with ")"
	$string =~ s/,\)/)/g;

}

print $string;
