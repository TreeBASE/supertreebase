#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::DB::Taxonomy;
use Bio::Phylo::Factory;
use Bio::Phylo::Util::Logger ':levels';

# process command line arguments
my ( $nodesfile, $namesfile, $directory, $taxafile, $verbosity );
GetOptions(
    'nodesfile=s' => \$nodesfile,
    'namesfile=s' => \$namesfile,
    'directory=s' => \$directory,
    'taxafile=s'  => \$taxafile,
    'verbose+'    => \$verbosity,
);

# instantiate logger
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
);

# read taxon IDs that were encountered in treebase
$log->info("going to read treebase taxon ids from $taxafile");
my @ids;
{
	open my $fh, '<', $taxafile or die $!;
	while(<$fh>) {
		chomp;
		if ( /^\s*\d+\s+(\d+)/ ) {
			my $id = $1;
			push @ids, $id;
		}
		else {
			$log->warn("unexpected pattern in $taxafile: $_");
		}
	}
	close $fh;
}

# for each id:
# 1. retain if it is a species
# 2. collapse up to species if a subspecies
# 3. expand to TreeBASE species if a higher taxon
# 4. keep higher taxon if no TreeBASE species exist
# 5. ignore unranked taxa (e.g. "no rank")
$log->info("going to normalize ".scalar(@ids)." taxon IDs");

# XXX verify that these are the only
# below-species ranks in the NCBI taxonomy
my %lower = (
	'forma'      => 1,
	'subspecies' => 1,
	'varietas'   => 1,
);

my (
	%map,     # maps from TreeBASE taxon ID to a comma-separated list of normalized IDs
	@higher,  # contains above species-level TreeBASE taxon IDs
	%species, # contains at and below species-level TreeBASE taxon IDs
);
my $i = 1;
ID: for my $id ( @ids ) {
	
	# fetch the taxon object, this really ought to exist
	my $taxon = $db->get_Taxonomy_Node( '-taxonid' => $id );
	if ( not $taxon ) {
		$log->warn("no taxon for ID $id");
		next ID;
	}
	
	# just for informational purposes		
	my $rank = $taxon->rank;
	$log->info("processing $rank ID $id ($i/".scalar(@ids).")");
	$i++;
	
	# 1. retain if it is a species
	if ( $rank eq 'species' ) {
		$log->debug("ID $id is a species, no need to collapse or expand");
		$map{$id} = {} if not $map{$id};
		$map{$id}->{$id} = 1;
		$species{$id} = 1;
	}
	
	# 2. collapse up to species if lower than species
	elsif ( $lower{$rank} ) {
		$log->debug("ID $id is a $rank, I think I need to collapse this");
		while( $rank ne 'species' ) {
			$taxon = $db->ancestor($taxon);
			if ( not $taxon ) {
				$log->warn("no ancestor for ID $id ($rank)");
				next ID;
			}
			$rank = $taxon->rank;
		}
		my $species_id = $taxon->id;
		$map{$id} = {} if not $map{$id};
		$map{$id}->{$species_id} = 1;
		$species{$species_id} = 1;
	}
	
	# 5: ignore 'no rank'
	elsif ( $rank eq 'no rank' ) {
		$log->warn("ID $id has no rank, can neither collaps nor expand, skipping...");
	}

	# 3/4: prepare for expansion
	else {
		$log->debug("ID $id is a $rank, I think I need to expand this");
		push @higher, $id;
	}
}
$log->info("have identified ".scalar(keys %species)." TreeBASE species so far");

# now expand the higher taxa
my $j = 1;
for my $id ( @higher ) {
	my $taxon = $db->get_Taxonomy_Node( '-taxonid' => $id );
	my $rank = $taxon->rank;
	$log->info("expanding $rank $id ($j/ ".scalar(@higher).")");
	$j++;		
	my @species = get_species_tips($taxon);
	for my $species_id ( @species ) {
		$map{$id} = {} if not $map{$id};
		$map{$id}->{$species_id} = 1;
	}
}

# print results
for my $id ( keys %map ) {
	print $id, "\t";
	print join ',', keys %{ $map{$id} };
	print "\n";
}

# get all species tips that are in TreeBASE...
sub get_species_tips {
	my $taxon = shift;
	my $list = [];
	recurse($taxon,$list);
	
	# if there is at least one species to expand to, do that
	if ( scalar @{ $list } ) {
		return @{ $list };
	}
	
	# otherwise use whatever higher taxon was in TreeBASE
	else {
		return $taxon->id;
	}
}

# ...recursively
sub recurse {
	my ( $taxon, $list ) = @_;
	if ( $taxon->rank eq 'species' ) {
		my $id = $taxon->id;
		if ( $species{$id} ) {
			push @{ $list }, $id;			
		}
		return;
	}
	else {
		for my $child ( $db->each_Descendent($taxon) ) {
			recurse( $child, $list );
		}
	}
}

