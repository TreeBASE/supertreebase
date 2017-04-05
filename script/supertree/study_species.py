#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 16/01/2016

Script to convert pipeline output in MRP matrix format to table file,
showing species ID's for every study.

Pipeline MRP input:
    Tb_ID NCBI_ID charstring (0/1/2)

Table file output:
	study_ID species_count species_ID(,species_ID)

Usage:
    -i  Input file (Input file (*.dat file from pipeline, containing MRP matrix/matrices))
'''

import argparse
import itertools
import os
import sys
import logging

logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.DEBUG)


def get_species(filename):
	'''
	Input:
		Tb_ID NCBI_ID charstring
	Output:
		Set of species_ID's within the file (string, comma separated)
	'''
	dat_file = open(filename)
	species = str()
	for l in dat_file:
		l = l.strip().split()
		ncbi_id = l[1]
		if ncbi_id not in species:
			species += ncbi_id.strip("*") + ","
	dat_file.close()
	return(species)


def main():

	parser = argparse.ArgumentParser(description='Process commandline arguments')
	parser.add_argument("-i", type=str,
    	                help="Input file (*.dat file from pipeline, containing MRP matrix/matrices)")
	args = parser.parse_args()
	
	filename = args.i

	species = get_species(filename)
	if len(species) > 0:
		print(filename + "\t" + str(species.count(",")) + "\t" + species[:-1])
	else:
		print(filename + "\t" + "0" + "\t" + "1")


if __name__ == "__main__":
	main()