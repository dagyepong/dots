#!/usr/bin/env python3
# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   P A C K A G E S                                                        │
# │   package queries · pacman and the aur, read only                        │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Read the package database and search the repositories and the AUR.

    installed        every installed package, with its description, install
                     reason and whether it is foreign, plus the AUR helper
    search TERM      packages whose name contains TERM, from the sync
                     databases and the AUR, ranked exact, prefix, substring

Read-only: installing and upgrading run in a terminal, where pacman can ask
for a password and confirmation. The AUR is searched over its RPC; a term the
RPC rejects as too broad is retried as a prefix through `suggest`. Offline,
the AUR part is null and the repositories still answer.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import threading
import urllib.parse
import urllib.request

AUR_RPC = "https://aur.archlinux.org/rpc/v5"
AUR_TIMEOUT = 8

# Maximum rows returned by a search.
LISTED = 160

# Supported AUR helpers, in order of preference. `setup` builds yay-bin when
# neither is installed.
HELPERS = ("yay", "paru")

ENV = dict(os.environ, LANG="C", LC_ALL="C")


def run(command):
    try:
        return subprocess.run(command, capture_output=True, text=True,
                              timeout=60, env=ENV)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"{command[0]} failed: {error}", file=sys.stderr)
        return None


def helper():
    return next((name for name in HELPERS if shutil.which(name)), "")


def foreign():
    """Names installed from outside the sync databases — the AUR, mostly."""
    result = run(["pacman", "-Qqm"])
    if result is None or result.returncode not in (0, 1):
        return set()
    return set(result.stdout.split())


# ── INSTALLED ───────────────────────────────────────────────────────────────


def installed():
    result = run(["pacman", "-Qi"])
    if result is None or result.returncode != 0:
        print(json.dumps({"available": False}))
        return

    aur = foreign()
    packages = []
    entry = {}
    field = ""
    for line in result.stdout.splitlines() + [""]:
        if not line.strip():
            if entry.get("Name"):
                packages.append({
                    "name": entry["Name"],
                    "version": entry.get("Version", ""),
                    "description": entry.get("Description", ""),
                    "size": entry.get("Installed Size", ""),
                    "explicit": entry.get("Install Reason", "").startswith("Explicitly"),
                    "aur": entry["Name"] in aur,
                })
            entry = {}
            field = ""
            continue
        if line.startswith(" ") and field:
            # A value that wraps continues on an indented line.
            entry[field] = f"{entry[field]} {line.strip()}"
            continue
        key, _, value = line.partition(":")
        field = key.strip()
        entry[field] = value.strip()

    print(json.dumps({
        "available": True,
        "helper": helper(),
        "packages": packages,
    }))


# ── SEARCH ──────────────────────────────────────────────────────────────────


def rank(name, term):
    """0 exact, 1 prefix, 2 anywhere in the name."""
    if name == term:
        return 0
    return 1 if name.startswith(term) else 2


def repositories(term, into):
    # `pacman -Ss` takes a regular expression and also matches descriptions,
    # so the term is escaped and the results are filtered by name here.
    result = run(["pacman", "-Ss", "--", re.escape(term)])
    found = []
    if result is not None and result.returncode == 0:
        head = None
        for line in result.stdout.splitlines():
            if not line.startswith(" "):
                # extra/firefox 142.0-1 (group) [installed: 141.0-1]
                parts = line.split(" ")
                repo, _, name = parts[0].partition("/")
                head = {
                    "name": name,
                    "version": parts[1] if len(parts) > 1 else "",
                    "source": repo,
                    "installed": "[installed" in line,
                    "description": "",
                }
                found.append(head)
            elif head is not None:
                head["description"] = line.strip()
    into["repos"] = [row for row in found if term in row["name"].lower()]


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "impasto"})
    with urllib.request.urlopen(request, timeout=AUR_TIMEOUT) as response:
        return json.load(response)


def aur(term, into):
    quoted = urllib.parse.quote(term, safe="")
    try:
        answer = fetch(f"{AUR_RPC}/search/{quoted}?by=name")
        prefix = False
        if answer.get("type") == "error":
            # Too many results: ask for the names that START with it, which
            # the RPC answers in order, and then for their details.
            names = fetch(f"{AUR_RPC}/suggest/{quoted}")
            prefix = True
            if not names:
                into["aur"] = []
                into["aurNote"] = "prefix"
                return
            query = urllib.parse.urlencode([("arg[]", name) for name in names])
            answer = fetch(f"{AUR_RPC}/info?{query}")
    except (OSError, ValueError) as error:
        print(f"The AUR did not answer: {error}", file=sys.stderr)
        into["aur"] = None
        return

    mine = foreign()
    into["aur"] = [{
        "name": row.get("Name", ""),
        "version": row.get("Version", ""),
        "source": "aur",
        "installed": row.get("Name", "") in mine,
        "description": row.get("Description") or "",
        "votes": row.get("NumVotes", 0),
        "popularity": row.get("Popularity", 0),
        "outOfDate": row.get("OutOfDate") is not None,
    } for row in answer.get("results", [])]
    into["aurNote"] = "prefix" if prefix else ""


def search(term):
    term = term.strip().lower()
    if len(term) < 2:
        # The RPC rejects single-character terms.
        print(json.dumps({"term": term, "results": [], "aur": "short"}))
        return

    found = {}
    threads = [threading.Thread(target=repositories, args=(term, found)),
               threading.Thread(target=aur, args=(term, found))]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()

    repos = found.get("repos", [])
    remote = found.get("aur")
    # A name in both is the repository's: that is the one pacman installs.
    taken = {row["name"] for row in repos}
    remote_rows = [row for row in (remote or []) if row["name"] not in taken]

    # Match quality first, whichever the source, so `hyprland` ranks above
    # repository packages that merely contain it. Within a tier the
    # repositories lead, and AUR results follow by popularity.
    rows = sorted(repos + remote_rows, key=lambda row: (
        rank(row["name"], term),
        row["source"] == "aur",
        -row.get("popularity", 0),
        row["name"],
    ))

    print(json.dumps({
        "term": term,
        "results": rows[:LISTED],
        "total": len(rows),
        "repos": len(repos),
        "aurCount": len(remote_rows),
        "aur": "offline" if remote is None else (found.get("aurNote") or "ok"),
    }))


def main():
    verb = sys.argv[1] if len(sys.argv) > 1 else ""
    if verb == "installed":
        installed()
    elif verb == "search" and len(sys.argv) > 2:
        search(" ".join(sys.argv[2:]))
    else:
        print("usage: packages.py installed | search TERM", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
