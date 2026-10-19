#!/usr/bin/env python3
"""Who is using the GPU, and which of SekaiPop's windows are screen-sized?

Read-only. Needs python3, an AMD/Intel GPU driver that exposes DRM fdinfo
(amdgpu does; NVIDIA's proprietary driver does not), and `hyprctl`.

  python3 gpu-attribution.py [seconds]          (default 30)

Run it three times under the same conditions and keep the output of each:
  1. IDLE: nothing playing, no panels open, hands off the mouse.
  2. MEDIA: a player playing, media-pill visualizer ON.
  3. MEDIA, pill visualizer OFF (VisualizerService.pillStyle = none).

What it prints
  * every layer-shell surface of sekaipop-* as w x h and as a share of its
    monitor. A transparent surface the size of the screen is composited
    again by Hyprland on every frame the shell draws into it.
  * per process, the share of GPU time (drm-engine-gfx) over the window, for
    quickshell, Hyprland and anything else that used the GPU. This is the
    number nvtop shows per process; it separates 'qs renders' from
    'Hyprland composites what qs drew'.
"""
import json, os, subprocess, sys, time, glob, re

secs = float(sys.argv[1]) if len(sys.argv) > 1 else 30.0
PROC = os.environ.get("PROCROOT", "/proc")   # overridable so the parser can be tested


def comm(pid):
    try:
        return open(f"{PROC}/{pid}/comm").read().strip()
    except OSError:
        return "?"


def gpu_ns():
    """{(pid, comm, pdev): total busy ns across the process's DRM clients}"""
    out = {}
    for d in glob.glob(f"{PROC}/[0-9]*"):
        pid = os.path.basename(d)
        seen = set()
        for fd in glob.glob(f"{d}/fdinfo/*"):
            try:
                txt = open(fd).read()
            except OSError:
                continue
            if "drm-driver" not in txt:
                continue
            kv = dict(re.findall(r"^(drm-[\w-]+):\s*(.+)$", txt, re.M))
            cid = (kv.get("drm-client-id"), kv.get("drm-pdev"))
            if cid in seen:            # one client can own many fds
                continue
            seen.add(cid)
            ns = 0
            for k, v in kv.items():
                if k.startswith("drm-engine-") and not k.startswith("drm-engine-capacity"):
                    m = re.match(r"(\d+)\s*ns", v)
                    if m:
                        ns += int(m.group(1))
            key = (pid, comm(pid), kv.get("drm-pdev", "?"))
            out[key] = out.get(key, 0) + ns
    return out


def layers():
    try:
        j = json.loads(subprocess.run(["hyprctl", "layers", "-j"], capture_output=True,
                                      text=True, timeout=5).stdout)
        mons = {m["name"]: (m["width"], m["height"]) for m in
                json.loads(subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True,
                                          text=True, timeout=5).stdout)}
    except Exception as e:
        print("hyprctl unavailable:", e)
        return
    print("layer surfaces (sekaipop-*), size and share of the monitor")
    rows = []
    for mon, v in j.items():
        mw, mh = mons.get(mon, (0, 0))
        for lvl, arr in v.get("levels", {}).items():
            for s in arr:
                ns = s.get("namespace", "")
                if ns.startswith(("sekaipop", "quickshell")):
                    share = (s["w"] * s["h"]) / (mw * mh) * 100 if mw and mh else 0
                    rows.append((share, mon, lvl, ns, s["w"], s["h"]))
    for share, mon, lvl, ns, w, h in sorted(rows, reverse=True):
        flag = "  <-- screen-sized" if share >= 50 else ""
        print(f"  {mon:8} level {lvl}  {ns:32} {w:5} x {h:<5} {share:5.1f}%{flag}")
    print()


layers()
a = gpu_ns()
t0 = time.time()
time.sleep(secs)
b = gpu_ns()
dt = time.time() - t0
print(f"GPU time over {dt:.1f} s, per process (percent of one engine's wall time)")
rows = []
for k, v in b.items():
    d = v - a.get(k, 0)
    if d > 0:
        rows.append((100.0 * d / (dt * 1e9), k))
for pct, (pid, name, pdev) in sorted(rows, reverse=True):
    print(f"  {pct:6.2f} %  {name:16} pid {pid:>7}  gpu {pdev}")
if not rows:
    print("  nothing used the GPU through fdinfo (driver without fdinfo, or no access: try sudo)")
