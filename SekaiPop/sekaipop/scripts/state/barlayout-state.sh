#!/bin/sh

# Helper for BarLayoutService.qml: remembers which bar zone (left / center /
# right) every bar module sits in, and in what order, so a shell restart
# brings the bar back exactly as you arranged it.
#
#   barlayout-state.sh save <json>   replace the remembered layout with <json>
#   barlayout-state.sh load          print the remembered JSON (or nothing at
#                                    all, if the bar was never rearranged)
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/bar-layout.json — state,
# not data, same convention settings-state.sh uses. Written to a temp file and
# moved into place, so a crash mid-save can't leave half a file.

mode="$1"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/bar-layout.json"

case "$mode" in
    save)
        mkdir -p "$dir" || exit 1
        printf '%s\n' "$2" > "$file.tmp" || exit 1
        mv "$file.tmp" "$file"
        ;;
    load)
        [ -f "$file" ] && cat "$file"
        exit 0
        ;;
    *)
        echo "usage: $0 save <json>|load" >&2
        exit 2
        ;;
esac
