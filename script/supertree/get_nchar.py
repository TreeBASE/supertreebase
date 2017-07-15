#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 04/04/2017

Creates table that reads the nexus file for every Class partition and extracts the number of characters
'''

import argparse
import itertools
import os
import glob
import sys
import logging


def main():

	datadir = "../../data/treebase/"

	# collect every nexus file to be evaluated
	filelist = glob.glob(datadir + "*.nex")

	for f in filelist:
		classname = f.split("/")[-1].replace(".nex", "")
		for l in open(f):
			l = l.strip()
			if "nchar=" in l:
				nchar = l.split("=")[-1]
				print(classname + "\t" + nchar.replace(";", ""))
				break


if __name__ == "__main__":
	main()