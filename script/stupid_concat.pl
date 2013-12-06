#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::Util::Logger ':levels';

# process command line arguments
my $workdir = 'data/treebase';
my $species = $workdir . '/species.txt';
my $verbosity = WARN;
my $extension = 'tnt';
my $ncbi = $workdir . '/ncbi.tnt';
GetOptions(
	'workdir=s'   => \$workdir,
	'species=s'   => \$species,
	'verbose+'    => \$verbosity,
	'extension=s' => \$extension,
);

# instantiate helper objects
my $log = Bio::Phylo::Util::Logger->new(
	'-level' => $verbosity,
	'-class' => 'main',
);

# read species list
my @species;
{
	$log->info("going to read species IDs from $species");
	my %species;
	open my $fh, '<', $species or die $!;
	while(<$fh>) {
		chomp;
		my ( $higher, $species ) = split /\t/, $_;
		my @fields = split /,/, $species;
		$species{$_}++ for @fields;
	}
	@species = keys %species;
	$log->info("read ".scalar(@species)." species from $species");
}

# create list of files
my @files;
{
	$log->info("going to read $extension files from $workdir");
	opendir my $dh, $workdir or die $!;
	@files = map { "$workdir/$_" } grep { $_ !~ /ncbi/ } grep { /\.$extension$/ } readdir $dh;
	closedir $dh;
	$log->info("will process ".scalar(@files)." files in $workdir");
}

# read NCBI in memory
my %NCBI;
my $NCBINCHAR;
{
	$log->info("going to slurp $ncbi into memory");
	open my $fh, '<', $ncbi or die $!;
	LINE: while(<$fh>) {
		chomp;
		my ( $id, $chars ) = split /\t/, $_;
		next LINE if $id !~ /\d+/;
		if ( not defined $NCBINCHAR ) {
			$NCBINCHAR = length $chars; # no ambiguity here
		}	
		$NCBI{$id} = $chars;
	}
	$log->info("done slurping $ncbi");
}

# now just iterate like an idiot
my $total_nchar = 0;
for my $i ( 0 .. $#species ) {
	my $taxon = $species[$i];
	$log->info("writing data for $i/".scalar(@species)." - $taxon");
	print $taxon, "\t";
	FILE: for my $file ( @files ) {
		$log->debug("reading file $file");
		my $nchar;
		open my $fh, '<', $file or die $!;
		LINE: while(<$fh>) {
			chomp;
			my ( $id, $chars ) = split /\t/, $_;
			next LINE if $id !~ /\d+/;
			if ( not defined $nchar ) {
				my $seq = $chars;
				$seq =~ s/\[01\]/a/g;
				$nchar = length $seq;
				$total_nchar += $nchar;
			}	
			if ( $id == $taxon ) {
				print $chars;
				next FILE;
			}
		}
		print '?' x $nchar;
	}
	if ( $NCBI{$taxon} ) {
		print $NCBI{$taxon};
	}
	else {
		$log->warn("taxon $taxon not in $ncbi");
		print '?' x $NCBINCHAR;
	}
	print "\n";
}

# done
$log->info("nchar: $total_nchar ntax: ".scalar(@species));
