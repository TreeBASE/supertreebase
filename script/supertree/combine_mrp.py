#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 23/03/2017

Making "supermatrix" nexus files for class partitions, compiled from previously filtered MRP matrices.

Table input:
	#comment
	species_ID character_string

Nexus output:
	#NEXUS
	begin data;
	    dimensions ntax=2 nchar=16;
	    format datatype=standard symbols="01" missing=?;
      taxlabels species_ID species_ID;
	matrix
	species_ID character_string
	species_ID character_string
	;
	end;

Usage:
    -i  Text file, containing MRP matrices for partition, devided by comment with source
'''

import argparse
import itertools
import os
import glob
import sys
import logging

logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.INFO)


def get_mrp_filedict(filename):
	'''
	Input:
		File name, for table -
		#comment
		species_ID character_string
	Output:
		dict { species_ID : [ [tb_ID, char_str], [tb_ID, char_str] ] }
	'''
	outdict = dict()
	mrp_file = open(filename)

	for l in mrp_file:
		if l.strip().startswith("#"):
			tb_id = l.strip()
		else:
			species_id = l.strip().split()[0]
			char_str = l.strip().split()[1]
			if species_id not in outdict:
				outdict[species_id] = list()
			outdict[species_id].append( [tb_id, char_str] )

	mrp_file.close()		
	return outdict


def main():

	datadir = "../../data/treebase/"

	parser = argparse.ArgumentParser(description='Process commandline arguments')
	parser.add_argument("-i", type=str,
    	                help="Text file, containing MRP matrices for partition, devided by comment with source")
	#parser.add_argument("-o", type=str,
  #  	                help="Text file, containing a string of study-names, for labeling the source of each character") 
	args = parser.parse_args()
	

	mrp_filedict = get_mrp_filedict(args.i)		# { species_ID : [ [tb_ID, char_str], [tb_ID, char_str] ] }
	tb_dict = dict()	# { tb_ID : char_count }

	ntax = len(mrp_filedict)
	nchar = 0
	charlabels = dict()
	
	# only make matrices suitable for PAUP* to work with
	if ntax > 3:

		found_combos = list()
		
		for tax in mrp_filedict:
			mrp_list = mrp_filedict[tax]
			out = ""
			for i in mrp_list:
				mrp = i[1]
				tb = i[0]
				# collect nchar for every treeblock-source
				tb_dict[tb] = len(mrp)
				# collect combinations of taxon ID's and treeblock-source ID's
				found_combos.append( (tax, tb) )
		
		# evaluate every species-treeblock combination
		# filling in missing combinations with the right ammount of questionmark characters
		for combo in itertools.product(mrp_filedict.keys(), tb_dict.keys() ):
			if combo not in found_combos:
				missing_tax = combo[0]
				missing_tb = combo[1]
				missing_chars = "?"*tb_dict[missing_tb]
				mrp_filedict[missing_tax].append([missing_tb, missing_chars])

		outlist = list()
		charlabels_check = list()		
		labelfile = open(datadir + args.i.split("/")[-1].split(".")[0] + "_charlabels.txt", "a")

		# collect output lines, number of chars and char labels 
		for tax in mrp_filedict:
			mrp_list = mrp_filedict[tax]
			out = ""
			for i in sorted(mrp_list):
				out += i[1]
				if i[0] not in charlabels_check:
					charlabels_check.append(i[0])
					labels = i[0] + "\t" + str(len(i[1]))  
					# write character-study label file                                            
					print(labels, file=labelfile)
			outlist.append(tax + " " + out)
			nchar = len(out)

		labelfile.close()   
           
		# write Nexus output

		ntax = ntax+1      
		print("#NEXUS\nbegin data;")
		print('    dimensions ntax={} nchar={};'.format(ntax, nchar) )
		print('    format datatype=standard symbols="012" missing=?;')
		print("matrix")  

		print("Root\t" + (nchar*"0") ) # this will be the outgroup 
         
		for l in outlist:
				print(l)     

		print(";")
		print("end;")   
     
		#print("begin paup;")
		#print("exe " + args.s + ";")
		#print("end;")


if __name__ == "__main__":
	main()