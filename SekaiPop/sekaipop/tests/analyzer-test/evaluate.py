"""Runs sekai_analyzer.py on the made-up song and compares with what really
happened in it. Usage: python3 evaluate.py"""
import json, subprocess, sys, os
import numpy as np
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import synth_song

HOP_S = 735 / 44100
raw = "/tmp/sekai_test_song.raw"
x, truth = synth_song.make()
(np.clip(x, -1, 1) * 32767).astype("<i2").tofile(raw)
engine = sys.argv[1] if len(sys.argv) > 1 else "numpy"
p = subprocess.run([sys.executable, os.path.join(here, "..", "..", "scripts", "cava", "sekai_analyzer.py"), "--file", raw, "--engine", engine],
                   capture_output=True, text=True)
print("engine:", p.stderr.strip() or "?")
frames = [json.loads(l) for l in p.stdout.splitlines()]
open("/tmp/sekai_frames_%s.jsonl" % engine, "w").write(p.stdout)
ev = {"k": [], "s": [], "h": [], "b": []}
lead = []
for i, f in enumerate(frames):
    t = (i + 1) * HOP_S                     # time at the END of the hop
    for e in f["e"]:
        ev[e[0]].append(t)
    if "v" in f:
        lead.append(t)

def match(found, real, tol=0.07, early=0.03):
    found = list(found); hits = 0; lat = []
    used = set()
    for r in real:
        best = None
        for j, f in enumerate(found):
            if j in used: continue
            if -early <= f - r <= tol + 0.03 and (best is None or abs(f - r) < abs(found[best] - r)):
                best = j
        if best is not None:
            used.add(best); hits += 1; lat.append(found[best] - r)
    return hits, len(real), len(found) - hits, (np.mean(lat) * 1000 if lat else float('nan'))

names = {"k": "kick", "s": "snare", "h": "hat", "b": "bass note"}
for k in "ksh b".replace(" ", ""):
    h, n, extra, lat = match(ev[k], truth[k], tol=0.30 if k == "b" else 0.07)
    print(f"{names[k]:10s} found {h:3d}/{n:3d}  extra {extra:3d}  mean delay {lat:5.0f} ms")

# lead: how much of each phrase is covered, and how much tone is claimed outside phrases
lead = np.array(lead)
cov = []
for (a, b) in truth["lead"]:
    inside = ((lead >= a) & (lead <= b)).sum() * HOP_S
    cov.append(inside / (b - a))
outside = sum(1 for t in lead if not any(a - 0.05 <= t <= b + 0.05 for a, b in truth["lead"])) * HOP_S
print("lead coverage per phrase:", " ".join(f"{c*100:3.0f}%" for c in cov))
print(f"lead claimed outside phrases: {outside:.2f} s of {len(frames)*HOP_S:.0f} s")
