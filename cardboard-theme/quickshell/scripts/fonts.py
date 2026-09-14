#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   F O N T S                                                              │
# │   installed typefaces, split into monospace and the rest                 │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""List the installed font families, split into monospace and the rest.

The settings window offers only families that exist: Qt silently falls back
for a family name that is not installed.
"""

import json
import shutil
import subprocess
import sys


def families(spacing=None):
    """Family names from fontconfig, deduplicated and sorted.

    `spacing=100` is fontconfig's constant for monospace.
    """
    if not shutil.which("fc-list"):
        return []

    pattern = ":spacing=100" if spacing == 100 else ":"
    try:
        result = subprocess.run(
            ["fc-list", pattern, "family"],
            capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.SubprocessError) as error:
        sys.stderr.write(f"fc-list failed: {error}\n")
        return []

    names = set()
    for line in result.stdout.splitlines():
        # fc-list prints comma-separated aliases; the first is the canonical
        # one.
        name = line.split(",")[0].strip()
        if name:
            names.add(name)
    return sorted(names, key=str.lower)


if __name__ == "__main__":
    mono = families(spacing=100)
    monoset = set(mono)
    print(json.dumps({
        "mono": mono,
        "sans": [name for name in families() if name not in monoset],
    }))
