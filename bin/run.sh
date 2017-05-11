#!/bin/bash

# all other scripts depend on this evironment variable to be set
[[ -z "$PDBKUP_BASE" ]] && export PDBKUP_BASE=/gpfs/fs0/DR/pdbkup

action=$1
shift
$PDBKUP_BASE/bin/$action $*
