#!/bin/sh

# Helper for ClockService.qml: remembers the desktop clock widget's
# position, lock state, visibility and 12h / 24h choice, so a shell restart
# brings it back exactly as you left it.
#
#   clock-state.sh save <json>   replace the remembered state with <json>
#   clock-state.sh load          print the remembered JSON (or nothing at
#                                all, if the widget has never been used)
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/clock.json — state, not
# data, same convention todo-state.sh / wallpaper-state.sh use. Written to a
# temp file and moved into place, so a crash mid-save can't leave half a file.

mode="$1"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/clock.json"

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
