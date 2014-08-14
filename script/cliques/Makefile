# this makefile contains the steps needed for building a dot network from which study
# clique (or other network properties) can be computed, e.g. using GraphViz or Gephi

# runtime verbosity
VERBOSITY=-v -v -v

# standard commands. unless these commands are installed in a non-standard location (this should be
# very rare) there is no need to change these
PERL=perl
RM_RF=rm -rf

# relative locations. it is possible that these relative paths won't work when recursive
# make is invoked from a different working directory
SCRIPT=.
DATA=../../data
METADATA=../../metadata

# contained folders. these are based on the relative locations defined above and probably
# don't need to be updated, ever
TB2DATA=$(DATA)/treebase
CLIQUEMETA=$(METADATA)/cliques

# standard commands. unless these commands are installed in a non-standard location (this should be
# very rare) there is no need to change these
PERL=perl

# file locations. these are based on contained folders defined above and probably
# don't need updating, ever
CLIQUEDOT=$(CLIQUEMETA)/cliques.dot
CLIQUECSV=$(CLIQUEMETA)/cliques.csv
CLIQUEGPH=$(CLIQUEMETA)/cliques.gephi

.PHONY : 

# make the cliques.dot file
$(CLIQUEDOT) :
	cd ../supertree && $(MAKE) tb2mrp_species && cd -
	$(PERL) $(SCRIPT)/cliquebuilder.pl $(VERBOSITY) -dir $(TB2DATA) > $@
cliques : $(CLIQUEDOT)
cliques_clean : 
	$(RM_RF) $(CLIQUEDOT) $(CLIQUECSV) $(CLIQUEGPH)
