#!/usr/bin/env python3
"""How many frames does the shell render at idle, and does hiding the bar stop them?

Restarts SekaiPop with Qt's render-loop log turned on, counts the frames it renders per second
while nothing is happening, then hides the bar (settings IPC) and counts again. Puts the bar back
and restarts the shell normally at the end.

  cd ~/.config/quickshell/sekaipop && python3 tests/perf-test/qs-frames.py

Hands off the mouse and keyboard while it runs (about 70 s); no media playing.
"""
import os, re, subprocess, sys, threading, time

CFG = "sekaipop"
lines = []                       # (time, text)
lock = threading.Lock()


def reader(p):
    for raw in p.stdout:
        with lock:
            lines.append((time.time(), raw.decode(errors="replace").rstrip()))


def ipc(*a):
    subprocess.run(["qs", "-c", CFG, "ipc", "call", *a], capture_output=True)


def count(t0, t1):
    with lock:
        sel = [t for t, s in lines if t0 <= t < t1 and re.search(r"render", s, re.I)]
    per_sec = {}
    for t in sel:
        per_sec[int(t - t0)] = per_sec.get(int(t - t0), 0) + 1
    n = int(t1 - t0)
    vals = [per_sec.get(i, 0) for i in range(n)]
    return len(sel), vals


subprocess.run(["qs", "kill", "-c", CFG], capture_output=True)
time.sleep(1.5)
RULES = "qt.scenegraph.time.renderloop=true"


def launch(extra, env_rules):
    env = dict(os.environ)
    if env_rules:
        env["QT_LOGGING_RULES"] = RULES
    # quickshell may print its log on stdout or stderr: read both through one pipe
    p = subprocess.Popen(["qs", "-c", CFG, *extra], env=env,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    threading.Thread(target=reader, args=(p,), daemon=True).start()
    return p


p = launch([], True)
try:
    print("shell starting, waiting 20 s to settle ...")
    time.sleep(20)
    with lock:
        seen = len(lines)
    if seen == 0:
        print("no log output with the environment variable; trying --log-rules ...")
        p.terminate(); time.sleep(1.5)
        subprocess.run(["qs", "kill", "-c", CFG], capture_output=True)
        p = launch(["--log-rules", RULES], False)
        time.sleep(20)
    a0 = time.time(); time.sleep(20); a1 = time.time()
    n_all, v_all = count(a0, a1)
    ipc("options", "set", "bar.visible", "false")
    time.sleep(5)
    b0 = time.time(); time.sleep(20); b1 = time.time()
    n_nobar, v_nobar = count(b0, b1)
    print(f"\neverything on : {n_all:5d} render lines in 20 s  ({n_all/20:.1f}/s)   per second: {v_all}")
    print(f"bar hidden    : {n_nobar:5d} render lines in 20 s  ({n_nobar/20:.1f}/s)   per second: {v_nobar}")
    with lock:
        sample = [s for t, s in lines if a0 <= t < a0 + 2][:6]
    print("\nfirst lines of the log (for me to check the format):")
    for s in sample:
        print("  ", s[:200])
    print(f"\ntotal log lines captured: {len(lines)}")
    if not any(re.search(r"render", s, re.I) for _, s in lines):
        print("\nNo render lines at all. Raw log head:")
        for _, s in lines[:15]:
            print("  ", s[:200])
finally:
    ipc("options", "set", "bar.visible", "true")
    p.terminate()
    time.sleep(1)
    subprocess.Popen(["qs", "-c", CFG, "-d"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
