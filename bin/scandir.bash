#!/usr/bin/bash

#
# scandir in parallel
#
# INPUT
#   srcdir - String - absolute path of directory to be scanned
#   outdir - String - absolute path of directory to store output and log file(s)
# OUTPUT
#   <outdir>/allfileslist - list of files
#   <outdir>/mk_allfileslist.joblog - joblog from Gnu Parallel

[[ $# -ne 2 ]] && {
    echo "Error - scandir: Expected two input parameters; got '$#'"
    exit 1
}
srcdir="$1"
outdir="$2"

##TESTING LIMIT
#maxdepth='-maxdepth 3'

outfile=$outdir/allfileslist
emptydirs=$outdir/emptydirs
dirsonly=$outdir/dirsonly

# Find only Dirs
# Save empty dirs to a file
# Pipe Dirnames to parallel to find all non-dir children
# Save Filesize + Filename to a file
#| tee <( grep '^2\0' | cut -d '' -f 2 > $emptydirs ) \
find "$srcdir" $maxdepth -type d ! -name $'*[\x1-\x1f]*' -printf '%n\0%p\n' \
| tee $dirsonly \
| cut -d '' -f 2 \
| parallel -d '\n' --joblog $outdir/mk_filelist.joblog \
    find '{}' -maxdepth 1 \\\( -type f -o -type l \\\) ! -name "\$'*[\\x1-\\x1f]*'" -printf '%s\\0%p\\n' >> $outfile
echo "Filesystem scan, elapsed seconds: $SECONDS"

#cat "$emptydirs" >> "$outfile"
#parallel -a $dirsonly "grep '^2\0' | cut -d '' -f 2 > $emptydirs

#rm -f "$dirsonly"
