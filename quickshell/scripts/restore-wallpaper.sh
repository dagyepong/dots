#!/bin/sh
state="$HOME/.cache/quickshell-wallpaper-current"
[ -s "$state" ] || exit 0
img=$(cat "$state")
[ -f "$img" ] || exit 0

if command -v awww >/dev/null 2>&1; then
    bin=awww; daemon=awww-daemon
else
    bin=swww; daemon=swww-daemon
fi

if ! "$bin" query >/dev/null 2>&1; then
    setsid "$daemon" >/dev/null 2>&1 &
    sleep 1
fi

"$bin" img "$img" --transition-type none
wal -R -q
sh "$(dirname "$0")/blur-backdrop.sh" "$img"
