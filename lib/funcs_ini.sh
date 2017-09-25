###
### INI FILE RELATED FUNCTIONS
###


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
