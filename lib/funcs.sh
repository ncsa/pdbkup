###
### COMMON FUNCTIONS
###

function die {
    echo "FATAL ERROR: $*"
    exit 99
}


function clean_exit {
    echo "$*"
    exit 0
}


function debug {
    [[ $BKUP_DEBUG -eq 1 ]] || return
    echo "#DEBUG# $*"
}

function log {
    [[ $BKUP_VERBOSE -eq 1 ]] || return
    echo "#INFO# $*"
}

function warn() {
    echo "#WARN# $*"
}


function dumpvars {
    [[ $BKUP_DEBUG -eq 1 ]] || return
    set +x
    for name; do
        echo "#DEBUG# $name ... ${!name}"
    done
}


function dump_ini {
    [[ $BKUP_DEBUG -eq 1 ]] || return
    set +x #disable verbosity
    local PFX=INI
    local vars_ref="${PFX}__ALL_VARS"
    local sections_ref="${PFX}__ALL_SECTIONS"
    local ALL_VARS=( ${!vars_ref} )
    local ALL_SECTIONS=( ${!sections_ref} )
    [[ -n "$1" ]] && PFX="$1"
    echo "===BEGIN DUMP_INI==="
    echo "------------"
    echo "ALL_SECTIONS"
    echo "------------"
    local v
    for v in "${ALL_SECTIONS[@]}"; do
        echo $v
    done
    echo "--------"
    echo "ALL_VARS"
    echo "--------"
    local var
    for var in "${ALL_VARS[@]}"; do
      echo $var ... ${!var}
    done
    echo "===END DUMP_INI==="
    set -x #re-enable verbosity
}



###
### INI FILE RELATED FUNCTIONS
###

