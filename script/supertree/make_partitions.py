#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 16/01/2016

Collects data as input for supertree analysis,
using *.sdm files or *.tnt

(Super)kingdom table input:
	kingdom_name species_count study_count study_ID(, study_ID)

Usage:
    -i  Text file containing study_ID's linked to kingdom_tax_ID list
    -a  (S/D), if data should be prepared for SDM or TNT analysis 
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
	parser.add_argument("-a", type=str,
    	                help="Analysis program where the data should be prepared for, SMD or TNT (S/T)")
	args = parser.parse_args()
	
	#outname_log = args.o + args.i
	#outname_log = outname_log.replace(".dat", ".log")
	#log_file = open(outname_log, "a")

	kingdoms_file = open(args.i)

	analysistype = args.a

	datadir = "../../data/treebase/"

	for l in kingdoms_file:
		l = l.strip()
		kingdom_name = l.split()[0]

		filecount = 0
		out = ""

		#SDM partition
		if analysistype == "S":

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

		#TNT partition
		if analysistype == "T":

			kingdom_file = open(datadir + "tntscript.run" + kingdom_name, "a")

			filelist = l.split()
			for f in filelist:
				f = f.replace(",", "").strip()
				studyfiles = (datadir + f + "*.tnt")
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