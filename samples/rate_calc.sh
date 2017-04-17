#!/usr/bin/bash

info_fn=$1

set -x

tmpfn=$( mktemp )

sum_str=$( grep RATE_BPS $info_fn | grep SLICE | cut -d' ' -f3 | tee "$tmpfn" | xargs echo | tr " " "+" )
numvals=$( wc -l "$tmpfn" | cut -d' ' -f1 )

rate_BPS=$( echo "scale=2; ($sum_str)/$numvals" | bc )
rate_MBS=$( echo "scale=2; $rate_BPS/1048576" | bc )

cat "$tmpfn"
rm "$tmpfn"

