# this makefile contains the steps needed for html visualizations of supertrees

# runtime verbosity
VERBOSITY=-v -v -v
ARCH=zip

# relative locations. it is possible that these relative paths won't work when recursive
# make is invoked from a different working directory
SCRIPT=.
DATA=../../data

# contained folders. these are based on the relative locations defined above and probably
# don't need to be updated, ever
TB2DATA=$(DATA)/treebase
VISUALIZATIONDATA=../../visualization

# standard commands. unless these commands are installed in a non-standard location (this should be
# very rare) there is no need to change these
PERL=perl
PYTHON=python3
RM_RF=rm -rf

# file lists.
VALIDNEWICK=$(wildcard $(TB2DATA)/*.tre)
STUDYSCORE=$(patsubst %.tre,%.score,$(VALIDNEWICK))
NEWICKCSV=$(patsubst %.tre,%.csv,$(VALIDNEWICK))
CSVHTML=$(patsubst %.csv,%.html,$(NEWICKCSV))

MRPBIPARTITION=$(patsubst %.tre,%.mrpsplit,$(VALIDNEWICK))
TREEBIPARTITION=$(patsubst %.tre,%.treesplit,$(VALIDNEWICK))


.PHONY : 


### Make and compare bipartitions for supertrees and source trees ###

# create bipartition labels for every input matrix in the MRP collection
$(MRPBIPARTITION) : %.mrpsplit : %.mrp
	$(PYTHON) $(SCRIPT)/matrix_bipartition.py -i $< >> $@
mrp_bipartition : $(MRPBIPARTITION)
mrp_bipartition_clean : 
	$(RM_RF) $(MRPBIPARTITION)
 
# find study_id's matching partitions with the supertree partitions
$(TREEBIPARTITION) : %.treesplit : %.tre
	$(PYTHON) $(SCRIPT)/newick_bipartition.py -i $< >> $@
tree_bipartition : $(TREEBIPARTITION)
tree_bipartition_clean : 
	$(RM_RF) $(TREEBIPARTITION) 


### Visualization ###

# get study-score linkage for every class tree
#$(STUDYSCORE) : %.score : %.tre
#	$(PYTHON) $(SCRIPT)/newick_mrp_fit.py -i $< >> $@
#study_score : $(STUDYSCORE)
#study_score_clean : 
#	$(RM_RF) $(STUDYSCORE)
 
# get every class tree in csv representation, including internal nodes
$(NEWICKCSV) : %.csv : %.tre
	$(PYTHON) $(SCRIPT)/newick_csv.py -i $< >> $@
csvtrees : $(NEWICKCSV)
csvtrees_clean : 
	$(RM_RF) $(NEWICKCSV)
 
# insert every csv file into html
$(CSVHTML) : %.html : %.csv
	$(PYTHON) $(SCRIPT)/csv_html.py -i $< >> $@
htmltrees : $(CSVHTML)
htmltrees_clean : 
	$(RM_RF) $(CSVHTML) 