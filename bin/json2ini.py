#!/usr/bin/python3

''' Read JSON from stdin
    Convert to INI file with section named JSON
    Save ini output to a temp file.
    Print path to temp file.
'''

import sys
import json
import configparser
import tempfile
import os

def insert_into_cfg( data, cfg ):
    valid_types = ( str, int, float, bool, type( None ) )
    cfg[ 'JSON' ] = {}
    for k,v in data.items():
        if isinstance( v, valid_types ):
            try:
                cfg[ 'JSON' ][ k ] = str( v )
            except ( TypeError ) as e:
                pass

data = json.load(sys.stdin)
cfg = configparser.ConfigParser()
insert_into_cfg( data, cfg )
fd, tmpfn = tempfile.mkstemp()
with os.fdopen( fd, 'w') as fh:
    cfg.write( fh )
print( tmpfn )
