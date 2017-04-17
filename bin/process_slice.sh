#!/usr/bin/bash

###
# INPUT
#   slice_fn
#   slice_num
#   info_fn
#   dar_enddir
###

die() {
    echo "FATAL ERROR: $*" >&2
    exit 99
}

# CHECK INPUT PARAMS
[[ $# -ne 4 ]] && die "Expected 4 parameters, got '$#'"
slice_fn="$1"
slice_num=$2
info_fn="$3"
dar_enddir="$4"
[[ -f "$slice_fn" ]] || die "Cant find slice file '$slice_fn'"
[[ $slice_num -lt 1 ]] && die "Invalid slice number '$slice_num'"
[[ -f "$info_fn" ]] || die "Cant find info file '$info_fn'"
[[ -d "$dar_enddir" ]] || die "Cant find dar_enddir or is not a directory '$dar_enddir'"

# GET A SINGLE VALUE FROM THE INI FILE
get_ini() {
    crudini --get "$info_fn" 'DAR' "$1"
}

# SAVE A SINGLE KEY / VALUE PAIR TO THE INI FILE
put_ini() {
    crudini --set "$info_fn" 'DAR' "$1" "$2"
}

# GET CURRENT TIME AS SLICE ENDTIME
slice_endtime=$( date "+%s" )

# GET SLICE STARTTIME
# If slice num is 1, use dar start time
if [[ $slice_num -eq 1 ]]; then
    slice_starttime=$( get_ini 'START' )
# Otherwise, use previous slice time
else
    prev_slice_num=$( bc <<< "$slice_num - 1" )
    slice_starttime=$( get_ini "SLICE_${prev_slice_num}_END" )
fi

# CALCULATE RATE IN BYTES PER SECOND
slice_size=$( stat -c '%s' "$slice_fn" )
rate=$( bc <<< "scale=2; $slice_size / ( $slice_endtime - $slice_starttime )" )

# SAVE INFO
put_ini "SLICE_${slice_num}_FILE" "$( basename $slice_fn )"
put_ini "SLICE_${slice_num}_SIZE" "$slice_size"
put_ini "SLICE_${slice_num}_START" $slice_starttime
put_ini "SLICE_${slice_num}_END" $slice_endtime
put_ini "SLICE_${slice_num}_RATE_BPS" $rate

# MOVE SLICE TO DAR END DIR
mv "$slice_fn" "$dar_enddir"
