#!/usr/bin/python

import ConfigParser
import argparse
import os.path
import logging
import datetime
import pprint

logr = logging.getLogger()
console_handler = logging.StreamHandler()
#fmtr = logging.Formatter( '%(asctime)s %(module)s %(funcName)s %(filename)s %(lineno)d %(message)s' )
formatter = logging.Formatter( '%(levelno)s [%(filename)s %(lineno)d] %(message)s' )
console_handler.setFormatter( formatter )
logr.addHandler( console_handler )
logr.setLevel( logging.WARNING )


def process_cmdline():
    desc = 'Get DAR stats from ini file'
    parser = argparse.ArgumentParser( description=desc )
    parser.add_argument( 'filename', metavar='FILE', help='INI file' )
    parser.add_argument( '-d', '--debug', action='store_true' )
    parser.add_argument( '-v', '--verbose', action='store_true' )
    args = parser.parse_args()
    if args.verbose:
        logr.setLevel( logging.INFO )
    elif args.debug:
        logr.setLevel( logging.DEBUG )
    return args


def parse_inifile( args ):
    cfg = ConfigParser.SafeConfigParser()
    cfg.read( args.filename )
    data = {}
    slice_data = {}
    for key, val in cfg.items( 'DAR' ):
        logr.debug( 'found key {0}'.format( key ) )
        parts = key.split( '_' )
        logr.debug( 'PARTS: {0}'.format( parts ) )
        if parts[0] == 'slice':
            slicenum = parts[1]
            subkey = parts[2]
            if slicenum not in slice_data:
                slice_data[ slicenum ] = {}
            slice_data[ slicenum ][ subkey ] = val
        else:
            data[ key ] = val
    logr.debug( 'SLICE_DATA: {0}'.format( slice_data ) )
    data[ 'slices' ] = slice_data
    return data


def print_summary( data, args ):
    slice_data = data[ 'slices' ]
    num_slices = len( slice_data )
    total_elapsed = 0
    total_size = 0
    # create summary data of slices
    for key, val in slice_data.iteritems():
        elapsed = int( slice_data[ key ][ 'end' ] ) - int( slice_data[ key ][ 'start' ] )
        total_elapsed += elapsed
        total_size += int( slice_data[ key ][ 'size' ] )
    size_gib = total_size / 1073741824.0
    delta = datetime.timedelta( seconds=total_elapsed )
    rate = float( total_size ) / float( total_elapsed )
    rate_mbs = float( total_size ) / 1048576.0 / total_elapsed
    # create summary of overall process
    status = 'Running'
    if 'exitcode' in data:
        status = 'Exited with {0}'.format( data[ 'exitcode' ] )
    # print summary data
    print( 'NUM_SLICES: {0}'.format( num_slices ) )
    print( 'TOTAL_SIZE: {0} B ({1:3.2f} GiB)'.format( total_size, size_gib ) )
    print( 'TOTAL_ELAPSED: {0} seconds ({1})'.format( total_elapsed, delta ) )
    print( 'AVG RATE: {0:3.3f} B/s ({1:3.3f} MiB/s)'.format( rate, rate_mbs ) )
    print( 'STATUS: {0}'.format( status ) )


if __name__ == '__main__':
    args = process_cmdline()
    data = parse_inifile( args )
    pprint.pprint( data )
    print_summary( data, args )

