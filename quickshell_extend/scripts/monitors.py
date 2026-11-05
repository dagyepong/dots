#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   M O N I T O R S                                                        │
# │   monitor detection and saved layouts                                    │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Read Hyprland's monitors and apply a display profile to them.

Like `compositor.py`, this never writes `hypr/*.lua`: `modules/monitors.lua`
holds a catch-all default, and the arrangement lives in the shell's settings,
re-applied after every reload and hotplug. Rules go through `hyprctl eval`
(`hyprctl keyword` fails silently with a Lua config); success is "ok" on stdout.

A whole profile is one eval. `position = "auto"` is resolved against the state
the previous statement left, so applying monitors one at a time can move a
screen that was already placed.

Monitors are matched by `desc:<description>` (make, model, serial) rather than
by port, so a screen keeps its settings on another connector. Quickshell's
`ShellScreen.serialNumber` identifies the same screen from the QML side.
"""

import json
import re
import shutil
import subprocess
import sys


# ── RULES ───────────────────────────────────────────────────────────────────
#
# `hl.monitor` rejects unknown fields by name; each field below was checked
# against Hyprland 0.56.2. The patterns guard what reaches `hyprctl eval`: a
# quoted value is safe as long as it has no quote, backslash or newline, and
# every pattern is narrower than that.

# A port name, or an EDID description to match with `desc:`, which can carry
# spaces, dots and brackets: "Samsung Electric Company LC27G5xT HK2W200792".
OUTPUT = re.compile(r"(desc:)?[A-Za-z0-9 ._,:+()\[\]/#-]{1,256}")

# A resolution, or one of the four words Hyprland resolves for itself.
MODE = re.compile(r"\d{1,5}x\d{1,5}(@\d{1,4}(\.\d{1,3})?)?|preferred|highres|highrr|maxwidth")

# A corner, or one of the five ways of asking the compositor to decide.
POSITION = re.compile(r"-?\d{1,5}x-?\d{1,5}|auto(-left|-right|-up|-down)?")

FIELDS = {
    "output":    ("string", OUTPUT),
    "mirror":    ("string", OUTPUT),
    "mode":      ("string", MODE),
    "position":  ("string", POSITION),
    "scale":     ("scale", None),
    "transform": ("range", (0, 7)),
    "vrr":       ("range", (0, 3)),
    "bitdepth":  ("choice", (8, 10)),
    "disabled":  ("bool", None),
}

# Fixed field order, so identical profiles produce identical chunks. `output`
# is the only required field.
ORDER = ("output", "disabled", "mode", "position", "scale",
         "transform", "mirror", "vrr", "bitdepth")

# How `hyprctl monitors` prints an available mode: "2560x1440@144.00Hz".
MODE_LINE = re.compile(r"(\d{1,5})x(\d{1,5})@([\d.]+)Hz")


def hyprctl(*arguments):
    if not shutil.which("hyprctl"):
        return None
    try:
        result = subprocess.run(
            ["hyprctl", *arguments], capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return result if result.returncode == 0 else None


def literal_for(field, value):
    """The Lua literal for one field of a rule, or None if it is invalid."""
    shape = FIELDS.get(field)
    if shape is None:
        return None
    kind, allowed = shape

    # bool is a subclass of int, so the numeric shapes exclude it explicitly.
    numeric = isinstance(value, (int, float)) and not isinstance(value, bool)

    if kind == "bool":
        return "true" if value is True else "false" if value is False else None
    if kind == "range":
        low, high = allowed
        return str(value) if numeric and low <= value <= high else None
    if kind == "choice":
        return str(value) if numeric and value in allowed else None
    if kind == "scale":
        # `auto` lets Hyprland derive the scale from the physical size.
        if numeric and 0.1 <= value <= 10:
            return f"{value:g}"
        return '"auto"' if value == "auto" else None

    text = str(value)
    return f'"{text}"' if allowed.fullmatch(text) else None


def rule_chunk(rule):
    """One `hl.monitor{...}` call, or None if any field is unknown or invalid.

    All or nothing: a rule with a field silently dropped would put a screen
    somewhere it was not meant to go.
    """
    if not isinstance(rule, dict) or "output" not in rule:
        return None
    if any(field not in FIELDS for field in rule):
        return None
    pairs = []
    for field in ORDER:
        if field not in rule:
            continue
        literal = literal_for(field, rule[field])
        if literal is None:
            return None
        pairs.append(f"{field} = {literal}")
    return "hl.monitor({ " + ", ".join(pairs) + " })"


# ── READING ─────────────────────────────────────────────────────────────────
#
# `monitors all`, not `monitors`, so a disabled screen is still listed and can
# be switched back on. A disabled monitor reports zero geometry.


def parse_modes(available):
    """`["2560x1440@144.00Hz", ...]` into rows, deduplicated and ordered.

    Monitors can list the same mode twice, so the mode string is the key.
    """
    seen = {}
    for line in available:
        found = MODE_LINE.fullmatch(str(line).strip())
        if not found:
            continue
        width, height = int(found.group(1)), int(found.group(2))
        refresh = round(float(found.group(3)), 2)
        name = f"{width}x{height}@{refresh:.2f}"
        seen.setdefault(name, {
            "mode": name, "width": width, "height": height, "refresh": refresh,
        })
    return sorted(seen.values(),
                  key=lambda mode: (-(mode["width"] * mode["height"]), -mode["refresh"]))


def group_modes(modes):
    """The modes grouped by resolution, each with the refresh rates it offers."""
    grouped = {}
    for mode in modes:
        grouped.setdefault((mode["width"], mode["height"]), []).append(mode["refresh"])
    return [
        {"width": width, "height": height, "refreshes": sorted(rates, reverse=True)}
        for (width, height), rates in sorted(grouped.items(),
                                             key=lambda row: -(row[0][0] * row[0][1]))
    ]


def described(monitor, names):
    modes = parse_modes(monitor.get("availableModes") or [])
    width = monitor.get("width") or 0
    height = monitor.get("height") or 0
    refresh = monitor.get("refreshRate") or 0.0
    return {
        "name": monitor.get("name") or "",
        "description": monitor.get("description") or "",
        "make": monitor.get("make") or "",
        "model": monitor.get("model") or "",
        "serial": monitor.get("serial") or "",
        "x": monitor.get("x") or 0,
        "y": monitor.get("y") or 0,
        "width": width,
        "height": height,
        "refresh": round(refresh, 2),
        # Same format as `availableModes`, so the current mode is one of the
        # rows.
        "mode": f"{width}x{height}@{refresh:.2f}" if width and height else "preferred",
        "position": f"{monitor.get('x') or 0}x{monitor.get('y') or 0}",
        # Rounded before it is compared with the saved value: hyprctl reports
        # 1.25 as 1.2000000476837158, which would re-apply the profile on
        # every hotplug.
        "scale": round(monitor.get("scale") or 1, 3),
        "transform": monitor.get("transform") or 0,
        "vrr": 1 if monitor.get("vrr") else 0,
        # hyprctl reports the mirrored monitor's id, but a rule names it; the
        # id is resolved to a name so the two compare equal.
        "mirror": names.get(str(monitor.get("mirrorOf")), "none"),
        "disabled": bool(monitor.get("disabled")),
        # Unlike `disabled`, a screen with DPMS off keeps its place in the
        # layout and its workspaces; it is only dark.
        "dpms": bool(monitor.get("dpmsStatus", True)),
        # Lets the shell tell a freshly created empty workspace from one that
        # holds windows.
        "workspace": (monitor.get("activeWorkspace") or {}).get("id", 0),
        "focused": bool(monitor.get("focused")),
        "modes": modes,
        "resolutions": group_modes(modes),
    }


def read():
    result = hyprctl("monitors", "all", "-j")
    if result is None:
        return []
    try:
        payload = json.loads(result.stdout)
    except ValueError:
        return []
    if not isinstance(payload, list):
        return []
    monitors = [monitor for monitor in payload if isinstance(monitor, dict)]
    names = {str(monitor.get("id")): monitor.get("name") or "none"
             for monitor in monitors}
    return [described(monitor, names) for monitor in monitors]


def apply(rules):
    # Disabled monitors first, so the ones staying are never positioned around
    # one that is leaving (`auto` resolves against the previous statement).
    #
    # When the chunk also enables a monitor, enable first: Hyprland does not
    # survive passing through zero enabled outputs (workspaces are stranded and
    # re-enabling from Lua fails), so the lit set must never be empty. A pure
    # disable is safe because the shell never switches off the last lit screen.
    lighting = any(isinstance(rule, dict) and rule.get("disabled") is False
                   for rule in rules)
    darkening = any(isinstance(rule, dict) and rule.get("disabled") is True
                    for rule in rules)
    first_off = not (lighting and darkening)

    def rank(rule):
        off = isinstance(rule, dict) and rule.get("disabled") is True
        if first_off:
            return 0 if off else 1
        return 1 if off else 0

    ordered = sorted(rules, key=rank)

    chunks = []
    for rule in ordered:
        chunk = rule_chunk(rule)
        if chunk is None:
            sys.stderr.write(f"Refusing this monitor rule: {rule!r}\n")
            return 1
        chunks.append(chunk)

    if not chunks:
        return 0

    result = hyprctl("eval", " ".join(chunks))
    # hyprctl exits 0 regardless; only its output says whether it worked.
    if result is None or result.stdout.strip() != "ok":
        sys.stderr.write((result.stdout if result else "hyprctl is not here") + "\n")
        return 1
    return 0


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "get"

    if action == "get":
        print(json.dumps(read()))
    elif action == "apply":
        if len(sys.argv) < 3:
            sys.stderr.write("Usage: monitors.py apply <json array of rules>\n")
            sys.exit(1)
        try:
            rules = json.loads(sys.argv[2])
        except ValueError:
            sys.stderr.write("apply takes a JSON array of monitor rules\n")
            sys.exit(1)
        if not isinstance(rules, list):
            sys.stderr.write("apply takes a JSON array of monitor rules\n")
            sys.exit(1)
        sys.exit(apply(rules))
    else:
        sys.stderr.write("Usage: monitors.py get | apply <json array of rules>\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
