#!/bin/bash

# all other scripts depend on this evironment variable to be set
[[ -z "$PDBKUP_BASE" ]] && export PDBKUP_BASE=/gpfs/fs0/DR/pdbkup

# Ensure PATH includes path to parallel
source $PDBKUP_BASE/lib/read_ini.sh
read_ini $PDBKUP_BASE/conf/settings.ini
[[ ":$PATH:" != *":$INI__PARALLEL__PATH:"* ]] \
&& PATH="${PATH:+"$PATH:"}$INI__PARALLEL__PATH"

action=$1
shift
exec $PDBKUP_BASE/bin/$action $*
