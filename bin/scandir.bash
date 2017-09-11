#!/usr/bin/bash

#
# scandir in parallel
#
# INPUT
#   srcdir    - String - absolute path of directory to be scanned
#   outdir    - String - absolute path of directory to store output and log file(s)
#   timestamp - String - [OPTIONAL] - select only files newer than timestamp
#                        Default = 0 (epoch)
# OUTPUT
#   <outdir>/scandir.out - list of files
#   <outdir>/scandir.joblog - joblog from Gnu Parallel

if [[ $# -lt 2 || $# -gt 3 ]] ; then
    echo "Error - scandir: Expected two input parameters; got '$#'"
    exit 1
fi
srcdir="$1"
outdir="$2"
timestamp=$( echo "$3" | tr -cd '[0-9]' )
[[ -n "$timestamp" ]] || timestamp=0

##TESTING LIMIT
#maxdepth='-maxdepth 3'

outfile=$outdir/scandir.out
joblog=$outdir/scandir.joblog
emptydirs=$outdir/emptydirs

# Find only Dirs
# Save empty dirs to a file
# Pipe Dirnames to parallel to find all non-dir children
# Save Filesize + Filename to a file
find "$srcdir" $maxdepth -type d ! -name $'*[\x1-\x1f]*' -printf '%n\0%p\n' \
| tee >( grep -Pa '^2\x0' > $emptydirs ) \
| cut -d '' -f 2 \
| parallel -d '\n' --joblog $joblog \
    find '{}' -maxdepth 1 \\\( -type f -o -type l \\\) ! -name "\$'*[\\x1-\\x1f]*'" -newerct "@$timestamp" -printf '%s\\0%p\\n' >> $outfile
echo "Filesystem scan, elapsed seconds: $SECONDS"

cat "$emptydirs" >> "$outfile"
rm -f "$emptydirs"
