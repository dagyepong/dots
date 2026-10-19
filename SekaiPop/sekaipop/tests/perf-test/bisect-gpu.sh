#!/bin/bash
# Which shell surface keeps Hyprland busy? Hides the dock and the bar one at a time through the
# shell's own settings IPC and measures Hyprland's GPU share each time. Puts both back at the end.
#
#   cd ~/.config/quickshell/sekaipop && bash tests/perf-test/bisect-gpu.sh [seconds per step, default 15]
#
# Leave the mouse and keyboard alone while it runs; no media playing.
secs=${1:-15}
here=$(cd "$(dirname "$0")" && pwd)
qs() { command qs -c sekaipop ipc call "$@" >/dev/null 2>&1; }
measure() {  # label
    local r; r=$(python3 "$here/gpu-attribution.py" "$secs" | awk '/Hyprland/{h=$1} /qs /{q=$1} END{printf "Hyprland %s %%   qs %s %%", h+0, q+0}')
    printf '%-28s %s\n' "$1" "$r"
}
restore() { qs options set dock.visible true; qs options set bar.visible true; }
trap restore EXIT

measure "everything on"
qs options set dock.visible false; sleep 3; measure "dock hidden"
qs options set bar.visible false;  sleep 3; measure "dock + bar hidden"
qs options set dock.visible true;  sleep 3; measure "bar hidden, dock on"
