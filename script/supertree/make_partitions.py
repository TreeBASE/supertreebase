#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 16/01/2016

Collects data as input for supertree analysis,
using *.sdm files 

(Super)kingdom table input:
	kingdom_ID species_count study_count study_ID(, study_ID)

Usage:
    -i  Text file containing study_ID's linked to kingdom_tax_ID list
'''

import argparse
import itertools
import os
import glob
import sys
import logging


def main():

	parser = argparse.ArgumentParser(description='Process commandline arguments')
	parser.add_argument("-i", type=str,
    	                help="Text file containing study_ID's linked to kingdom_tax_ID list")
	args = parser.parse_args()
	
	#outname_log = args.o + args.i
	#outname_log = outname_log.replace(".dat", ".log")
	#log_file = open(outname_log, "a")

	kingdoms_file = open(args.i)

	datadir = "../../data/treebase/"

	for l in kingdoms_file:
		l = l.strip()
		kingdom_name = l.split()[0]

		filecount = 0
		out = ""

		kingdom_file = open(datadir + "tb2dist_" + kingdom_name, "a")

		filelist = l.split()
		for f in filelist:
			f = f.replace(",", "").strip()
			studyfiles = (datadir + f + "*.sdm")
			datalist = glob.glob(studyfiles)
			for tb in datalist:
				tb_file = open(tb)
				out += (tb_file.read())
				tb_file.close()
			filecount += len(datalist)

		kingdom_file.write(str(filecount) + "\n")
		kingdom_file.write(out)

	kingdoms_file.close()

if __name__ == "__main__":
	main()