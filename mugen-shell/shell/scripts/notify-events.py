#!/usr/bin/env python3
"""Fire desktop notifications for today's mugen-shell calendar events.

Run periodically (e.g. every minute via systemd timer). Events with a time
fire when the current minute matches the event time. All-day events fire
once at 08:00. State of fired notifications is kept in
$XDG_STATE_HOME/mugen-shell/notified.json to prevent duplicates.
"""

import json
import os
import sqlite3
import subprocess
import sys
from datetime import datetime, timedelta


def paths():
    data_home = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    state_home = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    db = os.path.join(data_home, "mugen-shell", "calendar.db")
    fired = os.path.join(state_home, "mugen-shell", "notified.json")
    return db, fired


def load_json(path, default):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return default


def save_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f)


def notify(summary, body):
    subprocess.run(
        ["notify-send", "-a", "mugen-shell", "-i", "x-office-calendar", summary, body],
        check=False,
    )


def prune_old_fired(fired_set, now):
    cutoff = now - timedelta(days=7)
    cleaned = set()
    for key in fired_set:
        date_part = key.split(":", 1)[0]
        try:
            if datetime.strptime(date_part, "%Y-%m-%d") >= cutoff:
                cleaned.add(key)
        except ValueError:
            continue
    return cleaned


def fetch_today(db_path, today):
    if not os.path.exists(db_path):
        return []
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "SELECT id, time, title FROM events WHERE date = ? ORDER BY time",
            (today,),
        ).fetchall()
        conn.close()
        return [
            {"id": r["id"], "time": r["time"] or "", "title": r["title"]}
            for r in rows
        ]
    except sqlite3.Error:
        return []


def main():
    db_path, fired_path = paths()
    fired_data = load_json(fired_path, {"fired": []})
    fired_set = set(fired_data.get("fired", []))

    now = datetime.now()
    today = now.strftime("%Y-%m-%d")
    current_hm = now.strftime("%H:%M")

    events = fetch_today(db_path, today)
    new_keys = []
    for event in events:
        eid = event["id"]
        title = event["title"]
        etime = event["time"]
        if not eid or not title:
            continue

        key = f"{today}:{eid}"
        if key in fired_set:
            continue

        if etime:
            if etime == current_hm:
                notify("Mugen Calendar", f"{etime} — {title}")
                new_keys.append(key)
        else:
            if current_hm >= "08:00":
                notify("Mugen Calendar", f"Today — {title}")
                new_keys.append(key)

    if new_keys:
        fired_set.update(new_keys)
        fired_set = prune_old_fired(fired_set, now)
        save_json(fired_path, {"fired": sorted(fired_set)})


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
