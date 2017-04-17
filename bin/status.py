#!/usr/bin/env python3

import os
import configparser
import pathlib
import pprint
import collections
import statistics
import datetime
import argparse


class BkupDir( object ):
    def __init__( self, path ):
        self.path = path
        self.filelist = []
        self.num_expected_slices = 0
        self.slices = {}
        self._is_loaded = False
        self.load()

    def __str__( self ):
        return '<{0} ({1})>'.format( self.__class__.__name__, self.path )
    __repr__ = __str__

    def load( self ):
        if self._is_loaded:
            return
        for x in self.path.iterdir():
            if x.is_file():
                if x.suffix == '.ini':
                    self.filelist.append( x )
                elif x.suffix == '.filelist':
                    self.num_expected_slices += 1
        self.slices = {}
        for f in self.filelist:
            name = f.stem.split( '_' )[3]
            c = configparser.ConfigParser()
            c.optionxform = lambda option: option
            c.read( str( f ) )
            self.slices[ name ] = c
        self._is_loaded = True

    def reload( self ):
        self._is_loaded = False
        self.load()

    def as_list( self, section, key, formatter=str ):
        #return [ cfg[section][key] for s,cfg in self.slices.items() ]
        return [ formatter( cfg[ section ][ key ] ) for name, cfg in
            self.slices.items() if key in cfg[ section ] ]

    def dar_status( self ):
        failed = 0
        succeeded = 0
        completed = 0
        active = 0
        pending = self.num_expected_slices - len( self.slices )
        total = self.num_expected_slices
        for name, cfg in self.slices.items():
            if 'ELAPSED' in cfg[ 'DAR' ]:
                completed += 1
                if int( cfg[ 'DAR' ][ 'EXITCODE' ] ) == 0:
                    succeeded += 1
                else:
                    failed += 1
            elif 'START' in cfg[ 'DAR' ]:
                active += 1
        nt = collections.namedtuple( 'DarStatus', 'failed succeeded completed active pending total' )
        return nt( failed, succeeded, completed, active, pending, total )

    def dar_runtime_stats( self ):
#        times = [ int( cfg[ 'DAR' ][ 'ELAPSED' ] ) for name, cfg 
#            in self.slices.items() if 'ELAPSED' in cfg[ 'DAR' ] ]
        times = self.as_list( 'DAR', 'ELAPSED', formatter=int )
        if len( times ) < 1:
            raise UserWarning( 'insufficient stats data' )
        nt = collections.namedtuple( 'DarTimes', 'min max median mean stdev' )
        return nt( min( times ),
                   max( times ),
                   statistics.median( times ),
                   statistics.mean( times ),
                   statistics.pstdev( times ) )

    def dar_elapsed_total( self ):
        """ Total runtime for all dars to complete
            Returns: namedtuple( total_runtime )
        """
        start = min( self.as_list( 'DAR', 'START', formatter=int ), default=0 )
        end = max (self.as_list( 'DAR', 'END', formatter=int ), default=0 )
        if end < 1 or start < 1:
            raise UserWarning( 'insufficient time data' )
        runtime = end - start
        nt = collections.namedtuple( 'DarRuntime', 'total_runtime' )
        return nt( runtime )


def histogram( intlist, title, x_key, x_numcols=20, max_height=80, tick='*' ):
    if len( intlist ) < 1:
        print( 'insufficient histogram data' )
        return
    buckets = [0] * x_numcols
    heights = [0] * x_numcols
    v_max = max( intlist )
    divider = int( v_max / x_numcols ) + 1
#    print( 'Divider: {0}'.format( divider ) )
    for v in intlist:
        i = int( v / divider )
#        print( 'Actual: {0} : Bucket #: {1}'.format( v, i ) )
        buckets[i] += 1
#    print( 'Buckets: {0}'.format( buckets ) )
    scalar = max_height / ( max( buckets ) - min( buckets ) )
#    print( 'Scalar: {0}'.format( scalar ) )
    for i,v in enumerate( buckets ):
        if v > 0:
            heights[ i ] = max( 1, int( v * scalar ) )
        else:
            heights[ i ] = 0
