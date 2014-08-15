#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::Util::Logger ':levels';

# this script creates the links track for circos, i.e.
# $0 -w data/treebase -c metadata/circos/class.txt \
# -r metadata/circos/representation.txt > metadata/circos/links.txt

# process command line arguments
my $verbosity;
my $workdir;        # e.g. 'data/treebase'
my $classes;        # e.g. 'metadata/circos/class.txt'
my $representation; # e.g. 'metadata/circos/representation.txt'
GetOptions(
	'verbose+'    => \$verbosity,
	'workdir=s'   => \$workdir,
	'classes=s'   => \$classes,
	'representation=s' => \$representation,
);

# instantiate helper objects
my $log = Bio::Phylo::Util::Logger->new(
	'-level'      => $verbosity,
	'-class'      => 'main',
);

# read name to ID mapping
my %Id_for_name;
my %Phylum;
{
	$log->info("going to read taxon-to-id mapping from $representation");
	open my $fh, '<', $representation or die $!;
	while(<$fh>) {
		chomp;
		my ( $id, $name, $rank, $studies, $childcount, $phylum ) = split /\t/, $_;
		if ( $rank eq 'class' ) {
			$Id_for_name{$name} = $id;
			$Phylum{$id} = $phylum;
			$log->info("ID mapping: $name => $id (phylum: $phylum)");
		}
	}
}

# read class coordinate file
my %Coordinate;
{
	$log->info("going to read coordinates from $classes");
	open my $fh, '<', $classes or die $!;
	while(<$fh>) {
		chomp;
		my ( $chr, $start, $end, $name ) = split / /;		
		if ( my $id = $Id_for_name{$name} ) {
			$Coordinate{ $id } = $start;
			$log->info("Coordinate: $id => $start");
		}
		else {
			$log->warn("no taxon for $name!");
		}
	}
}

# start reading per-study classes, links are based on those
my %Link;
my %seen;
opendir my $dh, $workdir or die $!;
while( my $entry = readdir $dh ) {

	# skip all other files
	if ( $entry =~ /\.class$/ ) {
	
		# read file
		open my $fh, '<', "${workdir}/${entry}" or die $!;
		my %classes;
		while(<$fh>) {
			chomp;
			my ( $study, $class, $weight ) = split /\t/;
			$classes{$class} = $weight;
		}
		
		# only interested in studies that cross classes
		my @classes = keys %classes;
		if ( 1 < scalar @classes ) {
			my $study = $entry;
			$study =~ s/\.class$//;
			$log->info("$study spans classes");
			for my $i ( 0 .. ( $#classes - 1 ) ) {
			
				# shorthand for the NCBI taxon ID for $i
				my $c1 = $classes[$i];
				
				# shorthand for the start position of the link
				my $start = $Coordinate{$c1};
				if ( not $start ) {
					$log->error("no pos for $c1");
				}
				
				# now compare with all remaining others
				for my $j ( ( $i + 1 ) .. $#classes ) {
					my $c2 = $classes[$j];
					
					# sort these so that we can tell if it's the same link
					my $id = $c1 < $c2 ? "${c1}-${c2}" : "${c2}-${c1}";
					$seen{$id}++; # maybe use this for weights / transparency
					
					# shorthand for the end position of the link
					my $end = $Coordinate{$c2};
					if ( not $end ) {
						$log->error("no pos for $c2");
					}					
					
					# so we don't have duplicates
					if ( not $Link{$id} ) {
						$Link{$id} = [ $start => $end, $study ];
					}
					else {
						push @{ $Link{$id} }, $study;
					}
				}
			}
		}
		else {
			$log->debug("$entry doesn't span classes");
		}
	}
}

my ($max) = sort { $b <=> $a } values %seen;
my $scale = 4 / log($max) / log(3);
$log->info("max: $max");

# now print the links
my $template = 'link-%s tol %i %i thickness=%i,color=%s' . "\n";
for my $id ( keys %Link ) {
	#my $thickness = int ( 4 - ( log($seen{$id}) / log(3) ) * $scale ) + 1;
	my $thickness = $seen{$id};
	my ( $c1, $c2 ) = split /-/, $id;
	my $color = $Phylum{$c1} == $Phylum{$c2} ? 'green' : 'blue';
	my $start = $Link{$id}->[0];
	my $end   = $Link{$id}->[1];
	printf $template, $id, $start-1, $start+1, $thickness, $color;
	printf $template, $id, $end-1, $end+1, $thickness, $color;
	if ( $color eq 'blue' && $seen{$id} >= 10 ) {
		my @studies = @{ $Link{$id} };
		if ( ( $studies[0] == 62 && $studies[1] == 284 ) or ( $studies[0] == 284 && $studies[1] == 62 ) ) {
			$log->info("@studies");
		}
	}
}

