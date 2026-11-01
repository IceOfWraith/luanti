#!/usr/bin/env python3
# Build dashboard datasets from results/*.tsv, */catch2.tsv, changes.json, prof report
import json, glob, os, re, datetime
B = "/home/ice/ram-opt/bench"; O = B + "/dash"
alias = {"lightspread": "lightspread", "saveblock": "saveblock"}
order = ["baseline"] + [c["id"] for c in sorted(json.load(open(B + "/changes.json")), key=lambda c: c["order"])] + ["combined"]
runs = []
for f in glob.glob(B + "/results/*.tsv"):
    v = os.path.basename(f)[:-4]
    for line in open(f):
        d = dict(kv.split("=", 1) for kv in line.strip().split("\t") if "=" in kv)
        if "wall" not in d or "rss_end_kb" not in d: continue
        m, s = d["wall"].split(":")[-2:]
        num = lambda k: float(d[k])
        runs.append({"variant": v, "order": order.index(v) if v in order else 99, "run": int(d["run"]),
            "wall_s": round(int(m) * 60 + float(s), 2), "cpu_s": round(num("user_s") + num("sys_s"), 2),
            "peak_rss_mb": round(num("maxrss_kb") / 1024, 1),
            "rss_after_emerge_mb": round(num("rss_after_emerge_kb") / 1024, 1),
            "rss_after_lua_mb": round(num("rss_after_lua_kb") / 1024, 1),
            "rss_end_mb": round(num("rss_end_kb") / 1024, 1),
            "emerge_ms": num("emerge_8192_blocks_ms"), "get_node_ms": num("get_node_524k_ms"),
            "vmanip_ms": num("vmanip_rmw_ms"), "find_nodes_ms": num("find_nodes_ms"),
            "abm_ns_per_hit": num("abm_ns_per_hit"), "abm_hits": int(d["abm_hits"])})
runs.sort(key=lambda r: (r["order"], r["run"]))
json.dump(runs, open(O + "/runs.json", "w"))
noise = []
for f in glob.glob(B + "/results_noise/*.tsv"):
    v = os.path.basename(f)[:-4]
    for line in open(f):
        d = dict(kv.split("=", 1) for kv in line.strip().split("\t") if "=" in kv)
        if "noise3d_noeased_ms" not in d: continue
        noise.append({"variant": v, "order": order.index(v) if v in order else 99, "run": int(d["run"]),
            **{k: float(d[k]) for k in ["noise3d_noeased_ms", "noise3d_eased_ms", "noise2d_noeased_ms", "noise2d_eased_ms"]}})
noise.sort(key=lambda r: (r["order"], r["run"]))
json.dump(noise, open(O + "/noise.json", "w"))
mapgen = []
for f in glob.glob(B + "/results_mapgen/*.tsv"):
    v = os.path.basename(f)[:-4]
    for line in open(f):
        d = dict(kv.split("=", 1) for kv in line.strip().split("\t") if "=" in kv)
        if "gen_ms" not in d: continue
        mapgen.append({"variant": v, "order": order.index(v) if v in order else 99, "run": int(d["run"]), "mapgen_ms": float(d["gen_ms"]),
            "map_hash": d["content"] + "/" + d["light"] + "/" + d["param2"]})
mapgen.sort(key=lambda r: (r["order"], r["run"]))
json.dump(mapgen, open(O + "/mapgen.json", "w"))
mem = []
for f in glob.glob(B + "/results_mem/*.tsv"):
    v = os.path.basename(f)[:-4]
    for line in open(f):
        d = dict(kv.split("=", 1) for kv in line.strip().split("\t") if "=" in kv)
        if "heap_inuse_kb" not in d: continue
        mem.append({"variant": v, "order": order.index(v) if v in order else 99, "run": int(d["run"]),
            "heap_inuse_mb": round(float(d["heap_inuse_kb"]) / 1024, 1), "rss_air_mb": round(float(d["rss_air_kb"]) / 1024, 1)})
mem.sort(key=lambda r: (r["order"], r["run"]))
json.dump(mem, open(O + "/mem.json", "w"))
micro = []
for f in glob.glob(B + "/*/catch2.tsv"):
    v = f.split("/")[-2]
    for line in open(f):
        tc, bn, mean, sd = line.rstrip("\n").split("\t")
        micro.append({"variant": v, "suite": tc, "benchmark": bn, "key": tc + " / " + bn, "mean_ns": float(mean), "stddev_ns": float(sd)})
json.dump(micro, open(O + "/micro.json", "w"))
json.dump(sorted(json.load(open(B + "/changes.json")), key=lambda c: c["order"]), open(O + "/changes.json", "w"))
prof = []
sec = None
for line in open(B + "/prof/prof.report"):
    if line.startswith("== SELF"): sec = "self"; continue
    if line.startswith("== INCL"): sec = "inclusive"; continue
    m = re.match(r"\s*([\d.]+)%\s+(\d+)\s+(.*)", line)
    if m and sec:
        fn = re.sub(r"\(.*", "", m.group(3)).strip()
        prof.append({"kind": sec, "function": fn, "pct": float(m.group(1)), "samples": int(m.group(2))})
seen = set(); prof2 = []
for p in prof:
    k = (p["kind"], p["function"])
    if k in seen: continue
    seen.add(k); prof2.append(p)
json.dump([p for p in prof2 if p["kind"] == "inclusive"][:25] + [p for p in prof2 if p["kind"] == "self"][:25], open(O + "/profile.json", "w"))
print(len(runs), "runs;", len(micro), "micro;", len(prof2), "profile rows")
