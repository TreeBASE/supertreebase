SuperTreeBASE - data dump and code to summarize TreeBASE
========================================================
This repository contains a nearly complete dump of the
contents of [TreeBASE](http://treebase.org), the database
of phylogenetic knowledge. In addition there are various
scripts and (make-based) pipelines to summarize the dump
in various ways, including:
* topologically, by integrating the tree topologies in the
  database into MRP matrices that can be analyzed
* taxonomically, by summarizing coverage of classes and
  by visualizing taxonomic overlap between studies
* chronologically, by summarizing the growth in character
  data of various types over time

Licensing
---------
All data made available here are reproduced from TreeBASE
and the NCBI taxonomy. As such, the terms of the original
rights holders apply (which are very lenient: if you want
to do science with what's here, feel free to do so). The
source code is open source and made available under an
MIT license.

Structure
---------
* TreeBASE data are in data/treebase, in NeXML format
* taxonomy data are in data/taxdmp, in NCBI dmp format
* metadata/* contains summaries computed from the data
* script/* contains source code organized in pipelines

Pipelines
---------
All pipelines in the subfolders of script/ are executed
by running `make` targets defined in the Makefiles. The
targets invoke Perl scripts in the same folder. To find
out which targets to run and which dependencies to 
resolve you will have to study the source code.
* `characters` - computes usage of different types of
  character data over time
* `circos` - creates data tracks and links for input 
  into [Circos](http://circos.ca)
* `cliques` - creates a [GraphViz](http://graphviz.org)
  network of taxonomic links between studies
* `supertree` - creates MRP matrices for analysis with
  [TNT](http://tnt.insectmuseum.org)
* `test` - contains throwaway scripts that can be
  ignored




