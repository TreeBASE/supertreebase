#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 20/05/2017

Adding phylum and kingdom ranks to the classdata table.
(with help of the NCBI taxonomy).

Pipeline study_species table input:
    study_ID species_count species_ID(,species_ID)

Class table output:
	class_ID species_count study_count study_ID(, study_ID)

Usage:
    -i  Text file containing study_ID's linked to species_ID list
    -t  NCBI taxdmp nodes file
    -n 	NCBI names files
    -o  Output file
'''

import argparse
import itertools
import os
import sys
import logging

logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.INFO)


class TaxNode:
	'''NCBI node class'''

	def __init__(self, taxid, parentid, rank):
		self.taxid = taxid
		self.parentid = parentid
		self.rank = rank

	def get_taxid(self):
		return self.taxid

	def get_parentid(self):
		return self.parentid

	def get_rank(self):
		return self.rank


def get_nodes_objects(nodedmp):
	'''
	Input:
		NCBI nodes.dmp
	Output:
		dict {node_id : node_object}
	'''
	nodes_file = open(nodedmp)
	nodes = dict()
	for i in nodes_file:
		line = i.split("|")
		node_id = line[0].strip()
		parent_id = line[1].strip()
		rank = line[2].strip()
		nodes[node_id] = TaxNode(node_id, parent_id, rank)
	nodes_file.close()
	return nodes

def get_names_dict(namedmp):
	'''
	Input:
		NCBI names.dmp
	Output:
		dict {node_id : tax_name}
	'''
	names_file = open(namedmp)
	names = dict()
	for i in names_file:
		line = i.split("|")
		if "scientific name" in i:
			node_id = line[0].strip()
			tax_name = line[1].strip()
			names[tax_name] = node_id
	names_file.close()
	return names


def main():

	parser = argparse.ArgumentParser(description='Process commandline arguments')
	parser.add_argument("-i", type=str,
    	                help="Input file (table file with study_ID's linked to species_ID's)")
	parser.add_argument("-t", type=str,
    	                help="NCBI taxdmp nodes file")
	parser.add_argument("-n", type=str,
    	                help="NCBI names file")
	args = parser.parse_args()
	 

	logging.info("reading NCBI taxonomy")
	nodes = get_nodes_objects(args.t)
	names = get_names_dict(args.n)
	names["none"] = "None"
	inv_names = {v: k for k, v in names.items()}

	classdata = open(args.i)

	classlist = list()
	for l in classdata:
		if l.count("_") < 2:
			classname = l.split()[0]
			classlist.append(classname)

	lineagelist = list()
	for classname in classlist:
		classlineage = list()
		classlineage.append(classname)
		nid = names[classname]
		while nid != "1":
			# check if targeted class taxon is found
			nid = nodes[nid].get_parentid()	
			if nodes[nid].get_rank() == "phylum":
				classlineage.append(inv_names[nid])
			if nodes[nid].get_rank() == "kingdom" or nodes[nid].get_rank() == "superkingdom":
				classlineage.append(inv_names[nid])
				lineagelist.append(classlineage)
				break

	for l in lineagelist:
		if len(l) != 3:
			print("{}\t{}\t{}".format(l[0], "None", l[1]) )
		else:
			print("{}\t{}\t{}".format(l[0], l[1], l[2]) )


	# python3 get_class_lineages.py -i "classdata2.txt" -t "data/taxdmp/nodes.dmp" -n "data/taxdmp/names.dmp" >> "script/supertree/lineage_table.txt"


if __name__ == "__main__":
	main()