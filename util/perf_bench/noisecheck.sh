#!/bin/bash
# usage: noisecheck.sh <binary> <outfile>
W=$(mktemp -d /tmp/claude-1000/noisew.XXXX); mkdir -p $W/worldmods; cp -r ${BENCH_ROOT:-/home/ice/ram-opt}/bench/harness/noisecheck $W/worldmods/
printf "gameid = devtest\nbackend = dummy\nmg_name = singlenode\n" > $W/world.mt
printf "mg_name = singlenode\nfixed_map_seed = 42\n" > $W/c.conf
$1 --config $W/c.conf --world $W --gameid devtest --port 30124 > $W/log 2>&1
cp $W/noise_hashes.txt $2; cat $W/noise_times.txt; grep ERROR $W/log | head -6; rm -rf $W; wc -l < $2
