#!/bin/bash

BKUP_BASE=/gpfs/fs0/DR

DEBUG=0     #debug messages
VERBOSE=1   #info messages
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
dirkeys=( $( get_all_vars_matching_prefix INI__DIRS__ 1 ) )

function all_bkup_dirs() {
    for d in "${dirkeys[@]}"; do
        find "$INI__GENERAL__INFODIR/$d" -mindepth 1 -maxdepth 1 -type d | sort
    done
}


function latest_bkupdir() {
    for d in "${dirkeys[@]}"; do
        find "$INI__GENERAL__INFODIR/$d" -mindepth 1 -maxdepth 1 -type d | sort -r | head -1
    done
}


# Input: String - "pathname ending in a timestamp"
# Output: String - "pathname date time"
function add_datetime() {
    awk '{c=split( $1, parts, "/" ); dt=strftime( "%F %T", parts[c] ); printf("%s %s\n",$0,dt);}'
}


function sanitize() {
    if [[ $# -lt 1 ]]; then
        die "Missing bkupdir"
    fi
    infodir=$1
    parts=( $( echo $infodir | bkupinfodir2key_ts ) )
    key=${parts[0]}
    ts=${parts[1]}
    set -x
    find /gpfs/fs0/DR/DATA -name "*$ts*" -delete
    find $infodir -type f ! -name 'allfileslist' -delete
    set +x
}


function usage() {
    cat <<ENDHERE

Usage: $1 <CMD>
  where CMD is one of:
    init        - initialize backups for the newest snapshot
                  OPTIONAL: /path/to/existing/backup/infodir
                  DEFAULT: use latest snapshot
    startworker - start processing parallel jobs on a worker
    status      - report on a specific backup
                  OPTIONAL: /path/to/existing/backup/infodir
                  DEFAULT: use latest backup infodir
    dbstatus    - Display progress of parallel tasks
    dbclean     - Clean up database and related files for completed parallel jobs
    ls          - list all known backups
    ps          - list all backup processes on the local node
    files       - list all files associated with a given backup
                  OPTIONAL: /path/to/existing/backup/infodir
                  DEFAULT: use latest backup infodir
    tree        - List file counts in dir tree rooted at "$INI__GENERAL__DATADIR"
    plotdar     - Create gnuplot of dar slice creation times vs filesiszes
    purge       - Purge all files from old, completed processes (includes txfrs)
    stop        - Stop the parallel process (allow subprocesses to complete)
    kill        - Stop ALL backup processes
    sanitize    - *caution* delete all files from latest backup
    reset       - *caution* delete entire backup tree

ENDHERE

}


action=$1
shift
case $action in
    init) 
        exec bin/mk_bkup_tasks $*
        ;;
    startworker)
        exec bin/startworker
        ;;
    sanitize) 
        sanitize $*
        ;;
    reset) 
        read -p "Delete ALL under /gpfs/fs0/DR/{DATA,INFO} trees? "
        if [[ "$REPLY" == "Y" ]]; then
            set -x
            find /gpfs/fs0/DR/DATA -mindepth 1 -delete
            find /gpfs/fs0/DR/INFO -mindepth 1 -delete
            set +x
        else
            die "Declined, exiting without making changes."
        fi
        ;;
    stat*)
        d=$1
        [[ $# -lt 1 ]] && d=$( latest_bkupdir )
        exec bin/status.py -a $d
        ;;
    dbstat*)
        [[ $# -lt 1 ]] && die "Missing bkupdir path"
        parts=( $( bkupinfodir2key_ts <<< "$1" ) )
        workdir="$INI__GENERAL__DATADIR/$INI__PARALLEL__WORKDIR"
        pfx="${parts[0]}_${parts[1]}"
        cmdfile="$workdir/${pfx}.sqlworker.cmd"
        [[ -f "$cmdfile" ]] || clean_exit "Backup already completed"
        dburl=$( dburl_from_sqlworkercmdfile "$cmdfile" )
        num_ready=$( num_ready_tasks "$dburl" )
        num_active=$( num_active_tasks "$dburl" )
        num_done=$( num_successful_tasks "$dburl" )
        num_failed=$( num_failed_tasks "$dburl" )
        let "num_total = $num_ready + $num_active + $num_done + $num_failed"
        pct_ready=$( bc <<< "scale=2; $num_ready/$num_total * 100" )
        pct_active=$( bc <<< "scale=2; $num_active/$num_total * 100" )
        pct_done=$( bc <<< "scale=2; $num_done/$num_total * 100" )
        pct_failed=$( bc <<< "scale=2; $num_failed/$num_total * 100" )
        printf "%10s: %5d  (%4.2f%%)\n" 'Failed' $num_failed $pct_failed
        printf "%10s: %5d  (%4.2f%%)\n" 'Successful' $num_done $pct_done
        printf "%10s: %5d  (%4.2f%%)\n" 'Active' $num_active $pct_active
        printf "%10s: %5d  (%4.2f%%)\n" 'Pending' $num_ready $pct_ready
        printf "%10s: %5d\n"       'Total' $num_total
        ;;
    dbclean)
        # Find sqlworker cmd files
        ls_sqlworker_cmdfiles \
        | while read fn; do
            # Get DBURL
            dburl=$( dburl_from_sqlworkercmdfile "$fn" )
            # If all tasks have completed
            ready_count=$( num_ready_tasks "$dburl" )
            active_count=$( num_active_tasks "$dburl" )
            if [[ $ready_count == 0 && $active_count == 0 ]] ; then
                # Determine key & timestamp
                read key ts <<< $(filename2key_ts "$fn" )
                infodir="${INI__GENERAL__INFODIR}/${key}/${ts}"
                # If all tasks successful
                failed_count=$( num_failed_tasks "$dburl" )
                if [[ $failed_count -eq 0 ]]; then
                    # Move DB file to relevant INFODIR
                    mv "$fn" "$infodir"
                else
                    warn "Failures reported in WORKER QUEUE \"$dburl\""
                fi
                # Move sqlworker file to relevant INFODIR
                dbfn=$( dburl2filename "$dburl" )
                mv "$dbfn" "$infodir"
            fi
        done
        ;;
    errshow)
        warn "ERRSHOW NOT IMPLEMENTED YET"
        # Find errors in joblogs
        # Find errors in dar err files
        ;;
    ls) 
        (   echo "BKUP_DIR DATE TIME"
            all_bkup_dirs | add_datetime
        ) | column -t
        ;;
    ps)
        psopts=( -o pid,stat,time,command --sort stat  )
        pgrep -f dar | xargs -r ps "${psopts[@]}" 
        pgrep -f parallel | xargs -r ps "${psopts[@]}"
        ;;
    files)
        d=$1
        [[ $# -lt 1 ]] && d=$( latest_bkupdir )
        parts=( $( bkupinfodir2key_ts <<< "$d" ) )
        find /gpfs/fs0/DR -name "*${parts[1]}*"
        ;;
    tree)
        find "$INI__GENERAL__DATADIR" -maxdepth 1 -mindepth 1 -type d \
        | sort \
        | while read; do
            count=$( ls "$REPLY" | wc -l )
            printf "%3d  %s\n" $count $REPLY
        done
        ;;
    purge)
        find "${INI__GENERAL__DATADIR}/${INI__PURGE__SRCDIR}" -mindepth 1 -delete
        ;;
    stop)
        pkill -f parallel
        ;;
    kill)
        pkill -f parallel
        pkill -f dar
        ;;
    plot*)
        d=$1
        [[ $# -lt 1 ]] && d=$( latest_bkupdir )
        exec bin/$action $d
        ;;
    ini)
        export BKUP_DEBUG=1
        export BKUP_VERBOSE=1
        dump_ini
        ;;
#    qls)
#        next_worker_cmdfile
#        ;;
#    qnext)
#        next_worker_cmdfile
#        ;;
    *)
        usage $(basename "$0")
        ;;
esac
