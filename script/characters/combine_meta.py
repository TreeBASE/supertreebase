#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 15/04/2017

Making a table for easier metadata parsing.

Metadata input for study:
	prism:publicationDate	tb:type.matrix	tb:nchar.matrix	tb:ntax.matrix	tb:ntax.tree	tb:quality.tree	tb:type.tree	tb:kind.tree
	YEAR	TYPE.MATRIX	NCHAR.MATRIX	NTAX.MATRIX				
	YEAR												NTAX.TREE	QUALITY.TREE	TYPE.TREE	KIND.TREE

Table entry output:
	S.dat	YEAR(,YEAR)	TYPE.MATRIX(,TYPE.MATRIX)

Usage:
    -i  Meta file, containing information about matrices and trees
'''

import argparse


def main():

	parser = argparse.ArgumentParser(description='Process commandline arguments')
	parser.add_argument("-i", type=str,
    	                help="Meta file, containing information about matrices and trees")
	args = parser.parse_args()
	

	metafile = open(args.i)

	if "sitemap" not in metafile.name:

		years = list()
		types = list()

		for l in metafile:
			if "prism:" not in l:
				l = l.strip().split()
				years.append(l[0])
				if len(l) == 4:
					types.append(l[1])
		
		if years and types:		
			studyname = metafile.name.split("/")[-1].replace("meta", "dat")
			years_str = str( set(years) ).replace("'", "").replace("{", "").replace("}", "").replace(" ", "") 
			types_str = str( set(types) ).replace("'", "").replace("{", "").replace("}", "").replace(" ", "") 
			print(studyname + "\t" + years_str + "\t" + types_str)

	metafile.close()


if __name__ == "__main__":
	main()