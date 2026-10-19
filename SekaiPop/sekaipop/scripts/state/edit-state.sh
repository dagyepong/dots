#!/bin/sh

# Helper for EditMode.qml: remembers Edit Desktop's "Lock all" switch, so a
# shell restart brings it back as you left it.
#
#   edit-state.sh save <json>   replace the remembered state with <json>
#   edit-state.sh load          print the remembered JSON (or nothing at all,
#                               if the switch has never been touched)
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/edit.json — state, not
# data, same convention clock-state.sh / todo-state.sh use. Written to a temp
# file and moved into place, so a crash mid-save can't leave half a file.

mode="$1"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/edit.json"

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
