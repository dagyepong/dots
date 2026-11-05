#!/bin/sh
# Keeps the Firefox colors (Pywalfox) in sync with pywal: every time the
# wallpaper changes (~/.cache/wal/colors.json) it runs `pywalfox update`.
# Started by niri and Hyprland at login. Does nothing if pywalfox/inotifywait are missing.
command -v pywalfox >/dev/null 2>&1 || exit 0
command -v inotifywait >/dev/null 2>&1 || exit 0

# one instance only
lock="${XDG_RUNTIME_DIR:-/tmp}/quickshell-pywalfox.pid"
if [ -f "$lock" ] && kill -0 "$(cat "$lock")" 2>/dev/null; then exit 0; fi
echo $$ > "$lock"

f="$HOME/.cache/wal/colors.json"
mkdir -p "$(dirname "$f")"
pywalfox update >/dev/null 2>&1
while inotifywait -qq -e close_write,moved_to "$(dirname "$f")" --include 'colors\.json'; do
    pywalfox update >/dev/null 2>&1
done
