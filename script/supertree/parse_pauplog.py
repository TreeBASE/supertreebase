#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 26/04/2017

Getting usefull information from PAUP* logfile

Table output:
	Class	minimum_length       length    consistenct_index	retention_index rescaled_consistency_index goloboff_fit
	
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
		dict { Class : [ CI, RI, RC, Gfit ] }
	'''
	outdict = dict()
	log_file = open(filename)

	minlength = None
	length = None
	ci = None
	ri = None
	rc = None
	gfit = None

	class_name = None

	for l in log_file:
		if "Sum of min." in l:
			minlength = l.strip().split("=")[-1]
		if l.startswith("Length") and len(l.strip().split()) == 2:
			length = l.strip().split()[1]
		if l.startswith("CI"):
			ci = l.strip().split()[1]
			if "/" in ci:
				ci = "1.000"
		if l.startswith("RI"):
			ri = l.strip().split()[1]
			if "/" in ri:
				ri = "1.000"
		if l.startswith("RC"):
			rc = l.strip().split()[1]
			if "/" in rc:
				rc = "1.000"
		if l.startswith("G-fit"):
			gfit = l.strip().split()[1]
			if "/" in gfit:
				gfit = "0.000"
		if "tree saved to file" in l:
			directory = l.strip().split('"')[1]
			class_name = directory.split("/")[-1]
		if minlength and length and ci and ri and rc and gfit and class_name:
			if class_name not in outdict:
				outdict[class_name] = [minlength, length, ci, ri, rc, gfit]
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
		minlength = filedict[c][0]
		length = filedict[c][1]
		ci = filedict[c][2]
		ri = filedict[c][3]
		rc = filedict[c][4]
		gfit = filedict[c][5]
		c = c.replace(".tre", "")
		print(c + "\t" + minlength + "\t" + length + "\t" + ci + "\t" + ri + "\t" + rc + "\t" + gfit)


if __name__ == "__main__":
	main()