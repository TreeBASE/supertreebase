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
    -n  Tree-block ID's linked to number of characters 
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
	parser.add_argument("-n", type=str,
    	                help="Table containing Tb_ID's linked to number of character found in tree")
	args = parser.parse_args()
	
	#outname_log = args.o + args.i
	#outname_log = outname_log.replace(".dat", ".log")
	#log_file = open(outname_log, "a")

	kingdoms_file = open(args.i)
	
	nchar_file = open(args.n)
	nchar_dict = dict()

	print("reading nchar.txt ...")
	for l in nchar_file:
		l = l.strip()
		if l.count("Tb") == 1 and len(l.split()) == 2:
			tb_id = l.split()[0]
			nchar = l.split()[1]
			nchar_dict[tb_id] = nchar

	analysistype = args.a

	datadir = "../../data/treebase/"

	for l in kingdoms_file:
		l = l.strip()
		kingdom_name = l.split()[0]
		print("processing " + kingdom_name + " ...")

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
			charcount = 0
			specieslist = list()

			filelist = l.split()
			for f in filelist:
				f = f.replace(",", "").strip()
				studyfiles = (datadir + f + "*.tnt")
				datalist = glob.glob(studyfiles)
				for tb in datalist:
					print("processing " + tb + " ...")

					tb_file = open(tb)
					out += ("& [ num ] @@ {} data ;\n".format(tb) )

					for l in tb_file:
						l = l.strip()
						components = l.split()
						if len(components) != 1 and components[0] != "Label":
							tb_name = tb.split(".")[-2]							
							if tb_name in nchar_dict.keys():
								charcount += int(nchar_dict[tb_name])
							tax = components[0]
							if tax not in specieslist:
								specieslist.append(tax)

					tb_file.close()
				filecount += len(datalist)
			
			species_count = len(specieslist)

			intro = """
macro=;
/* execute me be starting up TNT and then type 'proc <scriptname> ;' */
/* note that you will need to increase memory to at least 50Gb! */
/* memory is increased in megabytes, e.g. using 'mxram 50000 ;' */
nstates 2;
xread
{} {} \n""".format(charcount, species_count) 
			kingdom_file.write(intro)
			kingdom_file.write(out)
			kingdom_file.write("proc/;\n")
	kingdoms_file.close()

if __name__ == "__main__":
	main()