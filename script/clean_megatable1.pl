#!/usr/bin/perl
use strict;
#use warnings;
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
			$log->info("taxon $counter, ".scalar(@ones)."/".scalar(@masks)." columns not yet accounted for");

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

			# do basic sanity checking on $nchar
			if ( not defined $nchar ) {
				$nchar = length $raw;
			}
			elsif ( $nchar != length($raw) ) {
				die "table not flush for taxon $counter";
			}
			my $last_index = $nchar - 1;

			# initialize the hash of indices
			if ( not $init ) {
				$log->info("initializing all indices 0 .. $last_index");
				%indices = map { $_ => 1 } 0 .. $last_index;
				$init = 1;
				$log->info("done initializing");
			}

			# iterate over all sites in this sequence
			my $i = 0;
			SITE: while ( $i >= 0 && $i <= $last_index ) {

				# jump to the next stretch of characters
                                $i = nearest( \$raw, $i, '0', '1', '2' );

				# stretch of characters was already evaluated
				if ( $indices{$i} == 0 or $indices{$i} == 2 ) {

					# jump to the end of the stretch, or -1
					$i = nearest( \$raw, $i, '?' );
					next SITE;
				}

				# jump to the end of the stretch of characters
				my $j = nearest( \$raw, $i, '?' );
				#$log->debug("stretch from $i .. $j");

				# length of the stretch is <= $minlength
				if ( $j != -1 && $j - $i <= $minlength ) {

					# mask these columns
					$indices{$_} = 0 for $i .. $j - 1;
					$log->info("will mask sites ${i}-".($j-1));
				}
				else {
					# these columns are legit, first case is for end of line
					if ( $j == -1 ) {
						$indices{$_} = 2 for $i .. $last_index;
					}
					else {
						$indices{$_} = 2 for $i .. $j - 1;
					}
				}
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

sub nearest {
	my ( $stringref, $i, @patterns ) = @_;
	my @is;
	for my $p ( @patterns ) {
		push @is, index $$stringref, $p, $i;
	}
	my ($nearest) = sort { $a <=> $b } grep { $_ != -1 } @is;
	return $nearest || -1;
}

# now do the masking
$log->info("going to write masked version of $infile");
{

	# create the bit mask
	my $mask = join '', map { $indices{$_} == 2 ? 1 : 0 } 0 .. ( $nchar - 1 );
	$mask =~ y/01/\x00\xff/;

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
		my $result = $raw & $mask;
		$result =~ s/\x00//g;
		$result =~ s/2/[01]/g;

		# print output
		print $taxon, "\t", $result, "\n";

		$log->info("writing taxon $counter") unless $counter % 100;
		$counter++;
	}
}
