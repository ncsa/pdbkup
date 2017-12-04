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


function try_clean_unlock() {
    # Attempt to kill lockfile badger process and delete the related lockfile
    # PARAMS:
    #   pid : integer : id of lockfile-touch process to be killed
    # OUPUT:
    #   NONE
    # EXITCODES:
    #          0 : success
    #   non-zero : error
    [[ $BKUP_DEBUG -eq 1 ]] || return
    local pid=$1
    local exitval=0
    [[ -n $pid ]] && {
        # get file that is locked
        debug "Getting the file that is locked"
        local dirname=$( ps -o args= $pid | cut -d ' ' -f 1 --complement )
        local lockfile=${dirname}.lock
        debug $lockfile
        if [[ -f "$lockfile" ]] ; then
            debug "Before kill $pid statement"
            kill $pid || exitval=$?
            debug "Going into if loop to execute lockfile-remove"
            lockfile-remove "$dirname" || exitval=$?
        else
            exitval=99
        fi
    }
    return $exitval
}
