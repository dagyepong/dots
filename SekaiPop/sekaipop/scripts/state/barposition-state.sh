#!/bin/sh

# Helper for BarPositionService.qml: remembers which screen edge the bar
# was put on (top / right / bottom / left), so a shell restart keeps it.
#
#   barposition-state.sh save <name>   remember this edge
#   barposition-state.sh load          print the remembered edge (or nothing
#                                      at all, if none is saved yet)
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/bar-position — same
# place and same idea as barstyle-state.sh.

mode="$1"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/bar-position"

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
