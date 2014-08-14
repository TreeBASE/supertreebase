#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Digest::MD5 'md5';
use Bio::Phylo::Util::Logger ':levels';

# the growing MRP table
my %Table;

# process command line arguments
my ( $dir, $species, $verbose, $pattern );
GetOptions(
	'dir=s'     => \$dir,
	'species=s' => \$species,
	'pattern=s' => \$pattern,
	'verbose+'  => \$verbose,
);

# instantiate logger
my $log = Bio::Phylo::Util::Logger->new(
	'-level' => $verbose,
	'-class' => 'main',
);

# read the species file
{
	open my $fh, '<', $species or die $!;
	while(<$fh>) {
		chomp;
		my @line = split /\t/, $_;
		my @species = split /,/, $line[1];
		$Table{$_} = [] for @species;
	}
	$log->info("read ".scalar(keys(%Table))." records from $species");
	close $fh;
}

#  read TreeBASE MRP matrices
{
	opendir my $dh, $dir or die $!;
	while( my $entry = readdir $dh ) {
		if ( $entry =~ /$pattern/ ) {

			# each file potentially has multiple tables for multiple tree blocks
			my %seen;
			for my $table ( read_tables("${dir}/${entry}") ) {
				for my $taxon ( keys %Table ) {
					my $seq = $table->{$taxon} || ( '?' x $table->{'nchar'} );
					my $digest = md5($seq);
					my $compressed = compress($seq);
					$seen{$digest} = \$compressed if not $seen{$digest};
					push @{ $Table{$taxon} }, $seen{$digest};
				}
			}
		}
	}
}

# print result
for my $taxon ( keys %Table ) {
	print $taxon, "\t";
	for my $ref ( @{ $Table{$taxon} } ) {
		my $compressed = ${ $ref };
		my $expanded = expand($compressed);
		print $expanded;
	}
	print "\n";
}

# compresses MRP seq to two-bit bit vector
sub compress {
	my $seq = shift;
	my %map = (
		'1' => '11',
		'0' => '00',
		'2' => '01',
		'?' => '10',
	);
	my $twobit = join '', map { $map{$_} } split //, $seq;
	my $packed = pack('b*', $twobit);
	return $packed;
}

# expands two-bit bit vector to MRP seq
sub expand {
	my $packed = shift;
	my %rev = (
		'11' => '1',
		'00' => '0',
		'01' => '2',
		'10' => '?',
	);
	my @unpacked = unpack('b*', $packed);
	my @revmapped;
	for ( my $i = 0; $i <= $#unpacked; $i += 2 ) {
		my $twobit = $unpacked[$i] . $unpacked[$i+1];
		push @revmapped, $rev{$twobit};
	}
	return join '', @revmapped;
}

# return a list of table hashes
sub read_tables {
	my $file = shift;
	my %tables;
	
	# read file
	open my $fh, '<', $file or die $!;	
	while(<$fh>) {
		chomp;
		my @line = split /\t/, $_;
		
		# after normalize_tb2_mrp, each taxon is unique within block scope
		my ( $blockid, $taxonid, $seq ) = @line;
		$tables{$blockid} = { 'nchar' => 0 } if not $tables{$blockid};
		$tables{$blockid}->{$taxonid} = $seq;
		
		# store nchar
		if ( length($seq) > $tables{$blockid}->{'nchar'} ) {
			$tables{$blockid}->{'nchar'} = length($seq);
		}				
	}
	close $fh;
	
	# return result
	my @tables = values %tables;
	$log->info("read ".scalar(@tables)." table(s) from $file");
	return @tables;
}