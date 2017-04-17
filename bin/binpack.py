class Bin( object ):
    ''' Container for File objects that tracks cumulative size and file count
    '''
    def __init__( self, 
                  maxsize=107374182400, 
                  maxcount=1073741824, 
                  fill_percent=90,
                  allow_oversized=True ):
        self.items = []
        self.size = 0
        self.maxsize = maxsize
        self.maxcount = maxcount
        # Allow bin to hold a single item that is larger than maxsize 
        # iff that is the only item in the bin
        self.allow_oversized = allow_oversized
        self.fill_percent = fill_percent / 100.0

    def __str__( self ):
        return "<{C} (len:{L} size:{S} %:{P})>".format(
            C=self.__class__.__name__, 
            L=len( self.items ), 
            S=self.size,
            P=self.fill_percent
        )
    __repr__ = __str__

    def insert( self, item ):
        ''' Attempt to insert and item into the bin.
            Checks are made to ensure the bin does not exceed any of it's capacities.
            Return True if item was inserted in the bin successfully, False otherwise
        '''
        can_fit = False
        newsize = item.size + self.size
        if newsize <= self.maxsize and len( self.items ) < self.maxcount:
            can_fit = True
        elif self.allow_oversized and len( self.items ) == 0:
            #enable oversize
            self.maxcount = 1
            can_fit = True
        if can_fit:
            self.items.append( item )
            self.size = newsize
        return can_fit

    def __iter__( self ):
        return iter( self.items )

    def is_full( self ):
        rv = False
        if len( self.items ) >= self.maxcount:
            rv = True
        elif self.size >= ( self.maxsize * self.fill_percent ):
            rv = True
        return rv


class File( object ):
    ''' Representation of a file containing absolute path and size in bytes.
    '''
    def __init__( self, filename, size ):
        self.filename = filename
        self.size = size

    def __str__( self ):
        return self.filename

    def __repr__( self ):
        return "{0}.File({1}, {2})".format( __name__, self.filename, self.size )
