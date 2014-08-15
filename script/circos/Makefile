# this makefile contains the steps needed for making the circos image

# runtime verbosity
VERBOSITY=-v -v -v

# relative locations. it is possible that these relative paths won't work when recursive
# make is invoked from a different working directory
SCRIPT=.
DATA=../../data
METADATA=../../metadata

# dependency program: circos, see http://www.circos.ca
CIRCOS=circos

# contained folders. these are based on the relative locations defined above and probably
# don't need to be updated, ever
TAXDMP=taxdmp
TAXDMPDIR=$(DATA)/$(TAXDMP)
TAXDMPTMP=$(TAXDMPDIR)/tmp
TB2DATA=$(DATA)/treebase
CIRCOSMETA=$(METADATA)/circos

# standard commands. unless these commands are installed in a non-standard location (this should be
# very rare) there is no need to change these
PERL=perl
RM_RF=rm -rf

# file locations. these are based on contained folders defined above and probably
# don't need updating, ever
CIRCOSBANDS=$(CIRCOSMETA)/bands.txt
CIRCOSREPRS=$(CIRCOSMETA)/representation.txt
CIRCOSSCATR=$(CIRCOSMETA)/scatter.txt
CIRCOSLINKS=$(CIRCOSMETA)/links.txt
CIRCOSCLASS=$(CIRCOSMETA)/class.txt
CIRCOSCONF=$(CIRCOSMETA)/circos.conf
CIRCOSSVG=$(CIRCOSMETA)/circos.svg
NCBINODES=$(TAXDMPDIR)/nodes.dmp
NCBINAMES=$(TAXDMPDIR)/names.dmp
TB2TAXA=$(TB2DATA)/taxa.txt

# file lists.
TB2STUDYPURLS=$(wildcard $(TB2DATA)/*.url)
TB2STUDYFILES=$(patsubst %.url,%.xml,$(TB2STUDYPURLS))
TB2CLASSES=$(patsubst %.xml,%.class,$(TB2STUDYFILES))

.PHONY : 

# extract the NCBI classes
$(TB2CLASSES) : %.class : %.xml
	$(PERL) $(SCRIPT)/getclass.pl -nodes $(NCBINODES) -names $(NCBINAMES) -taxa $(TAXDMPTMP) -i $< $(VERBOSITY) > $@
classes : $(TB2CLASSES)
classes_clean :
	$(RM_RF) $(TB2CLASSES)

# compute representation of taxa
$(CIRCOSREPRS) : $(TB2TAXA)
	$(PERL) $(SCRIPT)/representation.pl -i $(TB2TAXA) -names $(NCBINAMES) -nodes $(NCBINODES) -d $(TAXDMPTMP) $(VERBOSITY) > $@
representation : $(CIRCOSREPRS)
representation_clean :
	$(RM_RF) $(CIRCOSREPRS)

# build circos tracks
$(CIRCOSBANDS) : $(CIRCOSREPRS)
	$(PERL) $(SCRIPT)/make_classification.pl -w $(CIRCOSMETA) -b $@ -s $(CIRCOSSCATR) -table $< -taxa $(TAXDMPTMP) -names $(NCBINAMES) -nodes $(NCBINODES) $(VERBOSITY)
tracks : $(CIRCOSBANDS)
tracks_clean :
	$(RM_RF) $(CIRCOSBANDS)

# build links
$(CIRCOSLINKS) : $(CIRCOSBANDS)
	$(PERL) $(SCRIPT)/make_links.pl -w $(TB2DATA) -c $(CIRCOSCLASS) -r $(CIRCOSREPRS) $(VERBOSITY) > $@
links : $(CIRCOSLINKS)
links_clean :
	$(RM_RF) $(CIRCOSLINKS)

# run circos
$(CIRCOSSVG) : $(CIRCOSLINKS)
	cd $(CIRCOSMETA) && $(CIRCOS) -conf $(CIRCOSCONF)
circos : $(CIRCOSSVG)
circos_clean :
	$(RM_RF) $(CIRCOSSVG)
