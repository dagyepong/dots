#!/usr/bin/env python3
# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   U P D A T E S                                                          │
# │   packages an upgrade would touch · counted, never installed             │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""List pending updates from the repositories and the AUR, read-only.

`checkupdates` (pacman-contrib) syncs a throwaway copy of the database, so its
answer is current without touching pacman's own. Without it, `pacman -Qu`
reports against the last sync. The report says which one answered.

Foreign packages are looked up over the AUR RPC in batches and compared with
`vercmp`; offline, the AUR part is left out. Upgrades run in a terminal, never
from here. With no pacman at all the result is unavailable and the module is
hidden.
"""

import json
import os
import shutil
import subprocess
import sys
import urllib.parse
import urllib.request

# How many names ride along for the module's one line; the panel reads the
# whole list from `updates`.
LISTED = 15

AUR_RPC = "https://aur.archlinux.org/rpc/v5/info"
AUR_TIMEOUT = 8
# Names per RPC request. The query string carries them all, and a few
# hundred long ones is past what a URL should be asked to hold.
AUR_BATCH = 150

ENV = dict(os.environ, LANG="C", LC_ALL="C")


def run(command, timeout=120):
    try:
        return subprocess.run(command, capture_output=True, text=True,
                              timeout=timeout, env=ENV)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"{command[0]} failed: {error}", file=sys.stderr)
        return None


def parse(text, source):
    """'linux 6.9-1 -> 6.10-1' is the package, what it is, what it will be."""
    rows = []
    for line in text.splitlines():
        parts = line.split()
        if len(parts) >= 4 and parts[2] == "->":
            rows.append({"name": parts[0], "from": parts[1],
                         "to": parts[3], "source": source})
    return rows


def repositories():
    if shutil.which("checkupdates"):
        result = run(["checkupdates", "--nocolor"])
        # 2 is checkupdates for "no updates", which is an answer, not an error.
        if result is not None and result.returncode in (0, 2):
            return "checkupdates", parse(result.stdout, "repo")
        if result is not None:
            print(result.stderr.strip(), file=sys.stderr)

    if shutil.which("pacman"):
        result = run(["pacman", "-Qu"])
        # 1 with a silent stderr is pacman's "nothing to report".
        if result is not None and (result.returncode == 0
                                   or (result.returncode == 1
                                       and not result.stderr.strip())):
            return "pacman", parse(result.stdout, "repo")

    return None, None


def newer(candidate, installed):
    result = run(["vercmp", candidate, installed], timeout=5)
    try:
        return result is not None and int(result.stdout.strip()) > 0
    except ValueError:
        return False


def aur():
    """Foreign packages with a newer version on the AUR, or None offline."""
    result = run(["pacman", "-Qm"])
    if result is None or result.returncode not in (0, 1):
        return []
    mine = dict(line.split()[:2] for line in result.stdout.splitlines()
                if len(line.split()) >= 2)
    if not mine:
        return []

    remote = {}
    names = sorted(mine)
    try:
        for start in range(0, len(names), AUR_BATCH):
            query = urllib.parse.urlencode(
                [("arg[]", name) for name in names[start:start + AUR_BATCH]])
            request = urllib.request.Request(f"{AUR_RPC}?{query}",
                                             headers={"User-Agent": "impasto"})
            with urllib.request.urlopen(request, timeout=AUR_TIMEOUT) as answer:
                for row in json.load(answer).get("results", []):
                    remote[row.get("Name", "")] = row.get("Version", "")
    except (OSError, ValueError) as error:
        print(f"The AUR did not answer: {error}", file=sys.stderr)
        return None

    # A foreign package the AUR has never heard of is a local build, and
    # there is nothing to compare it with.
    return [{"name": name, "from": mine[name], "to": remote[name],
             "source": "aur"}
            for name in names
            if remote.get(name) and remote[name] != mine[name]
            and newer(remote[name], mine[name])]


def main():
    tool, rows = repositories()
    if rows is None:
        print("Neither checkupdates nor pacman answered", file=sys.stderr)
        print(json.dumps({"available": False}))
        return

    remote = aur()
    updates = rows + (remote or [])
    print(json.dumps({
        "available": True,
        "tool": tool,
        "aur": remote is not None,
        "count": len(updates),
        "packages": [row["name"] for row in updates[:LISTED]],
        "updates": updates,
    }))


if __name__ == "__main__":
    main()
