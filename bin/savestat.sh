#!/bin/bash

BKUP_BASE=/gpfs/fs0/DR

BKUP_DEBUG=0     #debug messages
BKUP_VERBOSE=0   #info messages
while getopts ":dv" opt; do
    case $opt in
    d) BKUP_DEBUG=1; BKUP_VERBOSE=1;;
    v) BKUP_VERBOSE=1;;
    esac
done
shift $((OPTIND-1))

[[ $BKUP_DEBUG -gt 0 ]] && set -x

CRUDINI="$BKUP_BASE/lib/crudini"

[[ $# -ne 4 ]] && die "savestat: Expected 4 parameters, got '$#'";
fn="$1";
sec="$2";
key="$3";
val="$4";
[[ -f "$fn" ]] || touch "$fn";
[[ -w "$fn" ]] || die "savestat: file '$fn' is not writeable";

[[ $BKUP_VERBOSE -gt 0 ]] && set -x

"$CRUDINI" --set "$fn" "$sec" "$key" "$val"
