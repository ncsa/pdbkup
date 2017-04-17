#!/bin/bash

BKUP_BASE=/gpfs/fs0/DR

DEBUG=0     #debug messages
VERBOSE=0   #info messages
while getopts ":dv" opt; do
    case $opt in
    d) DEBUG=1; VERBOSE=1;;
    v) VERBOSE=1;;
    esac
done
shift $((OPTIND-1))

export BKUP_DEBUG=$DEBUG
export BKUP_VERBOSE=$VERBOSE
export BKUP_BASE

cd $BKUP_BASE
source lib/funcs.sh
source lib/read_ini.sh

read_ini conf/settings.ini

#
# Get the filename for each filelist associated with a globus transfer
# The filelist lists all source files that are included in the transfer
#
function globus_task_files() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    find ${INI__GENERAL__DATADIR}/${INI__TXFR__WORKDIR_OUTBOUND} \
        -name '*.filelist'
}


#
# Return task ids in mtime sorted order with OLDEST first and NEWEST last
# PARAMS: none
#
function globus_taskids() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    globus_task_files \
    | while read; do 
        globus_taskfile2taskid $REPLY
    done
}


#
# Return task ids ONLY for completed transfers
# PARAMS: none
#
function is_globus_task_complete() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    local taskid="$1"
    local retval=1
    local simple_tid refname taskstatus
    go_task_details $taskid
    simple_tid=$( safe_varname $taskid )
    refname="${simple_tid}__status";
    taskstatus="${!refname}"
    case "$taskstatus" in
        SUCCEEDED|FAILED) retval=0
            ;;
    esac
    return $retval
}


#
# Return the Globus TaskID for the given task file
# PARAMS:
#    String - path to globus task file
#
function globus_taskfile2taskid() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    basename "$1" .filelist
}


#
# Calculate sum (in bytes) of files listed in filelist
#
function filelist2total_bytes() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    srcfn="$1"
    awk '{split($1, parts, /\//); print parts[2]}' $srcfn \
    | xargs urlencode -d \
    | xargs stat -c '%s' \
    | awk 'BEGIN {s=0}; {s+=$1}; END {print s}'
}


#
# Helper function to create variables for export
#
function safe_varname() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    echo -n "taskid$1" | tr -cd 'A-Za-z0-9_'
}


#
# Define (exported) varibles for each stat of the given Globus TaskID
# Variable names are <TASKID>__<varname>
# where <TASKID> is the Globus TaskID
# and <varname> is the key name as returned by "details -Okv" 
# from the globus ssh CLI
#
# PARAMS:
#   taskid - String - Globus TaskID
#
function go_task_details() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    local taskid=$1
    local keys=( bytes_checked
                 bytes_transferred
                 verify_checksum
                 'command'
                 completion_code
                 completion_time
                 encrypt_data
                 deadline
                 delete
                 dst_endpoint
                 dst_endpoint_name
                 dst_file
                 directories
                 mbits_sec
                 endpoint
                 endpoint_name
                 expansions
                 faults
                 files
                 files_skipped
                 files_transferred
                 force
                 is_paused
                 label
                 path
                 recursive
                 request_time
                 src_endpoint
                 src_endpoint_name
                 src_file
                 status
                 sync_level
                 taskid
                 task_type
                 tasks_canceled
                 tasks_expired
                 tasks_failed
                 tasks_pending
                 tasks_retrying
                 tasks_successful
                 total_tasks )
    local keys_csv=$( ( IFS=,; echo "${keys[*]}" ) )
    local taskvarname=$( safe_varname $taskid )
    local tmpfn=$( mktemp )
    gossh details -O kv -f $keys_csv $taskid \
    | xargs -n1 urlencode -d \
    | sed -e 's/=/="/; s/$/"/' \
    >$tmpfn
    read_ini -p ${taskvarname} $tmpfn
    rm -f $tmpfn
}


#
# Move source files to the local purge area for successful transfers
# otherwise, move the source files to the error directory if transfer failed
#
# PARAMS:
#   taskid - String - Globus TaskID
#
function cleanup_txfr_src_files () {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    local taskid=$1
    local ok_dir="${INI__GENERAL__DATADIR}/${INI__TXFR__ENDDIR_OUTBOUND}"
    local fail_dir="${INI__GENERAL__DATADIR}/${INI__TXFR__ERRDIR_OUTBOUND}"
    gossh details -t $taskid \
    | awk -f "$BKUP_BASE/lib/parse_go_subtask_details.awk" \
    | >/dev/null tee \
        >( grep '^SUCCEEDED' | while read rv fn; do mv "$fn" "$ok_dir/"; done ) \
        >( grep -v '^SUCCEEDED' | while read rv fn; do mv "$fn" "$fail_dir/"; done )
}


#
# For all files in each completed transfer,
#   Move successful files to purge directory
#   Move failed files to error directory
# Same as above for globus transfer filelist file
#
# PARAMS: none
#
function do_clean() {
    ok_dir="${INI__GENERAL__DATADIR}/${INI__TXFR__ENDDIR_OUTBOUND}"
    fail_dir="${INI__GENERAL__DATADIR}/${INI__TXFR__ERRDIR_OUTBOUND}"
    for taskfile in $( globus_task_files ); do
        taskid=$( globus_taskfile2taskid "$taskfile" )
        if is_globus_task_complete "$taskid" ; then
            cleanup_txfr_src_files $taskid || die "CLEAN: Fatal error"
            simple_tid=$( safe_varname $taskid )
            refname="${simple_tid}__status"; 
            taskstatus="${!refname}"
            case $taskstatus in
                SUCCEEDED)
                    mv "$taskfile" "$ok_dir/"
                    ;;
                FAILED)
                    mv "$taskfile" "$fail_dir/"
                    ;;
            esac
        else
            warn "Not complete: $taskid"
        fi
    done
}


