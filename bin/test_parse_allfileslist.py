#!/usr/bin/env python

import argparse
import pprint

parser = argparse.ArgumentParser()
parser.add_argument( 'infile', type=argparse.FileType('r') )
group_sep = parser.add_mutually_exclusive_group()
group_sep.add_argument( '-F', '--field_sep' )
group_sep.add_argument( '-0', '--null_sep', action='store_true' )
parser.set_defaults( 
    field_sep = None
)
args = parser.parse_args()
if args.null_sep:
    args.field_sep = '\x00'

for line in args.infile:
    parts = line.strip().split( args.field_sep, 1 )
    pprint.pprint( parts )
