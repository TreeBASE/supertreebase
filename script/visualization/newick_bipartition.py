#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 27/06/2017

Extract leafnode-bipartitions for every internal node in a Newick tree 

Table output:
	internal_node	ingroup_leaf,ingroup_leaf,..	outgroup_leaf,outgroup_leaf,..
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

def get_ingroup_dict(treeobj, leafnodelist):
	'''
	Input:
		DendroPy tree object, containing internal nodes
	Output:
		Dict { internal_node_name : list(leafnode_for_this_node, leafnode_for_this_node, ..) }
	'''
	node_ingroup_dict = dict()

	for node in treeobj.preorder_node_iter():
		nodename = str(node.taxon)[1:-1]

		if nodename.replace(" ", "_") not in leafnodelist:
			node_ingroup_dict[nodename] = list()

			subtree = dendropy.Tree(seed_node=node) 
			for subnode in subtree.preorder_node_iter():
				subnodename = str(subnode.taxon)[1:-1]
				if subnodename.replace(" ", "_") in leafnodelist:
					node_ingroup_dict[nodename].append(subnodename.replace(" ", "_"))

	return node_ingroup_dict

def get_sourcesplit_dict(mrpdata):
	'''
	Input:
		Filename, containing splits found in every treebase study
	Output:
		Dict { tb_study_id : list( [ [ingroup_leaf, ingroup_leaf, ..], [outgroup_leaf, outgroup_leaf, ..] ],  ..) }
	'''
	splitdict = dict()

	splitdata = open(mrpdata)
	for l in splitdata:
		l = l.strip()
		if "#" in l:
			source_id = l[1:]
			if source_id not in splitdict:
				splitdict[source_id] = list()
		else:		
			mrpsplit_in = set(l.split()[-2].split(",") )
			mrpsplit_out = set(l.split()[-1].split(",") )

			if "None" in mrpsplit_in:
				mrpsplit_in = set()
			if "None" in mrpsplit_out:
				mrpsplit_out = set() 

			splitlist = [mrpsplit_in, mrpsplit_out]
			if splitlist not in splitdict[source_id]:
				splitdict[source_id].append(splitlist)
	
	splitdata.close()
	return splitdict


def main():

	parser = argparse.ArgumentParser(description='Process commandline arguments')
	parser.add_argument("-i", type=str,
    	                help="Tree file, containing Newick representation of class partition")
	args = parser.parse_args()
	
	intnode_tree = get_intnode_tree(args.i)

	mrp_bipartition = args.i.replace(".tre", ".mrpsplit")
	splitdict = get_sourcesplit_dict(mrp_bipartition)

	treeobj = dendropy.Tree.get(
        data=intnode_tree,
        schema="newick",
        suppress_internal_node_taxa=False)

	#print(treeobj.as_ascii_plot())
	#print(treeobj.as_string(schema='newick'))

	leafnodelist = list()
	for l in treeobj.leaf_node_iter():
		leafnodelist.append(str(l.taxon)[1:-1].replace(" ", "_"))

	node_ingroup_dict = get_ingroup_dict(treeobj, leafnodelist)

	source_list = splitdict.keys()

	leafnodelist = leafnodelist[1:] # ignore hypothetical outgroup
	for n in node_ingroup_dict:
		ingroup = set(node_ingroup_dict[n])
		outgroup = set(leafnodelist).difference(ingroup)
		if outgroup:

			support_trees = list()
			oppose_trees = list()


			for source_id in splitdict:
				for split in splitdict[source_id]:
					mrpsplit_in = split[0]
					mrpsplit_out = split[1]

					if (mrpsplit_in.issubset(ingroup)) and (mrpsplit_out.issubset(outgroup)):
						if source_id not in support_trees:
							support_trees.append(source_id)

							#print(mrpsplit_in, ":::", ingroup)
							#print(mrpsplit_out, ":::", outgroup)
						#else:
						#	if source_id not in oppose_trees:
						#		if source_id not in support_trees:
						#			oppose_trees.append(source_id)

			support_trees = set(support_trees)
			oppose_trees = set(source_list).difference(support_trees)

			support_str = str(support_trees)[1:-1].replace("'","").replace(", ", ",")
			oppose_str = str(oppose_trees)[1:-1].replace("'","").replace(", ", ",")

			if not support_trees:
				support_str = "None"
			if not oppose_trees: 
				oppose_trees = "None"

			try:
				print(n, "\t", support_str, "\t", oppose_str, "\t", (len(support_trees)/len(oppose_trees))/len(source_list) )
			except ZeroDivisionError:
				print(n, "\t", "None", "\t", "None", "\t", "0" )
			
			#ingroup_str = str(ingroup)[1:-1].replace("'","").replace(", ", ",").replace(" ", "_")
			#outgroup_str = str(outgroup)[1:-1].replace("'","").replace(", ", ",").replace(" ", "_")
			
			# print output for every internal node
			#print(n.replace(" ", "_"), "\t", ingroup_str, "\t",  outgroup_str)

	
if __name__ == "__main__":
	main()