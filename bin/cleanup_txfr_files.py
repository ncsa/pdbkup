#!/usr/bin/python3

import argparse
import sys
import json
import os

DESCRIPTION= ''' 
    Move successfully transfered files to OKDIR.
    Move files that failed transfer to FAILDIR.
'''

SUCCESS = [ 'successful_transfer' ]


def process_cmdline():
    parser = argparse.ArgumentParser( description=DESCRIPTION )
    parser.add_argument( '--okdir', required=True )
    parser.add_argument( '--faildir', required=True )
    args = parser.parse_args()
    return args


def run():
    args = process_cmdline()
    okdir = pathlib.Path( args.okdir )
    faildir = pathlib.Path( args.faildir )
    data = json.load( sys.stdin )
    for elem in data[ 'DATA' ]:
        src = pathlib.Path( elem[ 'source_path' ] )
        if src.exists():
            status = elem[ 'DATA_TYPE' ]
            tgt = faildir/src.name
            if status in SUCCESS:
                tgt = okdir/src.name
            src.rename( tgt )


if __name__ == '__main__':
    run()

