# this Makefile contains the steps needed to extract interesting metadata about
# character data from TreeBASE files

# runtime verbosity
VERBOSITY=-v -v -v

# relative locations. it is possible that these relative paths won't work when recursive
# make is invoked from a different working directory
SCRIPT=.
DATA=../../data
METADATA=../../metadata

# contained folders. these are based on the relative locations defined above and probably
# don't need to be updated, ever
TB2DATA=$(DATA)/treebase
CHARMETA=$(METADATA)/characters

# standard commands. unless these commands are installed in a non-standard location (this should be
# very rare) there is no need to change these
PERL=perl
RM_RF=rm -rf

# file locations. these are based on contained folders defined above and probably
# don't need updating, ever
METATABLE=$(CHARMETA)/metadata.tsv

# file lists.
TB2STUDYFILES=$(wildcard $(TB2DATA)/*.xml)
TB2STUDYMETA=$(patsubst %.xml,%.meta,$(TB2STUDYFILES))

.PHONY : 

# extract metadata
$(TB2STUDYMETA) : %.meta : %.xml
	$(PERL) $(SCRIPT)/extract_meta.pl -i $< > $@
meta : $(TB2STUDYMETA)
meta_clean :
	$(RM_RF) $(TB2STUDYMETA)

