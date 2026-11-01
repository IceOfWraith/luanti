#!/bin/bash
# usage: memcheck.sh <label> [runs] -> results_mem/<label>.tsv
L=$1; R=${2:-3}; O=${BENCH_ROOT:-/home/ice/ram-opt}/bench/results_mem; mkdir -p $O
for r in $(seq 1 $R); do
W=$(mktemp -d /tmp/claude-1000/memw.XXXX); mkdir -p $W/worldmods; cp -r ${BENCH_ROOT:-/home/ice/ram-opt}/bench/harness/memcheck $W/worldmods/
printf "gameid = devtest\nbackend = dummy\nmg_name = v7\n" > $W/world.mt
printf "mg_name = v7\nfixed_map_seed = 1234567\nnum_emerge_threads = 4\nemergequeue_limit_total = 200000\nemergequeue_limit_generate = 200000\nsecure.trusted_mods = memcheck\nserver_unload_unused_data_timeout = 600\n" > $W/c.conf
${BENCH_ROOT:-/home/ice/ram-opt}/luanti/bin/luantiserver-$L --config $W/c.conf --world $W --gameid devtest --port 30127 > $W/log 2>&1
echo -e "run=$r\t$(cat $W/mem.txt)" | tee -a $O/$L.tsv; rm -rf $W
done
