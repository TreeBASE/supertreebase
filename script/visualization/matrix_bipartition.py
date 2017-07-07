#!/usr/bin/env python

'''
Author: Astrid Blaauw
Date: 03/07/2017

Extract taxon-bipartitions for every position in a combined MRP file:
	#dat.Tb
	tax_name	charstr
	tax_name	charstr
	#dat.Tb
	.. 

Table output:
	#dat.Tb
	char_num	ingroup_taxon,ingroup_taxon,..	outgroup_taxon,outgroup_taxon,..
	char_num	ingroup_taxon,ingroup_taxon,..	outgroup_taxon,outgroup_taxon,..
	#dat.Tb
	.. 

'''

import dendropy
import argparse
import logging

logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.INFO)


def get_mrpdict(mrpclass):
	'''
	Input:
		Filename for a MRP-line collection for a Class partition
	Output:
		Dict { Tb_id : list( [tax, charstr], [tax, charstr], .. ) }
	'''
	mrpdata = open(mrpclass)

	datadict = dict()

	for l in mrpdata:
		l = l.strip()

		if l[0] == "#":
			charcount = 0
			source_name = l 
			datadict[source_name] = list()
		else:
			tax = l.split()[0]
			mrp = l.split()[1]
			datadict[source_name].append([tax, mrp])

	mrpdata.close()
	return datadict


def main():

	parser = argparse.ArgumentParser(description='Process commandline arguments')
	parser.add_argument("-i", type=str,
    	                help="MRP file, containing the MRP taxa-charstring lines used in Class partition")
	args = parser.parse_args()
	
	
	datadict = get_mrpdict(args.i)

	for tb in datadict:
		#dat = tb.split(".")[0][1:]
		
		posdict = dict() # charstr_position : [ list(ingroup), list(outgroup) ]
		if len(datadict[tb]) > 2:
			# proceed if partitions are possible
			for mrpset in datadict[tb]:
				tax = mrpset[0]
				charstr = mrpset[1]
				for c in enumerate(charstr):
					if c[0] not in posdict:
						posdict[c[0]] = [list(), list()]
				for c in enumerate(charstr):
					if c[1] == "0":
						posdict[c[0]][1].append(tax)
					else:
						posdict[c[0]][0].append(tax)

			print(tb)
			for p in posdict:
				ingroup = str(posdict[p][0])[1:-1].replace("'","").replace(" ", "")
				outgroup = str(posdict[p][1])[1:-1].replace("'","").replace(" ", "")
				if not ingroup:
					ingroup = "None"
				if not outgroup:
					outgroup = "None"

				# print output for Tb_id
				print(p+1, "\t", ingroup, "\t", outgroup)

	
if __name__ == "__main__":
	main()