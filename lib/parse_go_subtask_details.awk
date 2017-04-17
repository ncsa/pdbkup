function abort() {
  abortnow=1
  exit
}

function print_prev_record() {
#  printf("Src: \"%s\"\nTgt: \"%s\"\nTaskType: \"%s\"\nExitVal: \"%s\"\nFaults: \"%s\"",
#    srcfn, tgtfn, tasktype, exitcode, faults )
  printf("%s %s %s\n", exitcode, tasktype, srcfn )
}

function print_record_status() {
  printf( "%s %s\n", exitcode, srcfn )
}

function check_prev_record() {
    if ( !( tasktype in valid_tasktypes ) ) {
        printf "ERROR: Unknown task type \"%s\"\n", tasktype >"/dev/stderr"
        print_prev_record()

        for (x in valid_tasktypes) {
            print x
        }
        abort()
    }
    if ( !( exitcode in valid_exitcodes ) ) {
        printf "ERROR: Unknown Exit Code \"%s\"\n", exitcode >"/dev/stderr"
        print_prev_record()
        abort()
    }
    if ( !( faults in valid_faults ) ) {
        printf "ERROR: Unknown Faults \"%s\"\n", faults >"/dev/stderr"
        print_prev_record()
        abort()
    }
    print_record_status()
}

BEGIN { 
    FS=":"
    filecount=0; tasktype=""; exitcode=""; srcfn=""; tgtfn=""; faults=""
    success = "SUCCESS"
    split( "FILE_COPY:ABCDEFG", ary ); for (i in ary) valid_tasktypes[ ary[i] ]
    split( "SUCCEEDED", ary ); for (i in ary) valid_exitcodes[ ary[i] ]
    split( "n/a", ary ); for (i in ary) valid_faults[ ary[i] ]
}

/^Task ID/ { 
    if (NR==1) { next }
    check_prev_record()
    next 
    }

/^Task Type/ {
    gsub(/^[[:space:]]+|[[:space:]]+$/,"", $NF)
    tasktype = $NF
    next 
    }

/^Completion Code/ {
    gsub(/^[[:space:]]+|[[:space:]]+$/,"", $NF)
    exitcode = $NF
    next 
    }

/^Source File/ {
    gsub(/^[[:space:]]+|[[:space:]]+$/,"", $NF)
    srcfn = $NF
    filecount++
    next 
    }

/^Destination File/ {
    gsub(/^[[:space:]]+|[[:space:]]+$/,"", $NF)
    tgtfn = $NF
    next 
    }

/^Faults/ {
    $1=""
    gsub( /^[ \t]+|[ \t]+$/, "" )
    faults = $0
    next 
    }

END { 
    if ( abortnow == 1 ) { exit 1 }
    check_prev_record()
}
