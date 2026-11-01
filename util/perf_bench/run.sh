#!/bin/bash
# usage: run.sh <label> [runs]  -- runs luanti/bin/luantiserver workload, appends to results/<label>.tsv
set -e
LABEL=$1; RUNS=${2:-3}
ROOT=${BENCH_ROOT:-/home/ice/ram-opt}; BIN=${BIN:-$ROOT/luanti/bin/luantiserver-$LABEL}; H=$ROOT/bench/harness
OUT=$ROOT/bench/results; mkdir -p $OUT
for r in $(seq 1 $RUNS); do
  W=$(mktemp -d /tmp/claude-1000/benchworld.XXXX)
  mkdir -p $W/worldmods && cp -r $H/benchmod $W/worldmods/
  cat > $W/world.mt <<EOT
gameid = devtest
backend = sqlite3
mg_name = v7
EOT
  echo "seed = 1234567" > $W/map_meta.txt; echo "[end_of_params]" >> $W/map_meta.txt
  cat > $W/bench.conf <<EOT
fixed_map_seed = 1234567
mg_name = v7
num_emerge_threads = 4
emergequeue_limit_total = 100000
emergequeue_limit_diskonly = 100000
emergequeue_limit_generate = 100000
active_block_range = 2
server_map_save_interval = 5.3
dedicated_server_step = 0.05
max_forceloaded_blocks = 1000
active_block_mgmt_interval = 0.5
abm_interval = 1.0
secure.trusted_mods = benchmod
EOT
  /usr/bin/time -v env ${PROF:+LD_PRELOAD=$ROOT/bench/prof/libsampler.so SAMPLER_OUT=$ROOT/bench/prof/$LABEL.samples} $BIN --config $W/bench.conf --world $W --gameid devtest --port 30123 > $W/server.log 2> $W/time.txt || true
  wall=$(grep "Elapsed (wall" $W/time.txt | awk '{print $NF}')
  usr=$(grep "User time" $W/time.txt | awk '{print $NF}')
  sys=$(grep "System time" $W/time.txt | awk '{print $NF}')
  rss=$(grep "Maximum resident" $W/time.txt | awk '{print $NF}')
  res=$(tr '\n' '\t' < $W/bench_result.txt 2>/dev/null || echo FAIL)
  echo -e "run=$r\twall=$wall\tuser_s=$usr\tsys_s=$sys\tmaxrss_kb=$rss\t$res" | tee -a $OUT/$LABEL.tsv
  rm -rf $W
done
