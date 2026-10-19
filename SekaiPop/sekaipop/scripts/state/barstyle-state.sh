#!/bin/sh

# Helper for BarStyleService.qml: remembers which bar style was picked
# (float / straight / transparent / capsule), so a shell restart keeps it instead
# of going back to Float.
#
#   barstyle-state.sh save <name>   remember this style name
#   barstyle-state.sh load          print the remembered name (or nothing
#                                   at all, if none is saved yet)
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/bar-style — state,
# not data, same convention wallpaper-state.sh and pinned-apps-state.sh
# use.

mode="$1"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/bar-style"

case "$mode" in
    save)
        name="$2"
        [ -n "$name" ] || exit 2
        mkdir -p "$dir" || exit 1
        printf '%s\n' "$name" > "$file.tmp" || exit 1
        mv "$file.tmp" "$file"
        ;;
    load)
        [ -f "$file" ] && cat "$file"
        exit 0
        ;;
    *)
        echo "usage: $0 save <name>|load" >&2
        exit 2
        ;;
esac
