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

function update_ini {
    # PARAMS:
    #   fn  = String - (REQUIRED) - filename
    #   sec = String - (REQUIRED) - section
    #   key = String - (REQUIRED) - key
    #   val = String - (REQUIRED) - val
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    [[ $# -ne 4 ]] && die "update_ini: Expected 4 parameters, got '$#'"
    local fn="$1"
    local sec="$2"
    local key="$3"
    local val="$4"
    [[ -f "$fn" ]] || touch "$fn"
    [[ -w "$fn" ]] || die "update_ini: file '$fn' is not writeable"
    $PDBKUP_BASE/lib/crudini --set "$fn" "$sec" "$key" "$val"
}


function get_all_vars_matching_prefix {
    # PARAMS:
    #   pfx  = String - (REQUIRED) - prefix to match
    #   keep = Int    - (OPTIONAL) - keep prefix (0 - Default) or strip (1)
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


function safe_varname() {
    # Create a variable name that is safe for export
    # Useful to create a prefix to be passed to the function "read_ini"
    # PARAMS:
    #   pfx - String - prefix to attach to beginning of cleaned up varname
    #   val - String - value to clean up for varname
    #
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    echo -n "$1$2" | tr -cd 'A-Za-z0-9_'
}



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
    find $infodir -mindepth 2 -maxdepth 2 -type f \
        -name 'filelist.filelist' -printf '%h' \
    | sort -r \
    | head -1
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
    local ts_str=$( basename $snapdir \
    | tr '_' ' ' | tr -cd ' 0-9-' | xargs -I {} date -d {} '+%s' )
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
        | awk -F '_' '{print $1,$2}'
    done
}


function gatekeeper_fn() {
    # Print the full path for a gatekeeper file for this node
    echo "$INI__GENERAL__DATADIR/$INI__PARALLEL__WORKDIR}/gatekeeper.$(hostname)"
}


###
### GNU PARALLEL RELATED FUNCTIONS
###


function mk_dburl {
    # Build parallel DBURL
    # (see also: man sql)
    # vendor://[[user][:password]@][host][:port]/[database]
    # NOTE: This does not include a table name
    #
    # PARAMS:
    #   pfx - String (optional) - prefix to be prepended to DBNAME
    #                             (useful for sqlite3 and csv to make unique files)
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


function dburl2filename() {
    # Convert a dburl to a filename
    #
    # PARAMS:
    #   dburl - String - dburl formatted appropriatly for GNU SQL, same as output from mk_dburl
    # OUTPUT:
    #   String - full path to filename (for sqlite3 and csv db types), null otherwise
    #
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


function ls_sqlworker_cmdfiles() {
    # Get list of sqlworker filenames
    # 
    # PARAMS: None
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    parallel_workdir="$INI__GENERAL__DATADIR/$INI__PARALLEL__WORKDIR"
    find "$parallel_workdir" -name '*.sqlworker.cmd'
}


function dburl_from_sqlworkercmdfile() {
    # Extract DBURL from sqlworker cmdfile
    #
    # PARAMS:
    #   sqlworkercmdfile - String - full path to sqlworker cmdfile
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    [[ $# -lt 1 ]] && die "dburl_from_sqlworkercmdfile: Expected 1 parameter, got $#"
    for fn; do
        grep '^QNAME=' "$fn" \
        | head -1 \
        | cut -d '=' -f 2 \
        | tr -d '"'
    done
}


function db_exitval_count() {
    # Count of rows with exit val matching input value
    #
    # PARAMS:
    #   dburl  - String - dburl from mk_dburl suitable for use with GNU sql command
    #   value  - Integer - value for which to match with exitval in DB
    #   compar - String (OPTIONAL) - numerical comparison operator
    #                                (one of =, <, >, <=, >=)
    #                                Default: "="
    #
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


function num_ready_tasks() {
    # Print number of tasks that are ready to run (not started, not reserved)
    #
    # PARAMS:
    #   dburl  - String - dburl from mk_dburl suitable for use with GNU sql command
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    [[ $# -ne 1 ]] && die "num_ready_tasks: Expected 1 parameter, got $#"
    local dburl="$1"
    db_exitval_count "$dburl" -1000
}


function num_active_tasks() {
    # Print number of tasks that are already started
    #
    # PARAMS:
    #   dburl  - String - dburl from mk_dburl suitable for use with GNU sql command
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    [[ $# -ne 1 ]] && die "num_active_tasks: Expected 1 parameter, got $#"
    local dburl="$1"
    db_exitval_count "$dburl" -1220
}


function num_successful_tasks() {
    # Print number of tasks that completed successfully
    #
    # PARAMS:
    #   dburl  - String - dburl from mk_dburl suitable for use with GNU sql command
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    [[ $# -ne 1 ]] && die "num_successful_tasks: Expected 1 parameter, got $#"
    local dburl="$1"
    db_exitval_count "$dburl" 0
}


function num_failed_tasks() {
    # Print number of tasks that failed
    #
    # PARAMS:
    #   dburl  - String - dburl from mk_dburl suitable for use with GNU sql command
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    [[ $# -ne 1 ]] && die "num_failed_tasks: Expected 1 parameter, got $#"
    local dburl="$1"
    db_exitval_count "$dburl" 0 ">"
}


function next_worker_cmdfile() {
    # Return the absolute path to the sqlworker.cmd file 
    # for the currently active queue
    # or the next queue (based on oldest mtime)
    # 
    # PARAMS: None
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


function gosudo() {
    # Return sudo cmd string
    echo "/usr/bin/sudo -u ${INI__GLOBUS__USERNAME} --"
}


function check_or_update_proxy() {
    # Check existing proxy has >24 hours remaining 
    # or make a new proxy valid for 264 hours (11 days)
    # PARAMS:
    #   min_hours - Integer - (Optional) refresh proxy if less than X hours remain
    #   refresh_hours - Integer - (Optional) make new proxy valid for X hours
    # OUTPUT:
    #   None
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    local min_hours=$1
    local refresh_hours=$2
    [[ -z $min_hours ]] && min_hours=24
    [[ -z $refresh_hours ]] && refresh_hours=264
    &>/dev/null $(gosudo) grid-proxy-info -e -h $min_hours ||
    &>/dev/null $(gosudo) grid-proxy-init -hours $refresh_hours ||
    die 'check_or_update_proxy: Error during proxy-init'
    sleep 1 #let the proxy file get created on the system
    &>/dev/null $(gosudo) grid-proxy-info -e -h $min_hours ||
    die 'check_or_update_proxy: Error validating proxy'
}


function endpoint_activate() {
    # Ensure endpoint is activated
    # PARAMS:
    #   endpoint_id - String - a valid globus endpoint name
    #   min_hours - Integer - (Optional) refresh proxy if less than X hours remain
    #   refresh_hours - Integer - (Optional) make new proxy valid for X hours
    # OUTPUT:
    #   None
    #
    # TODO - replce with Python CLI (when certificate support is available)
    local endpoint_id=$1
    local min_hours=$2
    local refresh_hours=$3
    [[ -z $min_hours ]] && min_hours=24
    [[ -z $refresh_hours ]] && refresh_hours=264
    check_or_update_proxy $min_hours $refresh_hours
    local min_secs=$( bc <<< "$min_hours * 3600" )
    local proxy_file=$( $(gosudo) grid-proxy-info -path )
    # check for current activation
    local safe_endpoint_id=$( safe_varname "EPcheck1" "$endpoint_id" )
    local tmpfn=$( ${INI__GLOBUS__CLI} endpoint show -F json $endpoint_id \
    | $PDBKUP_BASE/bin/json2ini.py )
    read_ini -p $safe_endpoint_id $tmpfn
    local refname=${safe_endpoint_id}__JSON__expires_in
    if [[ ${!refname} -lt $min_secs ]]; then
        # endpoint activation is expired or nearing expiration, renew it
        ${INI__GLOBUS__CLI} endpoint activate \
            --proxy-lifetime $refresh_hours \
            --delegate-proxy "$proxy_file" \
            $endpoint_id \
            || die "Unable to activte endpoint '$endpoint_id'"
    fi
}


function urlencode() {
    # Remove duplicate slashes AND urlencode non-alphanumeric characters
    # PARAMS:
    #   path - String - filepath, does not need to be a valid local path
    # OUTPUT:
    #   String
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    echo "$1" | sed 's#//*#/#g' | xargs -d '\n' urlencode
}
