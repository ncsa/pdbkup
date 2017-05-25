#!/bin/bash

function die() {
    echo "$*"
    exit 99
}

[[ -z "$1" ]] && die Missing restore sources dirname
[[ -d "$1" ]] || die "Not a directory '$1'"

find "$1" -maxdepth 1 -type f -name '*.dar.restore.log' \
| sort \
| while read; do
    tail -n 13 "$REPLY" \
    | awk -v "logfile=$REPLY" '

/inode\(s\) restored/ { num_restored=$1 }
/Total number of inode\(s\) considered/ { num_considered=$NF }
END {
    status="MISMATCH"
    if ( num_restored == num_considered ) {
        status="OK"
    }
    printf( "%8s %8s %8s %s\n", 
        status, 
        num_restored, 
        num_considered, 
        logfile )
}

'

done
