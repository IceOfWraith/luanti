#!/bin/bash
# usage: mapgen_run.sh <label> [runs] -> results_mapgen/<label>.tsv (single emerge thread, deterministic map hash)
L=$1; R=${2:-3}; O=${BENCH_ROOT:-/home/ice/ram-opt}/bench/results_mapgen; mkdir -p $O
for r in $(seq 1 $R); do
  echo -e "run=$r\t$(${BENCH_ROOT:-/home/ice/ram-opt}/bench/harness/mapcheck.sh ${BENCH_ROOT:-/home/ice/ram-opt}/luanti/bin/luantiserver-$L | tr ' ' '\t')"
done | tee -a $O/$L.tsv
