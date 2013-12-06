#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::Util::Logger ':levels';
use DBI;

# first create a database and a user, e.g.
# CREATE DATABASE concat WITH TEMPLATE = template1;
# CREATE USER supertreebase;
# GRANT ALL ON concat TO supertreebase;

# define the min number of OTUs per matrix
my $minotus = 3;

# database connection parameters
my $database = "concat";
my $username = "supertreebase";
my $password = "";

# working directory
my $dir = 'data/treebase';

# logging verbosity
my $verbosity = WARN;

# output file
my $outfile = $dir . '/concat.txt';

# process command line arguments
GetOptions(
	'db=s'       => \$database,
	'user=s'     => \$username,
	'password=s' => \$password,
	'verbose+'   => \$verbosity,
	'workdir=s'  => \$dir,
	'outfile=s'  => \$outfile,
	'minotus=i'  => \$minotus,
);

# instantiate helper objects
my $log = Bio::Phylo::Util::Logger->new(
	'-class' => 'main',
	'-level' => $verbosity,
);
my $dbh = ConnectToPg($database, $username, $password);

# clean up database
$dbh->do("DROP INDEX IF EXISTS taxon_indx");
$dbh->do("DROP TABLE IF EXISTS matrix");
$dbh->do("CREATE TABLE matrix (id SERIAL PRIMARY KEY, taxon INT, charscore TEXT, nchar INT) ");
$log->info("cleaned up database $database (user:${username},pass:${password})");

# read list of files to concatenate
my @list;
{
	opendir my $dh, $dir or die "Cannot open ${dir}: $!";
	@list = readdir $dh;
	closedir $dh;

	# ignore dot files
	@list = grep(/^[^\.]/, @list);
	
	# keep files with tnt extension
	@list = grep(/\.tnt$/, @list);

	# sort list
	@list = sort { $a cmp $b } @list;
	$log->info("created list of files to process in $dir");
}

# keys and values are taxon IDs
my %rows;

# will be the source of nchar
my $hichar = 0;

# list of taxon IDs in order of appearance
my @taxlist;

# iterate over files
for my $cnt ( 0 .. $#list ) {
	my %newchars = ();
	my $nchar = 0;
	$log->info('processing file '.($cnt+1).'/'.scalar(@list).' - '.$list[$cnt]);

	# open file handle	
	open my $fh, '<', $dir.'/'.$list[$cnt] or die "Cannot open $dir/$list[$cnt]: $!";
	while (<$fh>) { 
		chomp;
		my ( $taxid, $chars ) = split /\t/, $_;

		# skip over the closing token '@@' or ';' and the header 'Label data'
		if ( $taxid =~ /\d+/ ) {
			$newchars{ $taxid } = $chars;

			# store nchar if we haven't done so already
			if ( $nchar == 0 ) {

				# replace ambiguity codes
				$chars =~ s/\[[^\]]+\]/a/g;
				$nchar = length $chars;
			}
		}
	}
	close $fh;
	
	# skip over data sets that are not phylogenetically informative
	if ( $minotus <= scalar keys %newchars ) {

		# iterate over taxa in current file
		for my $newfiletax ( keys %newchars ) {

			# not yet seen this taxon, create a record for it
			if ( ! defined $rows{ $newfiletax } ) {
				$rows{ $newfiletax } = $newfiletax;
				$dbh->do("INSERT INTO matrix (taxon, nchar) VALUES ( ?, ? )", undef, $newfiletax, $hichar) if $hichar;

				# store focal taxon, this will always be unique because %rows hash
				push @taxlist, $newfiletax;
				$log->debug("created new record for $newfiletax");
			}
		}

		# iterate over all taxa
		for my $tax ( keys %rows ) {

			# have data in current file
			if ( defined $newchars{ $tax } ) {

				# store character data
				$dbh->do("INSERT INTO matrix (taxon, charscore) VALUES ( ?, ? )", undef, $tax, $newchars{ $tax } );
				$log->debug("stored new character data for $tax");
			} 
			else {
				# no data in current file, store number of missing characters
				$dbh->do("INSERT INTO matrix (taxon, nchar) VALUES ( ?, ? )", undef, $tax, $nchar );
				$log->debug("stored number of missing characters for $tax");
			}
		}
		$hichar = $hichar + $nchar;
	} 

	# skip
	else {
		$log->info("rejecting $list[$cnt] because it only has " . keys( %newchars ) . " OTUs");
	}

}
$log->info("done processing files, found ".scalar(@taxlist)." taxa with $hichar characters");

# add index once data is loaded
$dbh->do("CREATE INDEX taxon_indx ON matrix USING btree (taxon)");

# either use the raw character data or the number of missing characters
my $statement = "SELECT nchar, charscore FROM matrix WHERE taxon = ? ORDER BY id ";
my $sth = $dbh->prepare($statement) or die "Can't prepare $statement: ".$dbh->errstr;		

# open handle to concatenated outfile
open my $outfh, '>', $outfile or die "Cannot open ${outfile}!: $!";
$log->info("going to write concatenated matrix to $outfile");

# iterate over all taxa
for my $cnt ( 0 .. $#taxlist ) {
	$log->info('writing taxon '.($cnt+1).'/'.scalar(@taxlist).' - '.$taxlist[$cnt]);

	# write taxon id
	print $outfh $taxlist[$cnt] . "\t";

	# fetch data
	my $rv = $sth->execute( $taxlist[$cnt] ) or die "Can't execute the query: ".$sth->errstr;
	
	# iterate over results
	while ( my @row = $sth->fetchrow_array ) {

		# row[0] is number of missing characters
		if ($row[0]) {
			print $outfh "?" x $row[0];
		}

		# row[1] is raw character data
		else {
			print $outfh $row[1];
		}
	}
	# done fetching results for focal taxon
	my $rd = $sth->finish;

	# on to the next line!
	print $outfh "\n";
}

$dbh->disconnect();
$log->info("done writing $outfile - ".scalar(@taxlist)." taxa with $hichar characters");

# Connect to Postgres using DBI
sub ConnectToPg { 
	my ($cstr, $user, $pass) = @_;
	$log->info("trying to connect to ${cstr}, user='${user}', pass='${pass}'"); 

	$cstr = "DBI:Pg:dbname="."$cstr";
	#$cstr .= ";host=10.9.1.1";

	my $dbh = DBI->connect($cstr, $user, $pass, {pg_enable_utf8 => 1, PrintError => 1, RaiseError => 1});
 
	$dbh || $log->error("DBI connect failed : ",$dbh->errstr);
 
	return $dbh;
}
