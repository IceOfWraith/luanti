#!/usr/bin/env python3
# usage: symbolize.py samples.txt [topN]  -> flat (self) and inclusive profile by function
import sys, subprocess, collections, bisect
path = sys.argv[1]; top = int(sys.argv[2]) if len(sys.argv) > 2 else 40
maps = []
for l in open(path + ".maps"):
    p = l.split()
    if len(p) < 6 or 'x' not in p[1]: continue
    lo, hi = (int(x, 16) for x in p[0].split('-'))
    maps.append((lo, hi, int(p[2], 16), p[5]))
maps.sort()
starts = [m[0] for m in maps]
samples = []; addrs = set()
for l in open(path):
    p = l.split(); tid = p[0]; pcs = [int(x, 16) for x in p[1:]]
    samples.append((tid, pcs)); addrs.update(pcs)
def locate(a):
    i = bisect.bisect_right(starts, a) - 1
    if i >= 0 and maps[i][0] <= a < maps[i][1]:
        lo, hi, off, f = maps[i]; return f, a - lo + off
    return None, a
byfile = collections.defaultdict(set); loc = {}
for a in addrs:
    f, o = locate(a); loc[a] = (f, o)
    if f: byfile[f].add(o)
sym = {}
for f, offs in byfile.items():
    offs = sorted(offs)
    segs = []
    ro = subprocess.run(["readelf", "-lW", f], capture_output=True, text=True).stdout
    for ln in ro.split("\n"):
        q = ln.split()
        if q and q[0] == "LOAD": segs.append((int(q[1], 16), int(q[2], 16), int(q[4], 16)))
    def tova(o):
        for po, pv, fs in segs:
            if po <= o < po + fs: return o - po + pv
        return o
    # PIE: file offset ~ vaddr for typical layouts; use addr2line on offsets
    r = subprocess.run(["addr2line", "-f", "-C", "-e", f] + [hex(tova(o)) for o in offs], capture_output=True, text=True)
    lines = r.stdout.split("\n")
    for k, o in enumerate(offs):
        fn = lines[2 * k] if 2 * k < len(lines) else "??"
        if fn == "??": fn = "??@" + f.split("/")[-1]
        sym[(f, o)] = fn
def name(a):
    f, o = loc[a]
    return sym.get((f, o), "??") if f else "??"
selfc = collections.Counter(); incl = collections.Counter(); threads = collections.Counter()
for tid, pcs in samples:
    threads[tid] += 1
    names = [name(a) for a in pcs]
    selfc[names[0]] += 1
    for n in set(names): incl[n] += 1
N = len(samples)
print(f"samples={N} (1 sample = 1ms CPU)  threads={dict(threads.most_common(8))}")
print("\n== SELF ==")
for n, c in selfc.most_common(top): print(f"{100*c/N:6.2f}% {c:7d}  {n[:160]}")
print("\n== INCLUSIVE ==")
for n, c in incl.most_common(top): print(f"{100*c/N:6.2f}% {c:7d}  {n[:160]}")
