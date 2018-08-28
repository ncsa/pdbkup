###
### ARCHIVE RELATED FUNCTIONS
###


function get_last_snapdir {
    # PARAMS:
    #   ini_key = String - (REQUIRED) - key from ini file from DIRS section
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    key=$1
    [[ -z "$key" ]] && die "get_last_snapdir; got empty key"
    #snapbase=$( get_snap_base $key )
    local snapbase_ref="INI__${key}__SNAPDIR"
    local snapbase="${!snapbase_ref}"
    [[ -d "$snapbase" ]] || die "Cant find snapbase '$snapbase'"
    find "$snapbase" -mindepth 1 -maxdepth 1 | sort -r | head -1
}


function get_last_bkupdir {
    # PARAMS:
    #   ini_key = String - (REQUIRED) - key from ini file from DIRS section
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    local key=$1
    [[ -z "$key" ]] && die "get_last_bkupdir; got empty key"
    local infodir=$INI__GENERAL__INFODIR/$key
    [[ -d $infodir ]] || return
    find $infodir -mindepth 1 -maxdepth 1 -type d \
    | sort -r \
    | head -1
}


function get_bkupdirs() {
    [[ $DEBUG -gt 0 ]] && set -x
    local key="$1"
    [[ -z "$key" ]] && die "get_bkupdirs; missing or empty key"
    dirpath="$INI__GENERAL__INFODIR/$key"
    [[ -d $dirpath ]] || return
    find "$dirpath" -mindepth 1 -maxdepth 1 -type d \
    | sort
}


function get_old_bkupdirs() {
    [[ $DEBUG -gt 0 ]] && set -x
    local key="$1"
    [[ -z "$key" ]] && die "get_bkupdirs; missing or empty key"
    dirpath=$( readlink -e "$INI__GENERAL__ANNALDIR/${INI__GENERAL__INFODIR}/$key" )
    [[ -d "$dirpath" ]] || return
    find "$dirpath" -mindepth 1 -maxdepth 1 -type d \
    | sort
}


function timestamp2datetime() {
    # Input: String - "unix timestamp"
    # Output: String - "date time"
    [[ $DEBUG -gt 0 ]] && set -x
    [[ $# -lt 1 ]] && die "timestamp2datetime: Missing timestamp"
    echo "$1" | awk '{dt=strftime( "%F %T", $1 ); print dt}'
}


function snapdir2timestamp {
    # PARAMS:
    #   snapdir = String - (REQUIRED) - snapdir absolute path
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    local snapdir=$1
    [[ -z "$snapdir" ]] && die "snapdir2timestamp; snapdir cant be empty"
    #local ts_str=$( basename $snapdir \
    #| tr '_' ' ' | tr -cd ' 0-9-' | xargs -I {} date -d {} '+%s' )
    ts_str=$( basename $snapdir \
    | tr '_' ' ' | tr '-' ' ' | tr -cd ' 0-9-' | xargs -I {} date -d {} '+%s' )
    local rc=$?
    [[ $rc -ne 0 ]] && die "Unable to get date from snapdir '$snapdir'"
    echo "$ts_str"
}


function timestamp2snapdir {
    # PARAMS:
    #   ini_key = String - (REQUIRED) - key from ini file from DIRS section
    #   timestamp = String - (REQUIRED) - unix epoch time
    # OUTPUT:
    #   absolute path to matching snapdir
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    local key=$1
    local ts=$2
    [[ -z "$key" ]] && die "timestamp2snapdir; key cant be empty"
    [[ -z "$ts" ]] && die "timestamp2snapdir; timestamp cant be empty"
    #local snapbase=$( get_snap_base $key )
    local snapbase_ref="INI__${key}__SNAPDIR"
    local snapbase="${!snapbase_ref}"
    local date_fmt="${INI__DEFAULTS__SNAPDIR_DATE_FORMAT}"
    local refname=INI__${key}__SNAPDIR_DATE_FORMAT
    [[ -n "${!refname}" ]] && date_fmt="${!refname}"
    local datestr=$( date -d @$ts "+$date_fmt" )
    find $snapbase -maxdepth 1 -type d -name "*$datestr"
}


function bkupinfodir2key_ts() {
    # PARAMS:
    #   <STDIN> = String - (REQUIRED) - absolute path to backupinfodir
    # OUTPUT:
    #   String - space separated string of KEY TIMESTAMP
    awk '{c=split( $1, parts, "/"); ts=parts[c]; key=parts[c-1]; print key,ts}'
}


function mk_datadirs {
    # PARAMS:
    #   dir = String - (REQUIRED) - directory to populate
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    local dir="$1"
    [[ -d "$dir" ]] || die "mk_datadirs: dir '$dir' doesn't exist or is not a directory"
    local varname
    local val
    local newpath
    for varname in ${INI__ALL_VARS}; do
        echo $varname | grep -q 'WORKDIR\|SRCDIR\|ENDDIR\|ERRDIR' || continue
        val=${!varname}
        newpath=$val
        # prepend $dir for non-absolute path
        if [[ $val != /* ]]; then
            newpath="$dir/$val"
        fi
        [[ -d "$newpath" ]] || mkdir "$newpath"
        [[ $? -ne 0 ]] && die "Problem making datadir '$newpath'"
    done
}


function filename2key_ts() {
    # Attempt to extract DIRKEY and TIMESTAMP from a filename
    # Can take multiple files as input
    #
    # PARAMS:
    #   fullpath - String - path to file
    #
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    [[ $# -lt 1 ]] && die "filename2key_ts: Expected >=1 parameter, got '$#'"
    for fullpath; do
        basename "$fullpath" \
        | cut -d '.' -f 1 \
        | awk -F '_INFO' '{a=match($1,/_[0-9]+/); k=substr($1,0,a-1); t=substr($1,a+1); print k,t}'
    done
}


function gatekeeper_fn() {
    # Print the full path for a gatekeeper file for this node
    echo "$INI__GENERAL__DATADIR/$INI__PARALLEL__WORKDIR/gatekeeper.$(hostname)"
}


function get_last_full_timestamp {
    # PARAMS:
    #   ini_key = String - (REQUIRED) - key from ini file from DIRS section
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    local key=$1
    [[ -z "$key" ]] && die "get_last_bkupdir; got empty key"
    local infodir=$INI__GENERAL__INFODIR/$key
    [[ -d $infodir ]] || return
    local last_full_dirname=$( find $infodir -type f -name 'allfileslist.FULL' \
    | sort \
    | tail -1 \
    | xargs -r -n1 dirname )
    [[ -z "$last_full_dirname" ]] && return
    local foo last_full_timestamp
    read foo last_full_timestamp <<< $( bkupinfodir2key_ts <<< "$last_full_dirname" )
    echo $last_full_timestamp
}
