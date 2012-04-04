# eukaryotes
ROOTID=2759
PERL=perl
EXTRACT=unzip -f
ARCH=zip
MKPATH=mkdir -p
SCRIPT=script
DOWNLOADCMD=curl -O
DATA=data
VERBOSITY=-v -v -v -v
MRPDIR=$(DATA)/mrp
TAXDMP=taxdmp
TAXDMPDIR=$(DATA)/$(TAXDMP)
TAXDMPTMP=$(TAXDMPDIR)/tmp
TAXDMPARCH=$(TAXDMPDIR)/$(TAXDMP).$(ARCH)
TAXDMPURL=ftp.ncbi.nlm.nih.gov/pub/taxonomy/$(TAXDMP).$(ARCH)
NCBIMRP=$(MRPDIR)/ncbi.dat
NCBINODES=$(TAXDMPDIR)/nodes.dmp
NCBINAMES=$(TAXDMPDIR)/names.dmp
NCBIFILES=$(NCBINODES) $(NCBINAMES)

.PHONY : extract_taxdmp

$(TAXDMPARCH) :
	$(MKPATH) $(TAXDMPDIR)
	cd $(TAXDMPDIR) && $(DOWNLOADCMD) $(TAXDMPURL) && cd -

extract_taxdmp : $(TAXDMPARCH)
	cd $(TAXDMPDIR) && $(EXTRACT) $(TAXDMP).$(ARCH) && cd -	

$(NCBIFILES) : extract_taxdmp

ncbimrp : $(NCBIFILES)
	$(MKPATH) $(MRPDIR) $(TAXDMPTMP)
	$(PERL) $(SCRIPT)/make_ncbi_mrp.pl -rootid $(ROOTID) -nodes $(NCBINODES) -names $(NCBINAMES) -dir $(TAXDMPTMP) $(VERBOSITY) > $(NCBIMRP)