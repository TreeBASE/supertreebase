#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 01/04/2017

Summarize TreeBASE metadata,
showing percentages of found datatypes

Metadata input for study:
	prism:publicationDate	tb:type.matrix	tb:nchar.matrix	tb:ntax.matrix	tb:ntax.tree	tb:quality.tree	tb:type.tree	tb:kind.tree
	YEAR	TYPE.MATRIX	NCHAR.MATRIX	NTAX.MATRIX				
	YEAR												NTAX.TREE	QUALITY.TREE	TYPE.TREE	KIND.TREE
	...

Usage:
    -i  Meta file, containing information about matrices and trees
'''

import argparse


def get_types(metadata):
	'''
	Input:
		Combined metadata
	Output:
		unique matrix types, tree types, quality check types.
		dict { matrices|trees|qualities : list() }
	'''
	outdict = dict()

	matrix_types = list()
	tree_types = list()
	quality_types = list()

	lines = open(metadata)
	for l in lines:
		ltest = l.strip().split("\t")

		if ltest[1]:
			mt = ltest[1]
			if mt not in matrix_types:
				matrix_types.append(mt)
		else:
			qt = ltest[-3] + "|" + ltest[-2]
			tt = ltest[-1]
			if qt not in quality_types:
				quality_types.append(qt)
			if tt not in tree_types and len(tt) > 4:
				tree_types.append(tt)

	matrix_types = matrix_types[1:]
	outdict["matrices"] = matrix_types
	outdict["trees"] = tree_types
	outdict["qualities"] = quality_types 

	lines.close()
	return outdict


def print_matrix_stats(matrix_types, fulldata):

	matrixcount = dict()
	print("tb:type.matrix\n----")
	for i in matrix_types:
		matrixcount[i] = fulldata.count(i)

	total = sum(matrixcount.values())
	for i in matrixcount:
		perc = (matrixcount[i] / total) * 100
		print(i, round(perc, 2))


def print_tree_stats(tree_types, fulldata):

	print("tb:kind.tree\n----")
	treecount = dict()
	for i in tree_types:
		treecount[i] = fulldata.count(i)

	total = sum(treecount.values())
	for i in treecount:
		perc = (treecount[i] / total) * 100
		print(i, round(perc, 2))


def print_qtree(qual, fulldata):

	qualcount = dict()
	print("tb:quality.tree\n----")
	for i in qual:
		qualcount[i] = fulldata.count(i)

	total = sum(qualcount.values())
	for i in qualcount:
		perc = (qualcount[i] / total) * 100
		print(i, round(perc, 2))

def print_ttree(types, fulldata):

	typecount = dict()
	print("tb:type.tree\n----")
	for i in types:
		typecount[i] = fulldata.count(i)

	total = sum(typecount.values())
	for i in typecount:
		perc = (typecount[i] / total) * 100
		print(i, round(perc, 2))

def print_quality_stats(quality_types, fulldata):
	
	qual = list()
	types = list()
	for i in quality_types:
		q = i.split("|")[0]
		t = i.split("|")[1]
		if q not in qual:
			if q:
				qual.append(q)
		if t not in types:
			if t:
				types.append(t)

	print_qtree(qual, fulldata)
	print()
	print_ttree(types, fulldata)
	

def main():

	parser = argparse.ArgumentParser(description='Process commandline arguments')
	parser.add_argument("-i", type=str,
	   	                help="Meta file, containing information about matrices and trees")
	args = parser.parse_args()

	fulldata = open(args.i).read()
	typesdict = get_types(args.i)

	print_matrix_stats(typesdict["matrices"], fulldata)
	print()
	print_tree_stats(typesdict["trees"], fulldata)
	print()
	print_quality_stats(typesdict["qualities"], fulldata)
	print()


if __name__ == "__main__":
	main()
