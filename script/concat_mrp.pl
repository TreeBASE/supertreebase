#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::Factory;
use Bio::Phylo::Util::Logger ':levels';

# the growing MRP table
my %Table;

# process command line arguments
my ( $dir, $ncbi, $verbose, $pattern );
GetOptions(
	'dir=s'     => \$dir,
	'ncbi=s'    => \$ncbi,
	'pattern=s' => \$pattern,
	'verbose+'  => \$verbose,
);

# instantiate logger
my $log = Bio::Phylo::Util::Logger->new(
	'-level' => $verbose,
	'-class' => 'main',
);

# read the NCBI MRP matrix
{
	open my $fh, '<', $ncbi or die $!;
	while(<$fh>) {
		chomp;
		my @line   = split /\t/, $_;
		my @fields = split //, $line[1];
		$Table{$line[0]} = \@fields;
	}
	$log->info("read ".scalar(keys(%Table))." records from $ncbi");
	close $fh;
}

#  read TreeBASE MRP matrices
{
	opendir my $dh, $dir or die $!;
	while( my $entry = readdir $dh ) {
		if ( $entry =~ /$pattern/ ) {

			# each file potentially has multiple tables for multiple tree blocks
			for my $table ( read_tables("${dir}/${entry}") ) {
				for my $taxon ( keys %Table ) {
					if ( exists $table->{$taxon} ) {
						push @{ $Table{$taxon} }, @{ $table->{$taxon} };
					}
					else {
						for ( 1 .. $table->{'nchar'} ) {
							push @{ $Table{$taxon} }, '?';
						}
					}
				}
			}
		}
	}
}

# print result
for my $taxon ( keys %Table ) {
	print $taxon, "\t";
	print join '', @{ $Table{$taxon} };
	print "\n";
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
		$tables{$blockid} = {} if not $tables{$blockid};
		my @fields = split //, $seq;
		$tables{$blockid}->{$taxonid} = \@fields;
		
		# store nchar
		if ( scalar(@fields) > $tables{$blockid}->{'nchar'} ) {
			$tables{$blockid}->{'nchar'} = scalar(@fields);
		}				
	}
	close $fh;
	
	# return result
	my @tables = values %tables;
	$log->info("read ".scalar(@tables)." table(s) from $file");
	return @tables;
}