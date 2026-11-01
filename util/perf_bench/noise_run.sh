#!/bin/bash
# usage: noise_run.sh <label> [runs] -> appends to results_noise/<label>.tsv
L=$1; R=${2:-3}; mkdir -p ${BENCH_ROOT:-/home/ice/ram-opt}/bench/results_noise
for r in $(seq 1 $R); do
  ${BENCH_ROOT:-/home/ice/ram-opt}/bench/harness/noisecheck.sh ${BENCH_ROOT:-/home/ice/ram-opt}/luanti/bin/luantiserver-$L ${BENCH_ROOT:-/home/ice/ram-opt}/bench/noise_$L.txt | grep _ms | tr '\n' '\t' | sed "s/^/run=$r\t/" ; echo
done | tee -a ${BENCH_ROOT:-/home/ice/ram-opt}/bench/results_noise/$L.tsv
cmp -s ${BENCH_ROOT:-/home/ice/ram-opt}/bench/noise_baseline.txt ${BENCH_ROOT:-/home/ice/ram-opt}/bench/noise_$L.txt && echo "noise output: bit-exact vs baseline" || echo "noise output: DIFFERS from baseline"
