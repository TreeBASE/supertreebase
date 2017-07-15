#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 21/04/2017

Collecting filenames to write to PAUP* input file in Nexus format.

Nexus output:
		exe Filename.nex;
		exe spr_analysis.nex;
'''

import argparse
import itertools
import os
import glob
import sys
import logging

logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.INFO)


def main():

	datadir = "../../data/treebase/"

	nexlist = glob.glob(datadir + "*.nex")

	print("#NEXUS")
	print("begin paup;")

	for f in nexlist:
		if f.split("/")[-1][0].isupper():
			print("	" + "exe " + f)
			print("	" + "exe " + datadir + "spr_analysis.nex;")
	
	print("	quit;")
	print("end;")


if __name__ == "__main__":
	main()