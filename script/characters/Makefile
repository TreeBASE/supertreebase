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
PYTHON=python3
RM_RF=rm -rf
CAT=cat

# file locations. these are based on contained folders defined above and probably
# don't need updating, ever
METATABLE=$(CHARMETA)/metadata.tsv
METACOMBINE=$(CHARMETA)/metacombine.txt
ALLMETA=$(CHARMETA)/metatable.txt
METASUMMARY=$(CHARMETA)/metasummary.txt

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

# combine metadata
$(METACOMBINE) : $(TB2STUDYMETA)
	for f in $(TB2STUDYMETA) ; do \
		$(PYTHON) $(SCRIPT)/combine_meta.py -i $$f >> $@ ; \
   done
metacombine : $(METACOMBINE)
metacombine_clean :
	$(RM_RF) $(METACOMBINE) 

# add metadata to one file
$(ALLMETA) : $(TB2STUDYMETA)
	$(CAT) $(TB2STUDYMETA) >> $@
allmeta : $(ALLMETA)
allmeta_clean :
	$(RM_RF) $(ALLMETA)

# get some percentages from the metadata
$(METASUMMARY) : $(ALLMETA)
	$(PYTHON) $(SCRIPT)/summarize_meta.py -i $< > $@
metasummary : $(METASUMMARY)
metasummary_clean :
	$(RM_RF) $(METASUMMARY)
