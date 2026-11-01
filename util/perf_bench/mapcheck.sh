#!/bin/bash
# usage: mapcheck.sh <binary> [emerge_threads]
W=$(mktemp -d /tmp/claude-1000/mapw.XXXX); mkdir -p $W/worldmods; cp -r ${BENCH_ROOT:-/home/ice/ram-opt}/bench/harness/mapcheck $W/worldmods/
printf "gameid = devtest\nbackend = ${BACKEND:-dummy}\nmg_name = v7\n" > $W/world.mt
printf "mg_name = v7\nfixed_map_seed = 1234567\nnum_emerge_threads = ${2:-1}\nemergequeue_limit_total = 100000\nemergequeue_limit_generate = 100000\nserver_map_save_interval = ${SAVE_INTERVAL:-5.3}\n" > $W/c.conf
${PROF:+env LD_PRELOAD=$ROOT/bench/prof/libsampler.so SAMPLER_OUT=${BENCH_ROOT:-/home/ice/ram-opt}/bench/prof/mapgen.samples} $1 --config $W/c.conf --world $W --gameid devtest --port 30125 > $W/log 2>&1
cat $W/map_hash.txt 2>/dev/null || grep ERROR $W/log | head -3; rm -rf $W