#    print( 'Heights: {0}'.format( heights ) )
    print( title )
    print( x_key )
    header_fmt = '{0:>' + str( len( x_key ) ) + 'd}'
    graph_fmt = '{0:' + str( max_height ) + 's}'
    label_fmt = '({0:>2})'
    for i,h in enumerate( heights ):
        hdr = header_fmt.format( ( i + 1 ) * divider )
        line = graph_fmt.format( tick * h )
        label = label_fmt.format( buckets[i] )
        print( '{0} {1} {2}'.format( hdr, line, label ) )


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument( 'bkupinfodir' )
    parser.add_argument( '--dar_summary', action='store_true' )
    parser.add_argument( '--dar_histogram', action='store_true' )
    parser.add_argument( '--dar_filecountgraph', action='store_true' )
    parser.add_argument( '-a', '--all', action='store_true' )
#    default_opts = {
#        'dar_summary': False,
#        'dar_histogram': False,
#    }
#    parser.set_defaults( **default_opts )
    args = parser.parse_args()
    if args.all:
        args.dar_summary = True
        args.dar_histogram = True
        args.dar_filecountgraph = True
    return args


def printenv( name ):
    print( '{0}: {1}'.format( name, os.getenv( name ) ) )


def load_cfg():
    cfg_fn = '{0}/conf/settings.ini'.format( os.environ[ 'BKUP_BASE' ] )
    cfg = configparser.ConfigParser()
    cfg.optionxform = lambda option: option
    cfg.read( cfg_fn )
    return cfg


def show_cfg( cfg ):
    for ( section, opts ) in cfg.items():
        print( '{0}:'.format( section ) )
        for ( option, value ) in opts.items():
            print( '  {0}: {1}'.format( option, value ) )


#def find_all_infodirs( cfg ):
#    infodir_base = pathlib.Path( cfg[ 'GENERAL' ][ 'INFODIR' ] )
#    subdirs = [ x for x in infodir_base.iterdir() if x.is_dir() ]
#    datedirs = []
#    for d in subdirs:
#        datedirs.extend( [ x for x in d.iterdir() if x.is_dir() ] )
#    return datedirs
    
def print_dar_summary( bkupdir ):
    print( 'Dar Slice Status' )
    sdata = bkupdir.dar_status()
    for i,k in enumerate( sdata._fields ):
        print( '    {k}: {v}'.format( k=k.capitalize(), v=sdata[i] ) )
    print( 'Dar Slice Statistics' )
    try:
        tdata = bkupdir.dar_runtime_stats()
    except ( UserWarning ) as e:
        print( e )
    else:
        for i,k in enumerate( tdata._fields ):
            print( '    {k}: {s} ({t})'.format( 
                k=k.capitalize(), s=tdata[i], t=datetime.timedelta( seconds=tdata[i] ) ) )
    print( 'Dar Runtime' )
    try:
        rdata = bkupdir.dar_elapsed_total()
    except ( UserWarning ) as e:
        print( e )
    else:
        for i,k in enumerate( rdata._fields ):
            print( '    {k}: {s} ({t})'.format( 
                k=k.capitalize(), s=rdata[i], t=datetime.timedelta( seconds=rdata[i] ) ) )


#def filecountgraph( bkupdir ):


def run():
    cfg = load_cfg()
#    show_cfg( cfg )
    args = parse_args()
    infodir = pathlib.Path( args.bkupinfodir )
    if not infodir.is_dir():
        raise UserWarning( 'bkupinfodir is not a directory: {0}'.format( infodir ) )
#    if args.bkupinfodir:
#        infodir_base = pathlib.Path( cfg[ 'GENERAL' ][ 'INFODIR' ] )
#        infodir = infodir_base / args.bkupinfodir
#        if not infodir.is_dir():
#            raise UserWarning( 'bkupinfodir is not a directory: {0}'.format( infodir ) )
#    else:
#        infodirs = find_all_infodirs( cfg )
#        infodir = sorted( find_all_infodirs( cfg ) )[-1]
    print( 'Processing: {0}'.format( infodir ) )
    bkupdir = BkupDir( infodir )
    if args.dar_summary:
        print_dar_summary( bkupdir )

    if args.dar_histogram:
        histogram( intlist = bkupdir.as_list( 'DAR', 'ELAPSED', formatter=int ),
                   title = 'Dar Slice Elapsed Time',
                   x_key = 'Num Seconds',
                   max_height = 40 )

#    if args.dar_filecountgraph:
#        print( "FilecountGraph" )

if __name__ == "__main__":
    run()
