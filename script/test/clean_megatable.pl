#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::Util::Logger ':levels';

# process command line arguments
my $verbosity = WARN;
my $minlength = 1;
my ( $infile, $ncbi );
GetOptions(
	'infile=s'    => \$infile,
	'verbose+'    => \$verbosity,
	'minlength=s' => \$minlength,
	'ncbi=s'      => \$ncbi,
);

# instantiate helper objects
my $log = Bio::Phylo::Util::Logger->new(
	'-level' => $verbosity,
	'-class' => 'main',
);

# report in the end
my %indices;
my $counter = 1;
my $init;
my $ntax;
my $nchar;
my %skipme;

# start reading
$log->info("going to read from $infile");
{
	open my $fh, '<', $infile or die $!;
	LINE: while(<$fh>){
		chomp;

		# report progress
		if ( not $counter % 100 ) {
			my @masks = values %indices;
			my @ones = grep { $_ == 1 } @masks;
			$log->info("taxon $counter, ".scalar(@ones)."/".scalar(@masks)." not yet accounted for");

			# we are done, compute nchar
			if ( scalar(@ones) == 0 ) {
				my @zeros = grep { $_ == 0 } @masks;
				$nchar = scalar(@masks) - scalar(@zeros);
				last LINE;
			}
		}

		# process sequence
		my ( $taxon, $sequence ) = split /\t/, $_;
		if ( substr $sequence, -1 ne '?' or $ncbi ) {

			# get rid of the ambiguity codes, we will put these
			# back in later
			my $raw = $sequence;
			$raw =~ s/\[01\]/2/g;

			# initialize the hash of indices
			if ( not $init ) {
				$log->info("initializing all indices");
				%indices = map { $_ => 1 } 0 .. length($raw) - 1;
				$init = 1;
				$log->info("done initializing");
			}

			# iterate over all sites in this sequence
			my @sites = split //, $raw;
			my $i = 0;
			SITE: while ( $i <= $#sites ) {

				# gradually we assemble more sites to skip over
				if ( $indices{$i} == 0 or $indices{$i} == 2 ) {
					$i++;
					next SITE;
				}

				# start of a stretch of data, need to find out of the 
				# length of the stretch <= $minlength
				if ( $sites[$i] ne '?' ) {
					my $j = $i + 1;

					# start searching forward
					STRETCH: while ( $j <= $#sites ) {

						# at the end of the stretch
						if ( $sites[$j] eq '?' or $j == $#sites ) {

							# length of the stretch is <= $minlength
							if ( $j - $i <= $minlength ) {

								# mask these columns
								$indices{$_} = 0 for $i .. $j - 1;
								$log->info("will mask sites ${i}-".($j-1));
							}
							else {
								# these columns are legit
								$indices{$_} = 2 for $i .. $j - 1;
							}

							# continue onto the next column after this stretch
							$i = $j;
							last STRETCH;
						}
						$j++;
					}
				}
				$i++;
			}
			$ntax++;
		}
		else {
			$log->info("skippping taxon $counter ($taxon, not in NCBI MRP)");
			$skipme{$taxon}++;
		}
		$counter++;
	}
	close $fh;
}

# now do the masking
$log->info("going to write masked version of $infile");
{
	# make sorted list of indices to keep
	my @keep = sort { $a <=> $b } grep { $indices{$_} == 2 } keys %indices;
	$nchar = scalar @keep;

	# print tnt header
	print $nchar, ' ', $ntax, "\n";

	# start reading
	my $counter = 0;
	open my $fh, '<', $infile or die $!;
	while(<$fh>) {
		chomp;
		my ( $taxon, $seq ) = split /\t/, $_;

		# ignore if need be
		next if $skipme{$taxon};

		# replace ambiguity codes with 2
		my $raw = $seq;
		$raw =~ s/\[01\]/2/g;

		# do the masking, map back to ambiguity codes
		my @sites = split //, $raw;
		my @masked = map { $_ == 2 ? '[01]' : $_ } @sites[@keep];

		# print output
		print $taxon, "\t", @masked, "\n";

		$log->info("writing taxon $counter") unless $counter % 100;
		$counter++;
	}
}
