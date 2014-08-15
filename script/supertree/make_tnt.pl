#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

no warnings 'uninitialized';

# given an input file, which contains the MRP matrices for all trees in a
# study, emits a separate TNT data file for each matrix. this script is
# executed by the 'make tntdata' target.

# see: http://tnt.insectmuseum.org/index.php/How_to_manage_several_datasets
# note that the default RAM allocated by TNT at time of writing is 16Mb, 
# whereas the full data set at present appears to require more something like
# 50Gb(!)

# process command line arguments
my $infile;
GetOptions(
	'infile=s' => \$infile,
);

# read infile
my %tables;
{
	open my $fh, '<', $infile or die $!;
	while(<$fh>) {
		chomp;
		my @line = split /\t/, $_;
		my $block = shift @line;
		$tables{$block} = {} if not $tables{$block};
		$tables{$block}->{$line[0]} = $line[1];
	}
	close $fh;
}

# iterate over tables
my @blocks = sort { $a cmp $b } keys %tables;
for my $i ( 0 .. $#blocks ) {
	my $block = $blocks[$i];
	
	# print header
	my $matrix = "Label data\n";
	
	# iterate over rows
	my $nchar;
	ROW: for my $row ( keys %{ $tables{$block} } ) {

		# fetch the seq, move to next row if the 
		# entire row consists of missing data
                my $seq = $tables{$block}->{$row};
		next ROW if $seq =~ /^\?+$/;

		# append the row label to the matrix
		$matrix .= $row . "\t";
		
		# create ambiguity codes		
		my @char = map { $_ eq '2' ? '[01]' : $_ } split //, $seq;
		$matrix .= join '', @char;
		$matrix .= "\n";
		
		# track $nchar
		if ( not defined $nchar ) {
			$nchar = length($seq);
		}
		elsif ( defined $nchar && $nchar != length($seq) ) {
			die "Block $block in $infile is not flush!";
		}
	}
	
	# print closing token, for the last file this is a semicolon
	my $token = $infile =~ /S99\./ && $i == $#blocks ? ';' : '@@';
	$matrix .= $token . "\n";
	
	# write separate outfile for each matrix
	my $filename = $infile;
	$filename .= ".$block.tnt";
	open my $fh, '>', $filename or die "Can't open $filename: $!";
	print $fh $matrix;
	close $fh;
	
	# print scripting command, this needs to be in same dir, so only local name
	$filename =~ s|^.+/||;
	print '& [ num ] @@ ' . $filename . ' data ;' . "\n";

	# print $nchar to STDERR so we can redirect that as well, notice the
	# invocation in the Makefile
	print STDERR $block, "\t", $nchar, "\n";
}
