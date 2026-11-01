# Performance benchmark tools

Headless server workloads used to measure CPU and memory changes.
Results go to `$BENCH_ROOT/bench/results*/<label>.tsv`; binaries are
expected at `$BENCH_ROOT/luanti/bin/luantiserver-<label>` (RUN_IN_PLACE build).

| Script | Measures |
|---|---|
| `run.sh <label> [runs]` | Main workload (`benchmod`): emerge 8192 blocks with 4 threads, Lua node API, VoxelManip, find_nodes_in_area, ABM cost per call, RSS per phase. `PROF=1` adds the sampling profiler. |
| `mapgen_run.sh <label> [runs]` | Single-thread mapgen v7 time for a 320x160x320 area plus a hash of content, param2 and light (`mapcheck`). Maps must hash identically to baseline. |
| `noise_run.sh <label> [runs]` | Perlin map timings, and bit-exact output check over 495 parameter sets (`noisecheck`). |
| `memcheck.sh <label> [runs]` | Live heap (`mallinfo2`) after emerging ~99k mostly-air blocks (needs LuaJIT for FFI). |

`sampler.c` is an LD_PRELOAD CPU sampling profiler (per-thread CPU timers,
frame-pointer stacks); build with `gcc -O2 -shared -fPIC -o libsampler.so sampler.c -ldl`
and symbolize with `symbolize.py <samples> [topN]`. Build the profiled binary with
`-g -fno-omit-frame-pointer`.
