#!/bin/sh
# Switches light / dark: regenerates the pywal palette from the current wallpaper.
# pywal repaints the open terminals (kitty...) by itself; Firefox follows through
# pywalfox-watch.sh. Does not touch the wallpaper.
# Usage: apply-mode.sh light|dark
mode="$1"
mkdir -p "$HOME/.cache"
printf '%s' "$mode" > "$HOME/.cache/quickshell-theme-mode"

state="$HOME/.cache/quickshell-wallpaper-current"
[ -s "$state" ] || exit 0
img=$(cat "$state")
[ -f "$img" ] || exit 0
command -v wal >/dev/null 2>&1 || exit 0

if [ "$mode" = light ]; then
    wal -i "$img" -n -q -l
else
    wal -i "$img" -n -q
fi
exit 0