#
# Print stats for a given taskid
#
# PARAMS:
#    taskid - String - Globus TaskID
#
function do_status() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    # FOR TASKFILE, 
    #   get total size from file
    #   get taskid, 
    #   from bytes_transferred, calculate % complete
    #   from mbits_sec, calculate EstimatedTimeRemaining
    local taskid
    for taskid; do
        # get taskfile
        local taskfn=$( globus_task_files | grep "$taskid" )
        local total_bytes=$( filelist2total_bytes $taskfn )
        go_task_details $taskid
        local taskvarname=$( safe_varname $taskid )
        local cur_bytes total_files cur_files mbs varref
        varref=${taskvarname}__bytes_transferred; cur_bytes=${!varref}
        varref=${taskvarname}__files;             total_files=${!varref}
        varref=${taskvarname}__files_transferred; cur_files=${!varref}
        varref=${taskvarname}__mbits_sec;         mbs=${!varref}
        local MBS=$( bc <<< "scale=2; $mbs / 8" )
        local pct_bytes=$( bc <<< "scale=2; $cur_bytes/$total_bytes * 100" )
        local pct_files=$( bc <<< "scale=2; $cur_files/$total_files * 100" )
        local eta_hours=$( bc <<< "scale=2; ( $total_bytes - $cur_bytes ) / 1048576 / $MBS / 3600" )
        echo total_bytes=$total_bytes
        echo cur_bytes=$cur_bytes
        echo total_files=$total_files
        echo cur_files=$cur_files
        echo mbs=$mbs
        echo MBS=$MBS
        local hdrfmt="%-37s %9s %9s %9s %9s\n"
        local datafmt="%-37s %9.2f %9.2f %9.2f %9.2f\n"
        printf "$hdrfmt" "" "Rate" "%complete" "%complete" "ETA"
        printf "$hdrfmt" "TaskID" "(MBS)" "(bytes)" "(files)" "(hours)"
        printf "$datafmt" $taskid $pct_bytes $pct_files $eta_hours
    done
}


#
# Update credentials for all endpoints that are part of any current transfers
#
function update_credentials() {
    [[ $BKUP_DEBUG -gt 0 ]] && set -x
    check_or_update_proxy 24 72
    local taskid key endpoint varref taskvarname
    declare -a endpoint_list
    for taskid in $( globus_taskids ); do
        go_task_details $taskid
        taskvarname=$( safe_varname $taskid )
        for key in src_endpoint dst_endpoint; do
            varref=${taskvarname}__$key
            log "Found endpoint: ${!varref}"
            endpoint_list+=( ${!varref} )
        done
        for endpoint in $( echo "${endpoint_list[@]}" | sort -u ); do
            log "About to (re)activate endpoint: '$endpoint'"
            endpoint_activate $min_hours $refresh_hours $endpoint
            log "Endpoint activation ok for '$endpoint'"
        done
    done
}


function usage() {
    cat <<ENDHERE

Usage: $1 <CMD>
  where CMD is one of:
    startnew - Start a new GO task for all files ready to transfer
    status   - report on a specific transfer
               OPTIONAL: taskid OR label
               DEFAULT: show all active tasks
    ls       - list all active transfers
    files    - list all files in a given transfer
               OPTIONAL: taskid OR label
               DEFAULT: use latest transfer
    update-credentials
             - Check or re-activate endpoints as needed
    clean    - Clean up old, completed transfers
    pause    - Pause transfer
               OPTIONAL: taskid OR label
               DEFAULT: pause all active transfers
    cancel   - Cancel transfer
               PARAMETER: taskid OR label
               NOTE: use special keyword 'ALLACTIVE' to cancel all transfers

ENDHERE
}


[[ $BKUP_DEBUG -gt 0 ]] && set -x

action=$1
shift
case $action in
    start*) 
        exec bin/mk_new_txfr $*
        ;;
    stat*)
        for taskid in $( globus_taskids ); do
            do_status $taskid
        done
        ;;
    details)
        for taskid in $( globus_taskids ); do
            gossh details $taskid
        done
        ;;
    ls) 
        globus_task_files | while read; do
            ts=$( stat -c '%Y' "$REPLY" )
            datestr=$( date -d "@$ts" '+%Y-%m-%d %H:%M:%S' )
            taskid=$( globus_taskfile2taskid "$REPLY" )
            echo "$datestr  $taskid"
        done | sort
        ;;
    files)
        globus_task_files
        ;;
    update*)
        update_credentials
        ;;
    clean)
        do_clean
        ;;
    pause)
        warn "PAUSE - not implemented yet"
        ;;
    cancel)
        warn "CANCEL - not implemented yet"
        ;;
    gocli)
        gossh "$*"
        ;;
    test)
        export BKUP_DEBUG=1
        export BKUP_VERBOSE=1
        log "Destroy proxy info ..."
        $(gosudo) grid-proxy-destroy
        log "Check proxy info ..."
        $(gosudo) grid-proxy-info
        log ""
        log ""
        log "Globus details ..."
        gossh help
#        check_or_update_proxy
#        rc=$?
#        log "Return value: $rc"
#        log "Check proxy info ..."
#        $(gosudo) grid-proxy-info
        ;;
    *)
        usage $(basename "$0")
        ;;
esac
