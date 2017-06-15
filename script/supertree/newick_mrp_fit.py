#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 01/06/2017

Produce study_id linkage to parsimony score,
using character to study_tb_id mapping, Newick tree and source MRP matrix  

CSV output:
	study_id parsimony_score  
'''

import dendropy
from dendropy.calculate import treescore
from dendropy.model.parsimony import fitch_down_pass

import argparse
import logging

logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.INFO)


def get_scoredict(tbcharcount, score_by_character_list):
	'''
	Input:
		Table linking study_tree_id to character count,
		score_by_character list
	Output:
		dict {study_id : fitch_parsimony_score}
	'''	
	charstr = str()
	scoredict = dict() 

	charcountfile = open(tbcharcount)
	for l in charcountfile:
		studyid = l.split()[0]
		charcount = l.split()[1]
		charstr += (studyid.replace("#", " #")*int(charcount))
	charcountfile.close()

	for tbid, score in zip(charstr.split(), score_by_character_list):	
		studyid = tbid.split(".Tb")[0]   
		if studyid not in scoredict:
			scoredict[studyid] = int(score)
		else:
			scoredict[studyid] += int(score)
      
	charstr = None
	return scoredict


def main():
	
	parser = argparse.ArgumentParser(description='Process commandline arguments')
	parser.add_argument("-i", type=str,
    	                help="Tree file, containing Newick representation of class partition")
	args = parser.parse_args()

	treefile = open(args.i)
	tree = treefile.read().strip()
	
	taxon_namespace = dendropy.TaxonNamespace()	

	tree2 = dendropy.Tree.get(
        data=tree,
        schema="newick",
        suppress_internal_node_taxa=False,
        taxon_namespace=taxon_namespace)
	tree = None
	treefile.close()        

	classname = args.i.split("/")[-1]
	datadir = "../../data/treebase/"
	mrpnexus = datadir+classname.replace(".tre", ".nex") 

	mrpfile = open(mrpnexus)   
	mrp = dendropy.StandardCharacterMatrix.get(
        file=mrpfile,
        schema="nexus",
        taxon_namespace=taxon_namespace)

	score_by_character_list = list()
	score = treescore.parsimony_score(tree2, mrp,
		score_by_character_list=score_by_character_list)
   
	mrpfile.close()
	tree2 = None
	mrp = None

	tbcharcount = datadir+classname.replace(".tre", "_charlabels.txt") 
	scoredict = get_scoredict(tbcharcount, score_by_character_list)
	score_by_character_list = None
    
	# printing output  
	for studytuple in sorted(scoredict.items(), key=lambda x: x[1]):
		study = studytuple[0]         
		print(study[1:], "\t", scoredict[study] ) #score / len(score_by_character_list) ) 

	
if __name__ == "__main__":
	main()