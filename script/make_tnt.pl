#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

# see: http://tnt.insectmuseum.org/index.php/How_to_manage_several_datasets

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
for my $block ( keys %tables ) {
	
	# print header
	my $matrix = "Label data\n";
	
	# iterate over rows
	my $nchar;
	for my $row ( keys %{ $tables{$block} } ) {
		$matrix .= $row . "\t";
		
		# create ambiguity codes		
		my $seq = $tables{$block}->{$row};
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
	my $token = $infile =~ /S9999/ ? ';' : '@@';
	$matrix .= $token . "\n";
	
	# write separate outfile for each matrix
	my $filename = $infile;
	$filename =~ s/\.[^\.]+/-$block.tnt/;
	open my $fh, '>', $filename or die "Can't open $filename: $!";
	print $fh $matrix;
	close $fh;
	
	# print scripting command, this needs to be in same dir, so only local name
	$filename =~ s|^.+/||;
	print '& [ num ] @@ ' . $filename . ' data ;' . "\n";

	# print $nchar to STDERR so we can redirect that as well
	print STDERR $block, "\t", $nchar, "\n";
}