#
# PARAMS:
#   fn  = String - (REQUIRED) - filename
#   sec = String - (REQUIRED) - section
#   key = String - (REQUIRED) - key
#   val = String - (REQUIRED) - val
function update_ini {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    [[ $# -ne 4 ]] && die "update_ini: Expected 4 parameters, got '$#'"
    local fn="$1"
    local sec="$2"
    local key="$3"
    local val="$4"
    [[ -f "$fn" ]] || touch "$fn"
    [[ -w "$fn" ]] || die "update_ini: file '$fn' is not writeable"
    $BKUP_BASE/lib/crudini --set "$fn" "$sec" "$key" "$val"
}


#
# function get_all_vars_matching_prefix {
#
# PARAMS:
#   pfx  = String - (REQUIRED) - prefix to match
#   keep = Int    - (OPTIONAL) - keep prefix (0 - Default) or strip (1)
function get_all_vars_matching_prefix {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    [[ $# -ne 2 ]] && die "update_ini: Expected 2 parameters, got '$#'"
    local pfx=$1
    local keep=$2
    [[ -z "$pfx" ]] && die "get_all_vars_matching_prefix; got empty prefix"
    ( set -o posix ; set ) \
    | grep "^$pfx" \
    | cut -d '=' -f 1 \
    | ( [[ ${keep} -gt 0 ]] && sed -e "s/$pfx//" || cat )
}



###
### ARCHIVE RELATED FUNCTIONS
###

#
# function get_snap_base {
#
# PARAMS:
#   ini_key = String - (REQUIRED) - key from ini file from DIRS section
function get_snap_base {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    local key=$1
    [[ -z "$key" ]] && die "get_snap_base; got empty key"
    local snapdn="${INI__DEFAULTS__SNAPDIR}"
    local refname=INI__${key}__SNAPDIR
    [[ -n "${!refname}" ]] && snapdn="${!refname}"
    local pathref=INI__DIRS__$key
    local snapdir=${!pathref}/${snapdn}
    [[ -d $snapdir ]] && echo $snapdir
}


#
# function get_last_snapdir {
#
# PARAMS:
#   ini_key = String - (REQUIRED) - key from ini file from DIRS section
function get_last_snapdir {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    key=$1
    [[ -z "$key" ]] && die "get_last_snapdir; got empty key"
    snapbase=$( get_snap_base $key )
    [[ -d "$snapbase" ]] || die "Cant find snapbase '$snapbase'"
    find "$snapbase" -mindepth 1 -maxdepth 1 | sort -r | head -1
}

#
# function get_last_bkupdir {
#
# PARAMS:
#   ini_key = String - (REQUIRED) - key from ini file from DIRS section
function get_last_bkupdir {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    local key=$1
    local infodir=$INI__GENERAL__INFODIR/$key
    [[ -z "$key" ]] && die "get_last_bkupdir; got empty key"
    [[ -d $infodir ]] || return
    find $infodir -mindepth 2 -maxdepth 2 -type f \
        -name 'filelist.filelist' -printf '%h' \
    | sort -r \
    | head -1
}


#
# function snapdir2timestamp {
#
# PARAMS:
#   snapdir = String - (REQUIRED) - snapdir absolute path
function snapdir2timestamp {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    local snapdir=$1
    [[ -z "$snapdir" ]] && die "snapdir2timestamp; snapdir cant be empty"
    local ts_str=$( basename $snapdir \
    | tr '_' ' ' | tr -cd ' 0-9-' | xargs -I {} date -d {} '+%s' )
    local rc=$?
    [[ $rc -ne 0 ]] && die "Unable to get date from snapdir '$snapdir'"
    echo "$ts_str"
}


#
# function timestamp2snapdir {
#
# PARAMS:
#   ini_key = String - (REQUIRED) - key from ini file from DIRS section
#   timestamp = String - (REQUIRED) - unix epoch time
# OUTPUT:
#   absolute path to matching snapdir
function timestamp2snapdir {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    local key=$1
    local ts=$2
    [[ -z "$key" ]] && die "timestamp2snapdir; key cant be empty"
    [[ -z "$ts" ]] && die "timestamp2snapdir; timestamp cant be empty"
    local snapbase=$( get_snap_base $key )
    local date_fmt="${INI__DEFAULTS__SNAPDIR_DATE_FORMAT}"
    local refname=INI__${key}__SNAPDIR_DATE_FORMAT
    [[ -n "${!refname}" ]] && date_fmt="${!refname}"
    local datestr=$( date -d @$ts "+$date_fmt" )
    find $snapbase -maxdepth 1 -type d -name "*$datestr"
}


#
# function bkupinfodir2key_ts() {
#
# PARAMS:
#   path = String - (REQUIRED) - absolute path to backupinfodir
# OUTPUT:
#   String - space separated string of KEY TIMESTAMP
function bkupinfodir2key_ts() {
    awk '{c=split( $1, parts, "/"); ts=parts[c]; key=parts[c-1]; print key,ts}'
}


#
# Fill out workflow dirs for a new work area
#
# PARAMS:
#   dir = String - (REQUIRED) - directory to populate
function mk_datadirs {
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


#
# Attempt to extract DIRKEY and TIMESTAMP from a filename
# Can take multiple files as input
#
# PARAMS:
#   fullpath - String - path to file
#
function filename2key_ts() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    [[ $# -lt 1 ]] && die "filename2key_ts: Expected >=1 parameter, got '$#'"
    for fullpath; do
        basename "$fullpath" \
        | cut -d '.' -f 1 \
        | awk -F '_' '{print $1,$2}'
    done
}




###
### GNU PARALLEL RELATED FUNCTIONS
###


#
# Build parallel DBURL
#
# (see also: man sql)
# vendor://[[user][:password]@][host][:port]/[database]
#
# NOTE: This does not include a table name
#
# PARAMS:
#   pfx - String (optional) - prefix to be prepended to DBNAME
#                             (useful for sqlite3 and csv to make unique files)
#   
function mk_dburl {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    [[ $# -ne 1 ]] && die "mk_dburl: Expected 1 parameter, got '$#'"
    local pfx=$1
    local p=${INI__PARALLEL__DB_PASS:+:$INI__PARALLEL__DB_PASS}
    local u=${INI__PARALLEL__DB_USER:+$INI__PARALLEL__DB_USER$p@}
    local db=$pfx$INI__PARALLEL__DB_DBNAME
    case $INI__PARALLEL__DB_VENDOR in
        sqlite3|csv)
            # db is a filename
            db=$INI__GENERAL__DATADIR/$INI__PARALLEL__WORKDIR/${pfx}.$INI__PARALLEL__DB_DBNAME
            # replace / with octal code
            db=${db//\//%2F}
            ;;
    esac
    echo ${INI__PARALLEL__DB_VENDOR}://\
$u\
$INI__PARALLEL__DB_HOST\
${INI__PARALLEL__DB_PORT:+:$INI__PARALLEL__DB_PORT}\
/$db
}


#
# Convert a dburl to a filename
#
# PARAMS:
#   dburl - String - dburl formatted appropriatly for GNU SQL, same as output from mk_dburl
# OUTPUT:
#   String - full path to filename (for sqlite3 and csv db types), null otherwise
#
function dburl2filename() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    [[ $# -ne 1 ]] && die "mk_dburl: Expected 1 parameter, got '$#'"
    if [[ "$dburl" != sqlite3* ]] && [[ "$dburl" != csv* ]]; then
        return
    fi
    echo "$dburl" \
    | awk -F '/' '{
        gsub(/%2[Ff]/, "/", $NF)
        print $NF }
    '
}


###
### Build parallel DBURLTABLE
###
### (see also: man parallel)
### vendor://[[user][:password]@][host][:port]/[database[/table]
###
### PARAMS:
###   dburl - String - the DBURL part from mk_dburl
###   pfx   - String (optional) - prefix to be prepended to table name
###   
##function mk_dburltable {
##    [[ $BKUP_DEBUG -gt 0 ]] && set -x
##    local dburl=$1
##    local pfx=$2
##    [[ -z "$dburl" ]] && die "mk_dburltable: missing dburl parameter"
##    echo ${dburl}${INI__PARALLEL__DB_TABLE:+/$pfx$INI__PARALLEL__DB_TABLE}
##}


#
# Get list of sqlworker filenames
# 
# PARAMS: None
#
function ls_sqlworker_cmdfiles() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    parallel_workdir="$INI__GENERAL__DATADIR/$INI__PARALLEL__WORKDIR"
    find "$parallel_workdir" -name '*.sqlworker.cmd'
}


#
# Extract DBURL from sqlworker cmdfile
#
# PARAMS:
#   sqlworkercmdfile - String - full path to sqlworker cmdfile
#
function dburl_from_sqlworkercmdfile() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    [[ $# -lt 1 ]] && die "dburl_from_sqlworkercmdfile: Expected 1 parameter, got $#"
    for fn; do
        grep '^QNAME=' "$fn" \
        | head -1 \
        | cut -d '=' -f 2 \
        | tr -d '"'
    done
}


#
# Count of rows with exit val matching input value
#
# PARAMS:
#   dburl  - String - dburl from mk_dburl suitable for use with GNU sql command
#   value  - Integer - value for which to match with exitval in DB
#   compar - String (OPTIONAL) - numerical comparison operator
#                                (one of =, <, >, <=, >=)
#                                Default: "="
#
function db_exitval_count() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    [[ $# -lt 2 ]] && die "db_exitval_count: Expected 2 parameters, got $#"
    local dburl="$1"
    local exitval=$( echo "$2" | tr -cd '[0-9-]' )
    local compar=$( echo "$3" | tr -cd '[=<>]' )
    [[ ${#compar} -lt 1 ]] && compar='='
    local SQL="select count(*) 
               from $INI__PARALLEL__DB_TABLE 
               where Exitval${compar}$exitval;"
    sql -n "$dburl" "$SQL"
}


#
# Print number of tasks that are ready to run (not started, not reserved)
#
# PARAMS:
#   dburl  - String - dburl from mk_dburl suitable for use with GNU sql command
#
function num_ready_tasks() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    [[ $# -ne 1 ]] && die "num_ready_tasks: Expected 1 parameter, got $#"
    local dburl="$1"
    db_exitval_count "$dburl" -1000
}


#
# Print number of tasks that are already started
#
# PARAMS:
#   dburl  - String - dburl from mk_dburl suitable for use with GNU sql command
#
function num_active_tasks() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    [[ $# -ne 1 ]] && die "num_active_tasks: Expected 1 parameter, got $#"
    local dburl="$1"
    db_exitval_count "$dburl" -1220
}


#
# Print number of tasks that completed successfully
#
# PARAMS:
#   dburl  - String - dburl from mk_dburl suitable for use with GNU sql command
#
function num_successful_tasks() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    [[ $# -ne 1 ]] && die "num_successful_tasks: Expected 1 parameter, got $#"
    local dburl="$1"
    db_exitval_count "$dburl" 0
}


#
# Print number of tasks that failed
#
# PARAMS:
#   dburl  - String - dburl from mk_dburl suitable for use with GNU sql command
#
function num_failed_tasks() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    [[ $# -ne 1 ]] && die "num_failed_tasks: Expected 1 parameter, got $#"
    local dburl="$1"
    db_exitval_count "$dburl" 0 ">"
}


#
# Return the absolute path to the sqlworker.cmd file 
# for the currently active queue
# or the next queue (based on oldest mtime)
# 
# PARAMS: None
#
function next_worker_cmdfile() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    local parallel_workdir="$INI__GENERAL__DATADIR/$INI__PARALLEL__WORKDIR"
    # get list of worker files
    local -a workerfiles=( $( find "$parallel_workdir" \
        -maxdepth 1 -type f -name '*.sqlworker.cmd' \
        -printf '%T@\0%p\n' \
        | sort -n \
        | cut -d '' -f 2
        ) )
    #[[ $BKUP_DEBUG -eq 1 ]] && printf '%s\n' "${workerfiles[@]}"

    # get list of queues (DBURL's)
#    local -a workerqueues=( $( for wf in "${workerfiles[@]}"; do 
#        dburl_from_sqlworkercmdfile "$wf"; done ) )
    local -a workerqueues=( $( for wf in "${workerfiles[@]}"; do 
        dburl_from_sqlworkercmdfile "$wf"; done ) )
    #[[ $BKUP_DEBUG -eq 1 ]] && printf '%s\n' "${workerqueues[@]}"

    # List of queues with one or more tasks ready to start
    local num_tasks_ready i dburl seqstop
    local -a ready_q_indices
    let "seqstop = ${#workerqueues[*]}-1"
    for i in $( seq 0 $seqstop ) ; do 
        dburl=${workerqueues[$i]}
        num_tasks_ready=$( num_ready_tasks "$dburl" )
        [[ $num_tasks_ready -gt 0 ]] && ready_q_indices+=( $i )
    done
    #[[ $BKUP_DEBUG -eq 1 ]] && printf 'Num Ready Queues: %d\n' "${#ready_q_indices[*]}"
    #[[ $BKUP_DEBUG -eq 1 ]] && printf 'Ready Queue Indicies:\n'
    #[[ $BKUP_DEBUG -eq 1 ]] && printf '\t%d\n' "${ready_q_indices[@]}"

    # List of queues (having tasks ready to start) with one or more tasks already started
    local num_tasks_started
    local -a started_q_indicies
    for i in "${ready_q_indices[@]}" ; do
        dburl="${workerqueues[$i]}"
        num_tasks_started=$( num_active_tasks "$dburl" )
        [[ $num_tasks_started -gt 0 ]] && started_q_indicies+=( $i )
    done
    #[[ $BKUP_DEBUG -eq 1 ]] && printf 'Num Started Queues: %d\n' "${#started_q_indices[*]}"
    #[[ $BKUP_DEBUG -eq 1 ]] && printf 'Started Queue Indices:\n'
    #[[ $BKUP_DEBUG -eq 1 ]] && printf '\t%d\n' "${started_q_indices[@]}"

    # Try to echo first started queue, or first ready queue
    if [[ "${#started_q_indicies[*]}" -gt 0 ]] ; then
        i=${started_q_indicies[0]}
        echo "${workerfiles[$i]}"
    elif [[ "${#ready_q_indices[*]}" -gt 0 ]] ; then
        i=${ready_q_indices[0]}
        echo "${workerfiles[$i]}"
    fi
}




###
### TRANSFER RELATED FUNCTIONS
###


#
# Return sudo cmd string
#
function gosudo() {
    echo "/usr/bin/sudo -u ${INI__GLOBUS__USERNAME} --"
}


#
# Check existing proxy has >12 hours remaining 
# or make a new proxy valid for 24 hours
# PARAMS:
#   min_hours - Integer - (Optional) refresh proxy if less than X hours remain
#   refresh_hours - Integer - (Optional) make new proxy valid for X hours
# OUTPUT:
#   None
#
function check_or_update_proxy() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    local min_hours=$1
    local refresh_hours=$2
    [[ -z $min_hours ]] && min_hours=12
    [[ -z $refresh_hours ]] && refresh_hours=24
    &>/dev/null $(gosudo) grid-proxy-info -e -h $min_hours ||
    &>/dev/null $(gosudo) grid-proxy-init -hours $refresh_hours ||
    die 'check_or_update_proxy: Error during proxy-init'
    sleep 1 #let the proxy file get created on the system
    &>/dev/null $(gosudo) grid-proxy-info -e -h $min_hours ||
    die 'check_or_update_proxy: Error validating proxy'
}

#
# Wrapper for globus ssh cli
#
function gossh() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    check_or_update_proxy
    $(gosudo) gsissh cli.globusonline.org $* <&0
}


#
# Ensure endpoint is activated
# PARAMS:
#   endopintname - String - a valid globus endpoint name
# OUTPUT:
#   None
#
function endpoint_activate() {
    gossh endpoint-activate -g "$1" ||
    die "Unable to activte endpoint '$1'"
}


#
# Remove duplicate slashes AND urlencode non-alphanumeric characters
# PARAMS:
#   path - String - filepath, does not need to be a valid local path
# OUTPUT:
#   String
#  
function urlencode() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    echo "$1" | sed 's#//*#/#g' | xargs -d '\n' urlencode
}
