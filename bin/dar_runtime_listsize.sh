#!/usr/bin/bash

BASE=/gpfs/fs0/DR/INFO
KEY=DATASETS
TS=1481875200
DIR=$BASE/$KEY/$TS

for f in $(ls $DIR/*.filelist); do
    fn=$( basename "$f" ".filelist" )
    parts=( $( tr '_' ' ' <<< "$fn" ) )
    typ=${parts[2]}
    num=${parts[3]}
    ini_fn=$DIR/${TS}_${KEY}_${typ}_${num}_info.ini
    runtime=$(grep ELAPSED $ini_fn | cut -d' ' -f3)
    filecount=$(wc -l $f | cut -d' ' -f1)
    echo $num $runtime $filecount
done
