How to run the TNT pipeline, the nasty bits
===========================================

[This Makefile](https://github.com/TreeBASE/supertreebase/blob/master/script/supertree/Makefile) contains the steps 
for downloading TreeBASE data and preparing it for input into TNT. Here are the steps, identified as make targets. 
If you want to work your way through these steps one by one, you would issue them in the order given. If you want
to live dangerously you would simply get rid of the stale sitemap.xml if needed, and issue the last target 
(`make -j 4 tntscript`). A number of steps can be parallelized by make, by providing the `-j $num` command to
specify the number of cores to run on. To revert any of these steps, issue the target as `make <target>_clean` 
(example: `make sitemap_clean` deletes the sitemap.xml):

- `sitemap` - downloads the [sitemap.xml](http://treebase.org/treebase-web/sitemap.xml) from the TreeBASE website,
which lists all the studies currently published. The URLs are not pretty PURLs but URLs that directly compose the
query strings for the web application.
- `purls` - parses the sitemap.xml and extracts each URL, turning it into a PURL that leads to the NeXML data
associated with the study. This means that inside `data/treebase` very many *.url files will be created: one for
each study. If a *.url file already exists it will be left alone, allowing for incremental downloads.
- `studies` - for every *.url file, downloads the NeXML file it points to. Again, this can be done incrementally
as make checks for the existence of target files (and their timestamps: if any *.url file is newer than a NeXML
file, a download is initiated). _Some downloads fail (for a variety of reasons, e.g. the output is too much for
the web app to generate without time outs). To get past this step you can create empty *.xml files, e.g. for 
study $foo, do `touch data/treebase/$foo.xml`_
- `tb2mrp_taxa` - for each *.xml file, creates a *.txt file with multiple MRP matrices: one for each tree block in
the study. The *.txt file is tab separated, structured thusly: $treeBlockID, "\t", $ncbiTaxonID, "\t", $mrpString, "\n".
Note that at this point, $ncbiTaxonID can be anything: a (sub)species, genus, family, whatever.
- `taxa` - creates a file `taxa.txt` with two data columns: "\s+", $occurrenceCount, "\s+", $ncbiTaxonID, "\n"
- `species` - creates a file `species.txt` that maps the $ncbiTaxonID's to species IDs. The logic is as follows: if 
$ncbiTaxonID is below species level (e.g. subspecies), collapse up to species level. If $ncbiTaxonID is above species
level, expand it to include all the species that are seen to be subtended by that taxon in any TreeBASE study. So we
don't simply include all species in the NCBI taxonomy, just the ones TreeBASE knows about.
- `tb2mrp_species` - for each study MRP file (*.txt) maps the $ncbiTaxonID to the species ID. Results in a *.dat
file for every MRP *.txt file. _Note: the list of *.xml/*.txt/*.dat files is constructed by make from the list
of *.url files generated out of the sitemap. Other files with, say, *.txt extension are ignored._
