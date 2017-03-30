#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 08/03/2017

Making combined MRP files for class partitions, compiled from normalized MRP matrices.

Table input:
	- class_id tax_count unique_tax_count overlap_percentage species_id(,species_id)
	- rank_name species_count study_count study_ID(, study_ID)

Usage:
    -c  Text file, containing class_names linked to species_ID's
    -s  Text file, containing study_ID's linked to rank_ID
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
		class_id tax_count unique_tax_count overlap_percentage species_id(,species_id)
	Output:
		dict { class_name : [species_ID, species_ID] }
	'''
	outdict = dict()
	ranks_file = open(filename)
	for l in ranks_file:
		l = l.strip().split()
		outdict[l[0].replace('"', "").replace(" ", "_")] = l[-1].split(",")
	ranks_file.close()		
	return outdict

def get_study_filedict(filename):
	'''
	Input:
		File name, for table -
		rank_name species_count study_count study_ID(, study_ID)
	Output:
		dict { rank_name : [study_ID, study_ID] }
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


def main():

	parser = argparse.ArgumentParser(description='Process commandline arguments')
	parser.add_argument("-c", type=str,
    	                help="Text file, containing class rank names linked to species")
	parser.add_argument("-s", type=str,
    	                help="Text file, containing class rank names linked to species")
	parser.add_argument("-a", type=str,
    	                help="Analysis program where the data should be prepared for, SMD or TNT (S/T)")
	args = parser.parse_args()
	

	species_filedict = get_class_filedict(args.c)
	tb_filedict = get_study_filedict(args.s)

	analysistype = args.a

	datadir = "../../data/treebase/"

	filelist = glob.glob(datadir + "S*.dat")

	for c in species_filedict: 

		try:

			input_count = 0
			skip = 0

			outname = datadir + c + ".mrp"
			logging.info("processing " + c + " ...")
			rank_file = open(outname, "a")

			species = species_filedict[c]
			if len(species) > 2:

				classfilelist = tb_filedict[c]
				for f in filelist:

					study_id = f.split("/")[-1].split(".Tb")[0]
					if study_id in classfilelist:

						out = dict()
						species_count = 0
							
						for l in open(f):
							linelist = l.split()
							tb = linelist[0]

							if tb not in out:
								out[tb] = list()
							else:
								if len(linelist) > 2:
									if linelist[1] in species:
										species_count += 1
										out[tb].append(l)
							
						for tb in out:
							lines = out[tb]
							if len(lines) < 4:
								skip += 1
							input_count += 1

							comment = "#" + study_id + "." + tb
							#print(comment)
							rank_file.write(comment + "\n")

							for l in lines:
								tax_id = l.strip().split()[1]
								char_str = l.strip().split()[2]
								#print(tax_id + "\t" + char_str)
								rank_file.write(tax_id + "\t" + char_str  + "\n")

			else:
				logging.warning("not enough species in " + c)

			logging.info("wrote " + str(input_count) + " matrices to " + outname)
			logging.info(str(skip) + " less then 4 remaining species")

			rank_file.close()

		except KeyError:
			logging.warning(c + " not found")


if __name__ == "__main__":
	main()