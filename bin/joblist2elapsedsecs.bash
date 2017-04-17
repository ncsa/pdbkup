#!/bin/bash

START=$( awk 'NR==2 { print $3; exit }' $1 )

END=$( tail -n+2 $1 \
| awk '{printf("scale=3;%s+%s\n",$3,$4)}' \
| bc \
| sort -n \
| tail -1 )

ELAPSED=$( bc <<< "scale=3; $END - $START" )

echo $ELAPSED
