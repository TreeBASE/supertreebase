#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 09/05/2017

combines Class information into one table
'''

import argparse
import itertools
import os
import glob
import sys
import logging
import re

logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.INFO)


def main():

	#parser = argparse.ArgumentParser(description='Process commandline arguments')
	#parser.add_argument("-s", type=str,
    #	                help="Newick file")
	#parser.add_argument("-n", type=str,
    #	                help="NCBI names file")
	#args = parser.parse_args()	


	species_studies = "classes.txt"
	scores = "class_scores.txt"
	nchar = "class_nchar.txt"

	combo_dict = dict()
	nspecies_nstudies_dict = dict()
	nchar_dict = dict()

	
	for l in open(scores):
		classname = l.split()[0]
		if classname != "Class":
			scoredata = str()
			scores = l.split()[1:]
			for s in scores:
				scoredata += (s + "\t")
			combo_dict[classname] = scoredata[:-1]

	#ntax = 0
	for l in open(species_studies):
		classname = l.split()[0]
		if len(l.split()) > 1:
			nspecies_nstudies_dict[classname] = l.split()[1] + "\t" + l.split()[2]
			#if int(l.split()[1]) > 3:
				#ntax+=1
			#print(int(l.split()[2]))
	#print(ntax)


	for l in open(nchar):
		classname = l.split()[0]
		nchar_dict[classname] = l.split()[1]
			
		
	for c in combo_dict:
		combo_dict[c] += ("\t" + nspecies_nstudies_dict[c] + "\t" + nchar_dict[c])


	outtable = open("classdata.txt", "w")
	outtable.write("minimum_length	length	consistency_index	retention_index rescaled_consistency_index	goloboff_fit	species	studies	characters\n")
	for k in combo_dict:
		data = combo_dict[k]
		outtable.write(k + "\t" + data + "\n")

	#speciesvalid = 0
	#studiesvalid = 0
	#speciesfail = 0
	#for l in open("class_species.txt"):
	#	classname = l.split()[0]
	#	if l.split()[2] == 0:
	#		print(l)
		#print(classname)

			#nspecies_nstudies_dict[classname] = l.split()[1] + "\t" + l.split()[2]


	#file.close()	


if __name__ == "__main__":
	main()