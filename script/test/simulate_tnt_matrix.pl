#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

# this is inlined C code to simulate
# random character states
use Inline C => <<'SIMULATOR';

// write an integer sequenche of nchar numbers
// between 0 (inclusive) and nstates (exclusive)
void simulate(int ntax, int nchar, int nstates) {
	printf("xread\n");
	printf("%i %i\n", nchar, ntax);
	int i = 0;
	while ( i < ntax ) {
		i++;
		printf("Taxon%i ",i);
		int j = 0;
        	while ( j < nchar ) {
                	int state = rand() % nstates;
			printf("%i",state);
			j++;
        	}
		printf("\n");
		fprintf(stderr,"Taxon%i\n",i);
	}
	printf(";\n");
}
SIMULATOR

my ( $ntax, $nchar, $nstates );
GetOptions(
	'taxa=s'   => \$ntax,
	'char=s'   => \$nchar,
	'states=s' => \$nstates,
);

#print <<"HEADER";
#xread
#$nchar $ntax
#HEADER
simulate($ntax, $nchar, $nstates);
#print ";";
