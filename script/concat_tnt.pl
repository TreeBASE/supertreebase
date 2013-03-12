#!/usr/bin/perl

use strict;
use DBI;

# define the min number of OTUs per matrix
my $minotus = 3;

my $database = "concat";
my $username = "piel";
my $password = "";
my $dbh = &ConnectToPg($database, $username, $password);

$dbh->do("DROP INDEX IF EXISTS taxon_indx");
$dbh->do("DROP TABLE IF EXISTS matrix");
$dbh->do("CREATE TABLE matrix (id SERIAL PRIMARY KEY, taxon INT, charscore TEXT, nchar INT) ");

my $dir = $ENV{"PWD"};
opendir (LST,"$dir") || die "Cannot open $dir";
	my @list = readdir(LST);
closedir (LST);
my @taxlist;
@list = grep(/^[^\.]/, @list);
@list = grep(/\.tnt$/, @list);
@list = sort {($a <=> $b) || ($a cmp $b)} @list;
my %rows;
my $hichar = 0;

for (my $cnt = 0; $cnt < @list; $cnt++) {
	my %newchars = ();
	my $nchar = 0;
	print $cnt + 1;
	print ' / ' . eval(@list);
	print " " . $list[$cnt];
	
	open(INPUT, $list[$cnt]) || die "Cannot open $list[$cnt]: $!";
		<INPUT>;
		while (<INPUT>) { 
			chomp;
			my ($taxid, $chars) = split(/\t/,$_);
			if ($taxid ne '@@') {
				$newchars{ $taxid } = $chars;
				if ($nchar == 0) {
					$chars =~ s/\[[^\]]+\]/a/g;
					$nchar = length( $chars );
				}
			}
		}
	close (INPUT);
	
	if (scalar ( keys( %newchars ) ) >= $minotus ) {
		print "\n";
		foreach my $newfiletax ( keys( %newchars ) ) {
			if ( !( defined( $rows{ $newfiletax } ) ) ) {
				$rows{ $newfiletax } = $newfiletax;
				$dbh->do("INSERT INTO matrix (taxon, nchar) VALUES ( ?, ? )", undef, $newfiletax, $hichar) if ( $hichar );
				push @taxlist, $newfiletax;
			}
		}
		foreach my $tax ( keys(%rows) ) {
			if ( defined( $newchars{ $tax } ) ) {
				$dbh->do("INSERT INTO matrix (taxon, charscore) VALUES ( ?, ? )", undef, $tax, $newchars{ $tax } );
			} else {
				$dbh->do("INSERT INTO matrix (taxon, nchar) VALUES ( ?, ? )", undef, $tax, $nchar );
			}
		}
		$hichar = $hichar + $nchar;
	} else {
		print " Rejecting $list[$cnt] because it only has " . keys( %newchars ) . " OTUs\n";
	}

}

$dbh->do("CREATE INDEX taxon_indx ON matrix USING btree (taxon)");

my $statement = "SELECT nchar, charscore FROM matrix WHERE taxon = ? ORDER BY id ";
my $sth = $dbh->prepare($statement) or die "Can't prepare $statement: $dbh->errstr\n";		

open(OUT, ">concat.txt") || die "Cannot open concat.txt!: $!";
for (my $cnt = 0; $cnt < @taxlist; $cnt++) {
	print $cnt + 1;
	print ' / ' . eval(@taxlist);
	print " " . $taxlist[$cnt] ."\n";
	print OUT $taxlist[$cnt] ."\t";

	my $rv = $sth->execute( $taxlist[$cnt] ) or die "Can't execute the query: $sth->errstr\n";
	
	while(my @row = $sth->fetchrow_array) {
		if ($row[0]) {
			print OUT "?" x $row[0];
		} else {
			print OUT $row[1];
		}
	}
	my $rd = $sth->finish;
	print OUT "\n";
}

$dbh->disconnect();


# Connect to Postgres using DBI
#==============================================================
sub ConnectToPg {
 
	my ($cstr, $user, $pass) = @_;
 
	$cstr = "DBI:Pg:dbname="."$cstr";
	#$cstr .= ";host=10.9.1.1";

	my $dbh = DBI->connect($cstr, $user, $pass, {pg_enable_utf8 => 1, PrintError => 1, RaiseError => 1});
 
	$dbh || &error("DBI connect failed : ",$dbh->errstr);
 
	return($dbh);
}
