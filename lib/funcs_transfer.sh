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
