#!/bin/sh
img="$1"
[ -f "$img" ] || exit 1

if command -v awww >/dev/null 2>&1; then
    bin=awww; daemon=awww-daemon
else
    bin=swww; daemon=swww-daemon
fi

# the daemon only starts if it is not already running
if ! "$bin" query >/dev/null 2>&1; then
    setsid "$daemon" >/dev/null 2>&1 &
    sleep 1
fi

"$bin" img "$img" --transition-type grow --transition-pos center \
    --transition-duration 1.2 --transition-fps 60 &

# pywal updates ~/.cache/wal/colors.json: the shell recolors itself
mode=$(cat "$HOME/.cache/quickshell-theme-mode" 2>/dev/null)
if [ "$mode" = light ]; then wal -i "$img" -n -q -l; else wal -i "$img" -n -q; fi

printf '%s' "$img" > "$HOME/.cache/quickshell-wallpaper-current"

sh "$(dirname "$0")/blur-backdrop.sh" "$img" &
wait
