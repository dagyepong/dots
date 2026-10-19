#!/bin/sh

# Helper for TodoService.qml: remembers the desktop To-Do widget's tasks,
# position and lock state, so a shell restart brings it back exactly as
# you left it.
#
#   todo-state.sh save <json>   replace the remembered state with <json>
#   todo-state.sh load          print the remembered JSON (or nothing at
#                               all, if the widget has never been used)
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/todo.json — state, not
# data, same convention pinned-apps-state.sh / wallpaper-state.sh use. The
# JSON is passed as one real argv entry (not a shell string), so whatever
# you type into a task never has to be quoted. Written to a temp file and
# moved into place, so a crash mid-save can't leave half a file behind.

mode="$1"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/todo.json"

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
