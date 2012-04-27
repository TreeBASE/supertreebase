# eukaryotes
ROOTID=2759
PERL=perl
EXTRACT=unzip -f
ARCH=zip
MKPATH=mkdir -p
SCRIPT=script
CURL=curl
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
TB2DATA=$(DATA)/treebase
TB2SITEMAP=sitemap.xml
TB2SITEMAPXML=$(TB2DATA)/$(TB2SITEMAP)
TB2SITEMAPURL=http://treebase.org/treebase-web/$(TB2SITEMAP)
TB2TAXA=$(TB2DATA)/taxa.txt

.PHONY : all tb2 clean_tb2

all : tb2 $(NCBIMRP)

tb2 : tb2studypurls $(TB2STUDYFILES) $(TB2TAXA)

tb2mrp : $(TB2MRPFILES)

tb2taxa : $(TB2TAXA)

ncbimrp : $(NCBIMRP)

clean_tb2 :
	rm -rf $(TB2DATA)/*.url
	rm -rf $(TB2DATA)/*.dat
	rm -rf $(TB2DATA)/*.xml
	rm -rf $(TB2DATA)/*.txt

# fetch the TreeBASE site map
$(TB2SITEMAPXML) :
	$(MKPATH) $(TB2DATA)
	$(CURL) -o $@ $(TB2SITEMAPURL)

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

# download taxdmp archive
$(TAXDMPARCH) :
	$(MKPATH) $(TAXDMPDIR)
	$(CURL) -o $(TAXDMPARCH) $(TAXDMPURL)

# extract archive
$(NCBIFILES) : $(TAXDMPARCH)
	cd $(TAXDMPDIR) && $(EXTRACT) $(TAXDMP).$(ARCH) && cd -	

# make NCBI MRP matrix
$(NCBIMRP) : $(NCBIFILES) $(TB2TAXA)
	$(MKPATH) $(MRPDIR) $(TAXDMPTMP)
	$(PERL) $(SCRIPT)/make_ncbi_mrp.pl -taxa $(TB2TAXA) -nodes $(NCBINODES) -names $(NCBINAMES) -dir $(TAXDMPTMP) $(VERBOSITY) > $@

# concatenate NCBI and TreeBASE MRP matrices
$(MRPTABLE) : $(TB2MRPFILES) $(NCBIMRP)
	$(PERL) $(SCRIPT)/concat_mrp.pl -d $(TB2DATA) -n $(NCBIMRP) $(VERBOSITY) > $@