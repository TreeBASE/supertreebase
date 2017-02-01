#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 23/11/2016

Script to convert pipeline output in MRP matrix format to distance matrix format.
Produces distance matrix file for every tree block in input,
and also a log file for every input file.
Run by using "make sdmdata" command.

Pipeline MRP input:
    Tb_ID NCBI_ID charstring (0/1/2)

Distance matrix output:
	File for every treeblock:
	taxon_count char_count
	taxa1 distance distance
	taxa2 distance distance

Usage:
    -i  Input file (Input file (*.dat file from pipeline, containing MRP matrix/matrices))
    -o 	Output directory (for *.sdm files with distance matrices and *.log file)
'''

import argparse
import itertools
import os
import sys
import logging

logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.DEBUG)

def proc_log(logmessage, logtype, log_file):
	if logtype == "inf":
		logging.info(logmessage)
		log_file.write("INFO: " + logmessage + "\n")
	if logtype == "war":
		logging.warning(logmessage)
		log_file.write("WARNING: " + logmessage + "\n")


def get_tb_tree_dict(treeblock_file):
	'''
	Input:
		Tb_ID NCBI_ID charstring
	Output:
		dict: key = Tb_ID, value = (dict: key = NCBI_ID, value = charstring)
	'''

	try:
		treeblock_data = dict()

		for l in treeblock_file:
			l = l.strip().split()
			tb_id = l[0]
			ncbi_id = l[1]
			charstr = l[2]
			if tb_id not in treeblock_data:
				treeblock_data[tb_id] = dict()
			else:
				treeblock_data[tb_id][ncbi_id] = charstr
			treeblock_data[tb_id][ncbi_id] = charstr
		treeblock_file.close()
		return(treeblock_data)
	except IndexError:
		return None

def get_dist_dict(tb_tax_chars):
	'''
	Input:
		dict: key = Tb_ID, value = (dict: key = NCBI_ID, value = charstring),
	Output:
		dict: key = tuple(taxa_combo), value = Hamming_dist / taxon_count / character_count
	'''

	try:
		distdict = dict()
		taxa = sorted(tb_tax_chars.keys())
		tax_count = len(taxa)
		for combotuple in itertools.product(taxa, repeat=2):
			tax1 = combotuple[0]
			tax2 = combotuple[1]
			charst1 = tb_tax_chars[tax1]
			charst2 = tb_tax_chars[tax2]
			char_count = len(charst1)
			# count indices for positions with diference in characters
			dist = len([i for i in range(char_count) if charst1[i] != charst2[i]])
			distdict[combotuple] = dist / tax_count / char_count
		return(distdict)
	except MemoryError:
		return None

def write_dist_matrix(distdict, char_count, taxa, distance_file):
	'''
	Input:
		dict: key = taxa_combo_tuple, value = (charstring_1_count_taxon_1 - charstring_1_count_taxon_2),
		char_count,
		(sorted_)taxa_list
	Output:
		File for every tree block:
		taxon_count char_count
		distance_matrix ((charstring_1_count_taxon_1 - charstring_1_count_taxon_2) / taxon_count / char_count)
	'''

	tax_count = len(taxa)
	combo_count = tax_count*tax_count
	sorted_distdict = sorted(distdict)
	
	print("\n# {}".format(os.path.basename(distance_file.name)), file=distance_file)
	print("\n{} {}".format(tax_count, char_count), file=distance_file)
	for t in taxa:
		# start matrix row with taxon NCBI_ID
		row = [t]
		row_count = 0
		for taxtuple in sorted_distdict:
		# get the right combination of taxa in the right order
			if t == taxtuple[0]:
				dist = round(distdict[taxtuple], 8)
				dist = "{:.8f}".format(dist)
				row.append(dist)
			else:
				row_count += 1
				if row_count == combo_count:
					break
		print(*row, file=distance_file)


def main():

	parser = argparse.ArgumentParser(description='Process commandline arguments')
	parser.add_argument("-i", type=str,
    	                help="Input file (*.dat file from pipeline, containing MRP matrix/matrices)")
	parser.add_argument("-o", type=str,
    	                help="Output directory (for *.sdm files with distance matrices and *.log file)")
	args = parser.parse_args()
	
	outname_log = args.o + args.i
	outname_log = outname_log.replace(".dat", ".log")
	log_file = open(outname_log, "a")
	treeblock_file = open(args.i)

	proc_log("going to read MRP data from " + args.i, "inf", log_file)

	treeblock_data = get_tb_tree_dict(treeblock_file)
	if treeblock_data:		
		for tb in treeblock_data:
			WORKdict = treeblock_data[tb]
			taxa = sorted(WORKdict.keys())
			
			if len(taxa) > 1:
				WORKdict = get_dist_dict(WORKdict)
				if WORKdict:
					outname_tb = args.o + args.i + "." + tb + ".sdm"
					distance_file = open(outname_tb, "w")

					proc_log("going to write SDM data to " + outname_tb, "inf", log_file)

					char_count = len(treeblock_data[tb][taxa[0]])
					write_dist_matrix(WORKdict, char_count, taxa, distance_file)
					
					distance_file.close()
					proc_log("done writing " + outname_tb, "inf", log_file)
				else:
					proc_log("could not calculate distances", "war", log_file)
			else:
				proc_log("not enough taxa to work with", "war", log_file)
	else:
		proc_log("invalid MRP format", "war", log_file)			
			
	proc_log("done reading " + args.i, "inf", log_file)
	log_file.close()

if __name__ == "__main__":
	main()