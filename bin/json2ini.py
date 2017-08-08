#!/usr/bin/python3


import sys
import json
import configparser
import tempfile
import os
import argparse

import pprint

def process_cmdline():
    desc = '''
        Read JSON from stdin.
        Convert to INI file with section named JSON.
        Save ini output to a temp file.
        Print path to temp file.
    '''
    parser = argparse.ArgumentParser( description=desc )
    parser.add_argument( '--listelem', '-l', type=int, metavar='N',
        help=( "Input dict has one key, 'DATA', which is a list. "
               "json2ini should parse the Nth list element of DATA" ) )
    defaults = { 'listelem': -1,
               }
    parser.set_defaults( **defaults )
    return parser.parse_args()


def insert_into_cfg( data, cfg ):
    valid_types = ( str, int, float, bool, type( None ) )
    cfg[ 'JSON' ] = {}
    for k,v in data.items():
        if isinstance( v, valid_types ):
            try:
                cfg[ 'JSON' ][ k ] = str( v )
            except ( TypeError ) as e:
                pass


def run():
    args = process_cmdline()
    #pprint.pprint( args )
    rawdata = json.load(sys.stdin)
    cfg = configparser.ConfigParser()
    data = rawdata
    if args.listelem >= 0 :
        #print( 'args.listelem: {}'.format( args.listelem ) )
        data = rawdata[ 'DATA' ][ args.listelem ]
    #pprint.pprint( data )
    #raise SystemExit()
    insert_into_cfg( data, cfg )
    fd, tmpfn = tempfile.mkstemp()
    with os.fdopen( fd, 'w') as fh:
        cfg.write( fh )
    print( tmpfn )

if __name__ == '__main__':
    run()
