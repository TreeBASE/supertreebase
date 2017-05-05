#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 26/04/2017

Getting usefull information from PAUP* logfile

Table input:
	#comment
	species_ID character_string

Nexus output:
	Class	consistenct_index	retention_index
	
Usage:
    -i  Text file, containing verbose PAUP* logging for supertree-inference runs
'''

import argparse
import itertools
import os
import glob
import sys
import logging

logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.INFO)


def get_filedict(filename):
	'''
	Input:
		PAUP log
	Output:
		dict { Class : [ CI, RI ] }
	'''
	outdict = dict()
	log_file = open(filename)

	ci = None
	ri = None
	class_name = None

	for l in log_file:
		if l.startswith("CI"):
			ci = l.strip().split()[1]
			if "/" in ci:
				ci = "1.000"
		if l.startswith("RI"):
			ri = l.strip().split()[1]
			if "/" in ri:
				ri = "1.000"
		if "tree saved to file" in l:
			directory = l.strip().split('"')[1]
			class_name = directory.split("/")[-1]
		if ci and ri and class_name:
			if class_name not in outdict:
				outdict[class_name] = [ci, ri]
	log_file.close()		
	return outdict


def main():

	parser = argparse.ArgumentParser(description='Process commandline arguments')
	parser.add_argument("-i", type=str,
    	                help="Text file, containing verbose PAUP* logging for supertree-inference runs")
	args = parser.parse_args()
	
	filedict = get_filedict(args.i)	

	# write output
	for c in filedict:
		ci = filedict[c][0]
		ri = filedict[c][1]
		c = c.replace(".tre", "")
		print(c + "\t" + ci + "\t" + ri)

if __name__ == "__main__":
	main()