#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 17/05/2017

Translate Newick tree to CSV file for D3

CSV output:
	name,parent
	rootname,
	nodename,parent
	nodename,parent
	...
'''

import dendropy
import argparse
import logging

logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.INFO)


def get_intnode_tree(treename):
	'''
	Input:
		Filename for a Newick tree to be processed
	Output:
		New tree string, containing internal nodes
	'''
	treefile = open(treename)
	tree = treefile.read().strip()

	intnode_tree = str()
	intnode_count = 0
	for p in tree.split(")"):
		intnode_count += 1
		if p == ";":
			intnode_tree += p
		else:
			intnode_tree += (p+")"+"Node_"+str(intnode_count))

	tree = None
	treefile.close()
	return intnode_tree


def main():

	parser = argparse.ArgumentParser(description='Process commandline arguments')
	parser.add_argument("-i", type=str,
    	                help="Tree file, containing Newick representation of class partition")
	args = parser.parse_args()
	
	intnode_tree = get_intnode_tree(args.i)

	tree2 = dendropy.Tree.get(
        data=intnode_tree,
        schema="newick",
        suppress_internal_node_taxa=False)

	print("name,parent")
	parent_dict = dict()

	nonecount = 0
	for node in tree2.preorder_node_iter():
		parent = node.parent_node
		if parent:			
			n = str(node.taxon)[1:-1]
			p = str(parent.taxon)[1:-1]
			parent_dict[n] = p
			print(n + "," + p)
		else:
			parent_dict[str(node.taxon)[1:-1]] = "none"
			print(str(node.taxon)[1:-1])

	
if __name__ == "__main__":
	main()