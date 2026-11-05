#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   N E T W O R K                                                          │
# │   wifi listing and connection, through nmcli                             │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Wi-Fi networks in range, and connecting to them.

Quickshell's Networking module reports devices and connection state but not
signal strength, so the list comes from nmcli. Terse mode with the fields named
is used everywhere: nmcli's table output is translated and its column order is
not the documented one.
"""

import json
import shutil
import subprocess
import sys


def nmcli(*arguments, timeout=25):
    if not shutil.which("nmcli"):
        return None
    try:
        result = subprocess.run(
            ["nmcli", *arguments], capture_output=True, text=True, timeout=timeout,
        )
    except (OSError, subprocess.SubprocessError) as error:
        sys.stderr.write(f"nmcli failed: {error}\n")
        return None
    return result if result.returncode == 0 else None


def split_terse(line):
    """Split a terse row on unescaped colons.

    An SSID may contain a colon, which nmcli escapes as `\\:`; splitting
    naively would tear such a name in half and shift every later field.
    """
    fields, current, escaped = [], "", False
    for character in line:
        if escaped:
            current += character
            escaped = False
        elif character == "\\":
            escaped = True
        elif character == ":":
            fields.append(current)
            current = ""
        else:
            current += character
    fields.append(current)
    return fields


def known_networks():
    result = nmcli("-t", "-f", "NAME,TYPE", "connection", "show")
    if result is None:
        return set()
    names = set()
    for line in result.stdout.splitlines():
        fields = split_terse(line)
        if len(fields) >= 2 and "wireless" in fields[1]:
            names.add(fields[0])
    return names


def networks():
    result = nmcli("-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list")
    if result is None:
        return []

    known = known_networks()
    best = {}
    for line in result.stdout.splitlines():
        fields = split_terse(line)
        if len(fields) < 4:
            continue
        in_use, ssid, signal, security = fields[0], fields[1], fields[2], fields[3]
        if not ssid:
            continue
        try:
            strength = int(signal)
        except ValueError:
            strength = 0

        entry = {
            "ssid": ssid,
            "signal": strength,
            "secure": security.strip() not in ("", "--"),
            "active": in_use.strip() == "*",
            "known": ssid in known,
        }
        # A network appears once per band and access point, so the sightings
        # are merged, keeping the best signal. Flags are ORed: the associated
        # access point is often the weaker one, and dropping its `*` would
        # show a connected network as disconnected.
        if ssid not in best:
            best[ssid] = entry
        else:
            merged = best[ssid]
            merged["signal"] = max(merged["signal"], strength)
            merged["active"] = merged["active"] or entry["active"]
            merged["secure"] = merged["secure"] or entry["secure"]

    return sorted(best.values(), key=lambda n: (not n["active"], -n["signal"]))


def connect(ssid, password=None):
    arguments = ["device", "wifi", "connect", ssid]
    if password:
        arguments += ["password", password]
    # Association plus a DHCP lease can outlast the default timeout, and
    # killing nmcli does not cancel the activation, it only loses the result.
    # nmcli itself waits 90 s; 60 is enough without hanging on a wrong password.
    return nmcli(*arguments, timeout=60) is not None


def main():
    if len(sys.argv) < 2:
        sys.stderr.write("Usage: network.py list | connect <ssid> [password] | disconnect <ssid> | forget <ssid>\n")
        sys.exit(1)

    action = sys.argv[1]
    argument = sys.argv[2] if len(sys.argv) >= 3 else None

    if action == "list":
        print(json.dumps(networks()))
    elif action == "rescan":
        nmcli("device", "wifi", "rescan")
        print(json.dumps(networks()))
    elif action == "connect" and argument:
        password = sys.argv[3] if len(sys.argv) >= 4 else None
        sys.exit(0 if connect(argument, password) else 1)
    elif action == "disconnect" and argument:
        sys.exit(0 if nmcli("connection", "down", "id", argument) is not None else 1)
    elif action == "forget" and argument:
        sys.exit(0 if nmcli("connection", "delete", "id", argument) is not None else 1)
    else:
        sys.stderr.write(f"Unknown action: {action}\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
