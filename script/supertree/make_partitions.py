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


def get_filedict(filename):
	'''
	Input:
		File name, for table -
		kingdom_name species_count study_count study_ID(, study_ID)
	Output:
		dict { kingdom_name : [study_ID, study_ID] }
	'''
	outdict = dict()
	kingdoms_file = open(filename)
	for l in kingdoms_file:
		l = l.strip()
		kingdom_name = l.split()[0]
		if kingdom_name not in outdict:
			outdict[kingdom_name] = list()
			filelist = l.split()
			for f in filelist[3:]:
				f = f.replace(",", "").strip()
				outdict[kingdom_name].append(f)
	kingdoms_file.close()		
	return outdict


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

	filedict = get_filedict(args.i)
	analysistype = args.a

	datadir = "../../data/treebase/"


	for kingdom_name in filedict:

		filecount = 0
		out = ""

		#SDM partition
		if analysistype == "S":

			print("processing " + kingdom_name + " ...")
			kingdom_file = open(datadir + "tb2dist_" + kingdom_name, "a")

			filelist = filedict[kingdom_name]
			for f in filelist:
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

			print("processing " + kingdom_name + " ...")
			kingdom_file = open(datadir + "tntscript.run" + kingdom_name, "a")
			charcount = 0
			specieslist = list()

			filelist = filedict[kingdom_name]
			for f in filelist:
				studyfiles = (datadir + f + "*.tnt")
				datalist = glob.glob(studyfiles)
				for tb in datalist:
					#print("processing " + tb + " ...")
						
					tb_file = open(tb)
					out += ("& [ num ] @@ {} data ;\n".format(tb.split("/")[-1]) )

					for l in tb_file:
						l = l.strip()
						components = l.split()
						if len(components) != 1 and components[0] != "Label":
							tax = components[0].strip()
							if tax not in specieslist:
								specieslist.append(tax)
							charstring = components[1].strip()
					charcount += len(charstring)

					tb_file.close()
				filecount += len(datalist)
				
			species_count = len(specieslist)

			intro = """macro=;
/* execute me be starting up TNT and then type 'proc <scriptname> ;' */
/* note that you will need to increase memory to at least 50Gb! */
/* memory is increased in megabytes, e.g. using 'mxram 50000 ;' */
nstates 2;
xread
{} {} \n""".format(charcount, species_count) 
			kingdom_file.write(intro)
			kingdom_file.write(out)
			kingdom_file.write("proc/;\n")


if __name__ == "__main__":
	main()