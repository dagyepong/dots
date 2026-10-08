#!/usr/bin/env python3
# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   C O D E X   U S A G E                                                  │
# │   the plan's limits from Codex's own session logs                        │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Print, as one JSON line, the rate limits Codex last recorded.

Usage: codex_usage.py

Codex writes the plan's limits into its session log on every turn, as a
`rate_limits` object with a primary and a secondary window. The newest logs
are read from the end for the last such record; nothing is sent anywhere, so
the figures are as fresh as the last turn, and `observed` says when that was.
"""

import calendar
import json
import os
import sys
import time
from pathlib import Path

HOME = Path(os.path.expanduser("~"))
SESSIONS = Path(os.environ.get("CODEX_HOME") or (HOME / ".codex")) / "sessions"

# The newest logs searched, and how much of the end of each is read.
NEWEST = 8
TAIL = 256 * 1024


def fail():
    print(json.dumps({"available": False}))
    sys.exit(0)


def parse_timestamp(text):
    try:
        return calendar.timegm(time.strptime(text[:19], "%Y-%m-%dT%H:%M:%S"))
    except (TypeError, ValueError):
        return None


def window_name(minutes):
    if minutes >= 40000:
        return "Month"
    if minutes >= 10080:
        return "Week"
    if minutes >= 1440:
        return f"{round(minutes / 1440)} days"
    return f"{round(minutes / 60)} hours"


def last_record(path):
    """The last line of a log that carries `rate_limits`, parsed."""
    try:
        with path.open("rb") as handle:
            handle.seek(0, os.SEEK_END)
            size = handle.tell()
            handle.seek(max(0, size - TAIL))
            lines = handle.read().decode("utf-8", "replace").splitlines()
    except OSError:
        return None
    if size > TAIL:
        lines = lines[1:]
    for line in reversed(lines):
        if '"rate_limits"' not in line:
            continue
        try:
            record = json.loads(line)
        except ValueError:
            continue
        limits = (record.get("payload") or {}).get("rate_limits")
        if isinstance(limits, dict):
            return record, limits
    return None


def window(limit, observed):
    """One window, or None when its share is missing or out of range."""
    if not isinstance(limit, dict):
        return None
    used = limit.get("used_percent")
    minutes = limit.get("window_minutes") or 0
    if not isinstance(used, (int, float)) or not 0 <= used <= 100:
        return None
    resets = limit.get("resets_at")
    if not isinstance(resets, (int, float)):
        seconds = limit.get("resets_in_seconds")
        resets = observed + seconds if isinstance(seconds, (int, float)) and observed else 0
    return {"name": window_name(minutes), "minutes": minutes,
            "used": used / 100, "resets": int(resets)}


def modified(path):
    """A log's mtime, or 0 for one rotated away since it was listed."""
    try:
        return path.stat().st_mtime
    except OSError:
        return 0


def main():
    if not SESSIONS.is_dir():
        fail()
    logs = sorted(SESSIONS.rglob("rollout-*.jsonl"),
                  key=modified, reverse=True)[:NEWEST]
    for path in logs:
        found = last_record(path)
        if found is None:
            continue
        record, limits = found
        observed = parse_timestamp(record.get("timestamp") or "") or int(modified(path))
        windows = [window(limits.get(key), observed) for key in ("primary", "secondary")]
        plan = limits.get("plan_type") or ""
        print(json.dumps({
            "available": True,
            "plan": plan[:1].upper() + plan[1:],
            "observed": observed,
            "limits": [item for item in windows if item],
        }))
        return
    fail()


if __name__ == "__main__":
    main()
