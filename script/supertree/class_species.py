#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 07/03/2017

Partitions found species in MRP files to class level names

Table output:
	class_id tax_count unique_tax_count overlap_percentage species_id(,species_id)

Usage:
	-i 	Directory containing MRP files
    -t  NCBI taxdmp nodes file
    -n 	NCBI names files
'''

import argparse
import itertools
import os
import glob
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
			names[node_id] = tax_name
	names_file.close()
	return names


def main():

	parser = argparse.ArgumentParser(description='Process commandline arguments')
	parser.add_argument("-i", type=str,
    	                help="Directory with MRP files")
	parser.add_argument("-t", type=str,
    	                help="NCBI taxdmp nodes file")
	parser.add_argument("-n", type=str,
    	                help="NCBI names file")
	args = parser.parse_args()

	logging.info("reading NCBI taxonomy")
	nodes = get_nodes_objects(args.t)	

	logging.info("reading NCBI names")
	names = get_names_dict(args.n)

	datadir = args.i

	class_species = dict()

	filelist = glob.glob(datadir + "S*.dat")
	for tb in filelist:
		logging.info("processing " + tb + " ...")
		tb_file = open(tb)
		for l in tb_file:
			tax_id = l.split()[1].strip()
			species_id = tax_id
			while tax_id != "1":
				if nodes[tax_id].get_rank() == "class":
					if tax_id not in class_species:
						class_species[tax_id] = list()
					class_species[tax_id].append(species_id)
					break
				tax_id = nodes[tax_id].get_parentid()
		tb_file.close()
		
	for c in class_species:
		overlap =  len( set(class_species[c]) ) / len(class_species[c])
		name = names[c].replace("'", "").replace('"', '')
		species = str( set(class_species[c]) )[1:-1].replace("'", "").replace(" ", "")
		print('"' + name + '"', len(class_species[c]), len( set(class_species[c]) ), round(overlap*100, 2), species)


if __name__ == "__main__":
	main()