#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::Util::Logger ':levels';

# mapping from TreeBASE NCBI taxon IDs to NCBI species
my %Map;

# keyed on TreeBASE tree block ID, values are array refs
my %Tables;

# process command line options
my ( $speciesfile, $infile, $verbosity );
GetOptions(
	'speciesfile=s' => \$speciesfile,
	'infile=s'      => \$infile,
	'verbose+'      => \$verbosity,
);

# instantiate logger
my $log = Bio::Phylo::Util::Logger->new(
	'-level' => $verbosity,
	'-class' => 'main',
);

# read species file
{
	$log->info("going to read species list from $speciesfile");
	open my $fh, '<', $speciesfile or die $!;
	while(<$fh>) {
		chomp;
		my @line = split /\t/, $_;
		my @species = split /,/, $line[1];
		$Map{$line[0]} = \@species;
	}
	close $fh;
	$log->info("done reading $speciesfile");
}

# read infile
{
	$log->info("going to read MRP data from $infile");
	open my $fh, '<', $infile or die $!;
	while(<$fh>) {
		chomp;
		next if /^$/;
		my @line = split /\t/, $_;
		my $tbid = shift @line;
		$Tables{$tbid} = [] if not exists $Tables{$tbid};
		push @{ $Tables{$tbid} }, \@line;
	}
	close $fh;
	$log->info("done reading $infile");
}

# process tables
# 1. create consensus seq with ambiguity code '2' for duplicate, polyphyletic
#    taxa in input file
# 2. expand higher taxa into those species for which TreeBASE has data
# 3. if this introduces new duplicate seqs, create consensus for those
for my $treeblock ( keys %Tables ) {
	$log->info("processing tree block $treeblock from $infile");
	my %table;
	for my $row ( @{ $Tables{$treeblock} } ) {
		my $taxon = $row->[0];
		my @seq = split //, $row->[1];
				
		# collapse duplicate taxa
		if ( exists $table{$taxon} ) {
			$log->info("multiple taxa $taxon in $treeblock from $infile");
			$table{$taxon} = make_consensus($table{$taxon}, \@seq);
		}
		else {
			$table{$taxon} = \@seq;
		}
	}
	$log->info("going to expand species in $treeblock in $infile");
	expand_species(\%table);
	print_table(\%table,$treeblock);
}

# step 2 & 3
sub expand_species {
	my $table = shift;
	for my $taxon ( keys %{ $table } ) {
		my $seq = $table->{$taxon};
		delete $table->{$taxon};
		
		# resolve duplicates, if present
		for my $species ( @{ $Map{$taxon} } ) {
			if ( exists $table->{$species} ) {
				$table->{$species} = make_consensus($table->{$species},$seq);
			}
			else {
				$table->{$species} = $seq;
			}
		}		
	}
}

# print output
sub print_table {
	my ( $table, $treeblock ) = @_;
	for my $species ( keys %{ $table } ) {
		print $treeblock, "\t", $species, "\t";
		print join '', @{ $table->{$species} };
		print "\n";
	}
}

# makes a consensus sequence with multi-state columns
sub make_consensus {
	my ( $seq1, $seq2 ) = @_;
	my @result;
	for my $i ( 0 .. $#{ $seq1 } ) {
		if ( $seq1->[$i] eq $seq2->[$i] ) {
			push @result, $seq1->[$i];
		}
		else {
			$log->warn("polyphyly at index $i in $infile");
			push @result, 2;
		}
	}
	return \@result;
}

