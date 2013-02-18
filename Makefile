# eukaryotes
ROOTID=2759
PERL=perl
EXTRACT=unzip -f
ARCH=zip
MKPATH=mkdir -p
RM_RF=rm -rf
SCRIPT=script
CURL=curl
CAT=cat
ECHO=echo
DATA=data
VERBOSITY=-v -v -v
MRPDIR=$(DATA)/mrp
MRPTABLE=$(MRPDIR)/combined.dat
TAXDMP=taxdmp
TAXDMPDIR=$(DATA)/$(TAXDMP)
TAXDMPTMP=$(TAXDMPDIR)/tmp
TAXDMPARCH=$(TAXDMPDIR)/$(TAXDMP).$(ARCH)
TAXDMPURL=ftp.ncbi.nlm.nih.gov/pub/taxonomy/$(TAXDMP).$(ARCH)
NCBIMRP=$(MRPDIR)/ncbi.dat
NCBINODES=$(TAXDMPDIR)/nodes.dmp
NCBINAMES=$(TAXDMPDIR)/names.dmp
NCBIFILES=$(NCBINODES) $(NCBINAMES)
TB2STUDYPURLS=$(wildcard $(TB2DATA)/*.url)
TB2STUDYFILES=$(patsubst %.url,%.xml,$(TB2STUDYPURLS))
TB2MRPFILES=$(patsubst %.xml,%.txt,$(TB2STUDYFILES))
TB2NRMLMRP=$(patsubst %.xml,%.dat,$(TB2STUDYFILES))
TNTCOMMANDS=$(patsubst %.dat,%.run,$(TB2NRMLMRP))
TB2DATA=$(DATA)/treebase
TB2SITEMAP=sitemap.xml
TB2SITEMAPXML=$(TB2DATA)/$(TB2SITEMAP)
TB2SITEMAPURL=http://treebase.org/treebase-web/$(TB2SITEMAP)
TB2TAXA=$(TB2DATA)/taxa.txt
TB2SPECIES=$(TB2DATA)/species.txt
TB2NCHAR=$(TB2DATA)/nchar.txt
TNTSCRIPT=$(TB2DATA)/tntscript.runall

.PHONY : all clean_tb2 tb2sitemap

all : tb2 $(NCBIMRP)

tb2 : tb2download $(TB2TAXA)

tb2download : tb2studypurls $(TB2STUDYFILES)

tb2mrp : $(TB2MRPFILES)

tb2taxa : $(TB2TAXA)

tb2species : $(TB2SPECIES)

normalized : $(TB2SPECIES) $(TB2NRMLMRP)

mrp : $(MRPTABLE)

tnt : $(TB2NRMLMRP) $(TNTSCRIPT)

clean_tb2 :
	$(RM_RF) $(TB2DATA)/*.url
	$(RM_RF) $(TB2DATA)/*.dat
	$(RM_RF) $(TB2DATA)/*.xml
	$(RM_RF) $(TB2DATA)/*.txt

# fetch the TreeBASE site map
tb2sitemap :
	$(MKPATH) $(TB2DATA)
	$(RM_RF) $(TB2SITEMAPXML)
	$(CURL) -o $(TB2SITEMAPXML) $(TB2SITEMAPURL)

$(TB2SITEMAPXML) : tb2sitemap

# turn the study URLs in the site map into local *.url files with PURLs
tb2studypurls : $(TB2SITEMAPXML)
	$(PERL) $(SCRIPT)/make_tb2_urls.pl -i $(TB2SITEMAPXML) -o $(TB2DATA)

# fetch the studies
$(TB2STUDYFILES) : %.xml : %.url
	$(CURL) -L -o $@ `cat $<`

# make TreeBASE MRP matrices
$(TB2MRPFILES) : %.txt : %.xml
	$(PERL) $(SCRIPT)/make_tb2_mrp.pl -i $< $(VERBOSITY) > $@

# create list of unique taxon IDs
$(TB2TAXA) : $(TB2MRPFILES)
	cat $(TB2MRPFILES) | cut -f 2 | sort | uniq > $@

# make species-level list from TreeBASE taxon IDs
$(TB2SPECIES) : $(TB2TAXA)
	$(PERL) $(SCRIPT)/make_species_list.pl -taxa $(TB2TAXA) -nodes $(NCBINODES) -names $(NCBINAMES) -dir $(TAXDMPTMP) $(VERBOSITY) > $@

# make MRP tables with normalized species and ambiguity codes for polyphyly
$(TB2NRMLMRP) : %.dat : %.txt
	$(PERL) $(SCRIPT)/normalize_tb2_mrp.pl -i $< -s $(TB2SPECIES) $(VERBOSITY) > $@

# download taxdmp archive
$(TAXDMPARCH) :
	$(MKPATH) $(TAXDMPDIR)
	$(CURL) -o $(TAXDMPARCH) $(TAXDMPURL)

# extract archive
$(NCBIFILES) : $(TAXDMPARCH)
	cd $(TAXDMPDIR) && $(EXTRACT) $(TAXDMP).$(ARCH) && cd -	

# make NCBI MRP matrix
#$(NCBIMRP) : $(NCBIFILES) $(TB2SPECIES)
#	$(MKPATH) $(MRPDIR) $(TAXDMPTMP)
#	$(PERL) $(SCRIPT)/make_ncbi_mrp.pl -species $(TB2SPECIES) -nodes $(NCBINODES) -names $(NCBINAMES) -dir $(TAXDMPTMP) $(VERBOSITY) > $@

# concatenate NCBI and TreeBASE MRP matrices
$(MRPTABLE) : $(TB2MRPFILES) $(TB2SPECIES)
	$(PERL) $(SCRIPT)/concat_mrp.pl -d $(TB2DATA) -s $(TB2SPECIES) -p 'S[0-9]+\.dat' $(VERBOSITY) > $@

# make tnt file inclusion commands and single file with nchar for each treeblock
$(TNTCOMMANDS) : %.run : %.dat
	$(PERL) $(SCRIPT)/make_tnt.pl -i $< > $@ 2>> $(TB2NCHAR)

# make the master tnt script
$(TNTSCRIPT) : $(TNTCOMMANDS)
	$(PERL) $(SCRIPT)/make_tnt_script.pl -n $(TB2NCHAR) -s $(TB2SPECIES) > $@
	$(CAT) $(TNTCOMMANDS) >> $@
	$(ECHO) 'proc/;' >> $@
