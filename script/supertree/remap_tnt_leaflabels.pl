#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::DB::Taxonomy;
use Bio::Phylo::Util::Logger ':levels';

# process command line arguments
my ( $infile, $workdir, $nodesfile, $namesfile, $directory, $verbosity );
GetOptions(
	'infile=s'    => \$infile,
	'workdir=s'   => \$workdir,
	'nodesfile=s' => \$nodesfile,
	'namesfile=s' => \$namesfile,
	'directory=s' => \$directory,
	'verbose+'    => \$verbosity,
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

# strip the TNT bullshit from their goddamn tree format
my $string;
{
	$log->info("going to read TNT tree from $infile");
	open my $fh, '<', $infile or die $!;
	while(<$fh>){
		chomp;
		next if /^tread/;
		next if /^proc/;
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
							$lookup{$index} = $name;
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

# the string now holds NCBI taxon IDs
$string =~ s/(\d+)/$lookup{$1}/g;

# strip spaces before closing parentheses
$string =~ s/ ([\)])//g;

# replace remaining spaces with commas
$string =~ tr/ /,/;

# place commas between sister clades
$string =~ s/([^,\(])\(/$1,(/g;

print $string;
