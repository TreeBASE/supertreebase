#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use List::Util 'sum';
use Bio::Phylo::Util::Logger ':levels';

# process command line arguments
my ( $verbosity, $extension, $ncbifile, $datadir ) = ( WARN, 'tnt', 'data/mrp/ncbi.dat', 'data/treebase' );
GetOptions(
	'verbose+'    => \$verbosity,
	'extension=s' => \$extension,
	'ncbifile=s'  => \$ncbifile,
	'datadir=s'   => \$datadir,
);

# instantiate helper objects
my $log = Bio::Phylo::Util::Logger->new(
	'-class' => 'main',
	'-level' => $verbosity,
);
$log->info("ncbifile  => $ncbifile");
$log->info("datadir   => $datadir");
$log->info("extension => $extension");

# total number of characters
my $Nchar = 0;

# key count will be total number of taxa
my %Taxa;

# total list of files to include
my @files;

my $ncbiTNTfile = $ncbifile;
$ncbiTNTfile =~ s/.+\///;
push @files, $ncbiTNTfile;
$ncbiTNTfile = "$datadir/$ncbiTNTfile";

# we start with the NCBI table. this should
# have all the taxa exactly once!
{
	my $nchar;
	my $line = 1;
	$log->info("going to read from ncbi file");
	open my $fh, '<', $ncbifile or die $!;
	open my $outfh, '>', $ncbiTNTfile or die $!;
	print $outfh "Label data\n";
	while(<$fh>) {
		chomp;
		my ( $taxon, $seq ) = split /\t/, $_;

		# set the seq length on the first line
		if ( not defined $nchar ) {
			$nchar = length $seq;
		}

		# all following lines should have the same value
		else {
			if ( length $seq != $nchar ) {
				$log->error("NCBI table is not flush at line $line");
				die;
			}
		}

		# all taxa must occur only once
		if ( not $Taxa{$taxon} ) {
			$Taxa{$taxon} = 1;
		}
		else {
			$log->error("taxon $taxon occurs again at line $line");
			die;
		}
		$log->info("line $line") unless $line % 1000;
		$line++;
		print $outfh $taxon, "\t", $seq, "\n";
	}
	$Nchar = $nchar;
	print $outfh "@@\n";
}
$log->info("$ncbiTNTfile has $Nchar characters and ".scalar(keys(%Taxa))." taxa");

# now read the tnt files
opendir my $dh, $datadir or die $!;
while( my $file = readdir $dh ) {
	$log->debug("$file");

	# skip all other files
	if ( $file =~ /\.$extension$/ ) {
		$log->debug("going to read $datadir/$file");
		open my $fh, '<', "$datadir/$file" or die $!;
		my $nchar;
		my $line = 1;
		while(<$fh>) {
			chomp;
			if ( /^(\d+)\s+(.+)$/ ) {
				my ( $taxon, $seq ) = ( $1, $2 );
				$seq =~ s/\[01\]/2/g;

				# set the seq length on the first data line
				if ( not defined $nchar ) {
					$nchar = length $seq;
				}
				else {
					if ( length $seq != $nchar ) {
						$log->error("$datadir/$file is not flush at line $line");
						die;
					}
				}

				# check if the taxon has been seen (now it has to be)
				if ( $Taxa{$taxon} ) {
					$Taxa{$taxon}++;
				}
				else {
					$Taxa{$taxon}++;
					$log->warn("taxon $taxon should have been known in $datadir/$file line $line");
				}
			}
			$line++;
		}

		# check if file wasn't empty
		if ( $nchar ) {
			$Nchar += $nchar;
			push @files, $file;
		}
		else {
			$log->warn("no characters in $datadir/$file, skipping...");
		}
	}
}

# compute ntax
my $Ntax = scalar keys %Taxa;
my $mean = sum( values %Taxa ) / $Ntax;
$log->info("taxa occur on average $mean times");

print <<"HERE";
macro=;
/* execute me by starting up TNT and then type 'proc <scriptname> ;' */
/* note that you will need to increase memory to at least 50Gb! */
/* memory is increased in megabytes, e.g. using 'mxram 50000 ;' */
nstates 2;
xread 
$Nchar $Ntax
HERE

# print the file inclusion commands
my $template = '& [ num ] @@ %s data ;' . "\n";
printf $template, $_ for @files;
print "proc/;\n";
