#!/usr/bin/python3

import xml.etree.ElementTree
import argparse
import sys
import os.path
import pprint
import logging

def process_cmdline():
    parser = argparse.ArgumentParser()
    parser.add_argument('-f', '--fsroot', help='fsroot that was given to dar create')
    parser.add_argument('files', metavar='FILE', nargs='*', help='files to read, if empty, stdin is used')
    defaults = { 'fsroot': '__FSROOT__' }
    parser.set_defaults( **defaults )
    return parser.parse_args()


def read_xml( args ):
    xtree = None
    if len( args.files ) > 0:
        xtree = xml.etree.ElementTree.parse( args.files[0] )
    else:
        xtree = xml.etree.ElementTree.parse( sys.stdin )
    return xtree


def xml2filenames( path, elem ):
    logging.debug( 'Enter: path={}, {}'.format( path, pprint.pformat( elem ) ) )
    for child in elem:
        logging.debug( 'Processing: {}'.format( pprint.pformat( child ) ) )
        if child.tag in ( 'Catalog', 'Attributes' ):
            continue
        newpath = os.path.join( path, child.attrib[ 'name' ] )
        if child.tag == 'Directory':
            xml2filenames( newpath, child )
        elif child.tag in ( 'File', 'Symlink', 'Socket', 'Pipe' ):
            print( newpath )
        else:
            raise UserWarning( "Unknown Element tag '{}'".format( child.tag ) )

def run():
    args = process_cmdline()
    xtree = read_xml( args )
    root = xtree.getroot()
    xml2filenames( args.fsroot, root )


if __name__ == '__main__':
#    logging.basicConfig( level=logging.DEBUG )
    logging.basicConfig( level=logging.WARNING )
    run()
