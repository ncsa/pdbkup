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
