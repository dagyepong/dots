#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   G I T H U B                                                            │
# │   github contribution calendar scraper                                   │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""A year of contributions, scraped from a public GitHub profile.

GitHub serves the contribution calendar as an HTML fragment at
/users/<name>/contributions, the one the profile page loads. Each cell carries
its date and level (0-4), and a tooltip keyed by the same id has the exact
count. No token or API key is needed.

An empty or unknown name is reported as `"reason": "user"` so the settings
can show it; any other failure is reported as unavailable, and the shell keeps
its last good grid.
"""

import json
import re
import subprocess
import sys

ENDPOINT = "https://github.com/users/{user}/contributions"
TIMEOUT = 12

# A day cell, with its attributes in the order GitHub writes them: the date,
# the grid position in the id (row 0-6 is the weekday, col the week), then the
# level. `[^>]*?` skips whatever sits between them without leaving the tag.
DAY = re.compile(
    r'data-date="(\d{4}-\d{2}-\d{2})"[^>]*?'
    r'id="contribution-day-component-(\d+)-(\d+)"[^>]*?'
    r'data-level="(\d)"'
)

# The exact count, from the cell's tooltip: "No contributions on …" or
# "N contribution(s) on …". Optional: the level carries the colour, so a
# missing tooltip leaves the count at zero.
TIP = re.compile(
    r'for="contribution-day-component-(\d+)-(\d+)"[^>]*?>\s*'
    r'(No|[\d,]+) contribution'
)

# The year's total, from the heading above the graph, so it matches the
# profile exactly.
TOTAL = re.compile(
    r'js-contribution-activity-description[^>]*>\s*([\d,]+)'
)


class UserNotFound(Exception):
    """GitHub has no public profile under this name."""


def number(text):
    return int(text.replace(",", ""))


def fetch(user):
    url = ENDPOINT.format(user=user)
    result = subprocess.run(
        ["curl", "-sS", "--max-time", str(TIMEOUT), url],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "no answer from github.com")
    return result.stdout


def report(user):
    html = fetch(user)

    cells = DAY.findall(html)
    # No cells: a wrong name, or a profile whose calendar is not public.
    if not cells:
        raise UserNotFound(user)

    counts = {(int(row), int(col)): 0 if amount == "No" else number(amount)
              for row, col, amount in TIP.findall(html)}

    days = []
    columns = max(int(col) for _, _, col, _ in cells) + 1
    weeks: list[list[int | None]] = [[None] * 7 for _ in range(columns)]
    for date, row, col, level in cells:
        row, col, level = int(row), int(col), int(level)
        weeks[col][row] = level
        days.append({"date": date, "level": level,
                     "count": counts.get((row, col), 0)})

    # Newest last, so the tail of the list is the days just gone.
    days.sort(key=lambda day: day["date"])

    # The current streak. Like GitHub, an empty today does not end it, but
    # any earlier gap does.
    streak = 0
    for index, day in enumerate(reversed(days)):
        if day["level"] > 0:
            streak += 1
        elif index == 0:
            continue
        else:
            break

    total = TOTAL.search(html)
    return {
        "available": True,
        "user": user,
        "total": number(total.group(1)) if total else sum(d["count"] for d in days),
        "streak": streak,
        "today": days[-1]["count"] if days else 0,
        "busiest": max((d["count"] for d in days), default=0),
        # One list per week, seven entries each, null where the calendar has no
        # cell (the first and last weeks are usually partial). The shell draws
        # the columns left to right, oldest to newest.
        "weeks": weeks,
        "source": f"github.com/{user}",
    }


if __name__ == "__main__":
    user = " ".join(sys.argv[1:]).strip().lstrip("@")
    if user == "":
        # No name configured.
        print(json.dumps({"available": False, "reason": "user"}))
        sys.exit(0)
    try:
        print(json.dumps(report(user)))
    except UserNotFound as error:
        sys.stderr.write(f"github: no such profile: {error}\n")
        print(json.dumps({"available": False, "reason": "user"}))
    except Exception as error:  # a widget must never take the shell down
        sys.stderr.write(f"github failed: {error}\n")
        print(json.dumps({"available": False}))
