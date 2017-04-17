#!/usr/bin/python3

import argparse
import logging
import binpack
import uuid
import statistics
import time
import os.path
import pprint

logr = logging.getLogger()
console_handler = logging.StreamHandler()
formatter = logging.Formatter( '%(levelname)s [%(filename)s %(lineno)d] %(message)s' )
console_handler.setFormatter( formatter )
logr.addHandler( console_handler )
logr.setLevel( logging.WARNING )

def process_cmdline():
    desc = 'Split filelist based on thresholds.'
    parser = argparse.ArgumentParser( description=desc )
    parser.add_argument( '-s', '--size_max', type=int,
        help='Max size, in bytes, of sum of all file sizes in each output file' )
    parser.add_argument( '-n', '--numfiles_max', type=int,
        help='Max number of files in each output file' )
    parser.add_argument( '-o', '--outdir',
        help='Output directory' )
    parser.add_argument( 'infile', type=argparse.FileType('r') )
    parser.add_argument( '--with_summary', action='store_true' )
    parser.add_argument( '-v', '--verbose', action='store_true' )
    parser.add_argument( '-d', '--debug', action='store_true' )
    group_sep = parser.add_mutually_exclusive_group()
    group_sep.add_argument( '-F', '--field_sep' )
    group_sep.add_argument( '-0', '--null_sep', action='store_true' )
    parser.set_defaults(
        size_max = 1073741824,
        numfiles_max = 1048576,
        outdir = '.',
        field_sep = None
    )
    args = parser.parse_args()
    if args.null_sep:
        args.field_sep = '\x00'
    if args.verbose:
        logr.setLevel( logging.INFO )
    if args.debug:
        logr.setLevel( logging.DEBUG )
    if not os.path.isdir( args.outdir ):
        raise UserWarning( "Output directory '{0}' does not exist".format( args.outdir ) )
    return args


def run():
    args = process_cmdline()
    outfn_count = 1
    active_bins = {}
    donelist = []
    final_bins = {}
    linecount = 0
    starttime = time.time()
    # count line in input
    total_linecount = sum( 1 for line in args.infile )
    args.infile.seek(0)
    # PROCESS INPUT
    for line in args.infile:
        logr.debug( "Processing line: {0}".format( line ) )
        parts = line.strip().split( args.field_sep, 1 )
        logr.debug( pprint.pformat( parts ) )
        item = binpack.File( filename=parts[1], size=int( parts[0] ) )
        # Try to fit into an existing bin
        for key, bin in active_bins.items():
            if bin.insert( item ):
                break
            if bin.is_full():
                final_bins[ key ] = bin
                donelist.append( key )
        else:
            # Doesn't fit in any existing bins, make a new one
            newbin = binpack.Bin( maxsize=args.size_max, maxcount=args.numfiles_max )
            if not newbin.insert( item ):
                raise UserWarning( 'Failed to insert item into bin: {0}'.format( item ) )
            active_bins[ uuid.uuid4() ] = newbin
            logr.debug( "New bin: {0}".format( newbin ) )
        # Remove full bins from active list
        for k in donelist:
            logr.debug( "Full bin: {0}".format( active_bins[k] ) )
            del active_bins[ k ]
        donelist = []
        # Progress report
        linecount += 1
        if linecount % 100000 == 0:
            elapsed = time.time() - starttime
            line_rate = linecount / elapsed
            eta = ( total_linecount - linecount ) / line_rate
            bincount = len( active_bins )
            logr.info( "Lines:{L} ActiveBins:{B} Secs:{S:2.0f} Rate:{R:5.0f} ETA:{E:3.1f}".format(
                L=linecount, 
                S=elapsed, 
                R=line_rate, 
                E=eta, 
                B=bincount ) )

    # Create final bin dict
    endtime = time.time()
    final_bins.update( active_bins )
    bins = final_bins

    # SAVE BINS TO FILES and SUMMARIZE BINS
    sizes = []
    lengths = []
    percents_full = []
    for key, bin in bins.items():
        sizes.append( bin.size )
        lengths.append( len( bin.items ) )
        percents_full.append( float( bin.size ) / bin.maxsize * 100 )
        with open( "{0}/{1}.filelist".format( args.outdir, key ), 'w' ) as f:
            for fn in bin:
                f.write( "{0}\n".format( fn ) )
    totalbins = len( bins )
    if len( sizes ) != totalbins:
        raise UserWarning( "num sizes doesn't match num bins" )
    if len( lengths ) != totalbins:
        raise UserWarning( "num lengths doesn't match num bins" )
    if args.with_summary:
        print( "Runtime: {0:2.0f} secs".format( endtime - starttime ) )
        print( "Total number of bins: {0}".format( totalbins ) )
        # Sizes
        print( "SIZES" )
        print( "Max: {0}".format( max( sizes ) ) )
        print( "Min: {0}".format( min( sizes ) ) )
        print( "PERCENT FULL STATS" )
        for stat in [ "mean", "median", "pstdev", "pvariance" ]:
            f = getattr( statistics, stat )
            print( "{0}: {1:3.2f}".format( stat.title(), f( percents_full ) ) )
        # Lenths
        print( "LENGTH STATS" )
        print( "Max: {0}".format( max( lengths ) ) )
        print( "Min: {0}".format( min( lengths ) ) )
        for stat in [ "mean", "median", "pstdev", "pvariance" ]:
            f = getattr( statistics, stat )
            print( "{0}: {1:3.2f}".format( stat.title(), f( lengths ) ) )
        print( "Num 1-length bins: {0}".format( lengths.count(1) ) )


if __name__ == '__main__':
    run()
