#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 08/03/2017

Making combined MRP files for class partitions, compiled from normalized MRP matrices.

Table input:
	- class_name tax_count unique_tax_count overlap_percentage species_id(,species_id)
	- class_name species_count study_count study_ID(, study_ID)

Usage:
    -c  Text file, containing class_names linked to species_ID's
    -s  Text file, containing class_names linked to study_ID's
    -n 	NCBI names file
'''

import argparse
import itertools
import os
import glob
import sys
import logging

logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.INFO)


def get_class_filedict(filename):
	'''
	Input:
		File name, for table -
		class_name tax_count unique_tax_count overlap_percentage species_id(,species_id)
	Output:
		dict { class_name : [species_ID, species_ID] }
	'''
	outdict = dict()
	ranks_file = open(filename)
	for l in ranks_file:
		class_name = l.split('"')[1].replace(" ", "_") 
		l = l.strip().split()
		outdict[class_name] = l[-1].split(",")
	ranks_file.close()		
	return outdict

def get_study_filedict(filename):
	'''
	Input:
		File name, for table -
		class_name species_count study_count study_ID(, study_ID)
	Output:
		dict { class_name : [study_ID, study_ID] }
	'''
	outdict = dict()
	ranks_file = open(filename)
	for l in ranks_file:
		l = l.strip()
		if len(l.split()) > 2:
			rank_name = l.split()[0]
			if rank_name not in outdict:
				outdict[rank_name] = list()
				filelist = l.split()
				for f in filelist[3:]:
					f = f.replace(",", "").strip()
					outdict[rank_name].append(f)
	ranks_file.close()		
	return outdict

def get_names_dict(namedmp):
	'''
	Input:
		NCBI names.dmp
	Output:
		dict {node_id : tax_name}
	'''
	names_file = open(namedmp)
	names = dict()
	for i in names_file:
		line = i.split("|")
		if "scientific name" in i:
			node_id = line[0].strip()
			tax_name = line[1].strip()
			names[node_id] = tax_name
	names_file.close()
	return names


def main():

	parser = argparse.ArgumentParser(description='Process commandline arguments')
	parser.add_argument("-c", type=str,
    	                help="Text file, containing class rank names linked to species")
	parser.add_argument("-s", type=str,
    	                help="Text file, containing class rank names linked to studies")
	parser.add_argument("-n", type=str,
    	                help="NCBI names file")
	args = parser.parse_args()
	

	species_filedict = get_class_filedict(args.c)
	tb_filedict = get_study_filedict(args.s)

	names_dict = get_names_dict(args.n)

	datadir = "../../data/treebase/"

	# collect every data file to be evaluated
	filelist = glob.glob(datadir + "S*.dat")

	# evaluate every class
	for c in species_filedict: 

		try:

			input_count = 0
			skip = 0
			
			# create output file for every class
      
			outname = datadir + c + ".mrp"
			logging.info("processing " + c + " ...")
			rank_file = open(outname, "a")

			species = species_filedict[c]
			# evaluate the species within the class when there are more then 2
			if len(species) > 2:

				classfilelist = tb_filedict[c]
      			# process every treeblock-source file in which the current class is represented
				for f in filelist:
        
					# collecting the input lines from the right species within the class

					study_id = f.split("/")[-1].split(".Tb")[0]
					if study_id in classfilelist:

						out = dict()
							
						for l in open(f):
							linelist = l.split()
							tb = linelist[0]
							# collect the lines from every input file
							if tb not in out:
								out[tb] = list()
							else:
								if len(linelist) > 2:
									if linelist[1] in species:
										out[tb].append(l)
							
						for tb in out:
							lines = out[tb]
							if len(lines) < 4:
								skip += 1
							input_count += 1
                              
							# writing output

							comment = "#" + study_id + "." + tb
							rank_file.write(comment + "\n")

							for l in lines:
								tax_id = l.strip().split()[1]
								char_str = l.strip().split()[2]

								# translate tax_id and check if it is valid
								tax_name = names_dict[tax_id].replace(" ", "_")
								if (tax_name.count("_") == 1) and ("sp." not in tax_name):
									rank_file.write(tax_name.replace("-", "_").replace("'", "") + "\t" + char_str  + "\n")
								else:
									logging.warning("invalid taxon " + tax_name + " found, not writing")

			else:
				logging.warning("not enough species in " + c)

			logging.info("wrote " + str(input_count) + " matrices to " + outname)
			logging.info(str(skip) + " less then 4 remaining species")

			rank_file.close()

		except KeyError:
			logging.warning(c + " not found")


if __name__ == "__main__":
	main()