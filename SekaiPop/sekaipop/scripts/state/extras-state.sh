#!/bin/sh

# Helper for ExtrasSource.qml: remembers the emoji picker's "recent" row
# across shell restarts.
#
#   extras-state.sh save-emoji <emoji> [<emoji> ...]   replace the list
#   extras-state.sh load-emoji                         print it, one per line
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/recent-emoji -- state,
# same place wallpaper-state.sh and pinned-apps-state.sh keep theirs.
# Emoji are passed as real argv entries, so nothing needs quoting.

mode="$1"
shift
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/recent-emoji"

case "$mode" in
    save-emoji)
        mkdir -p "$dir" || exit 1
        : > "$file.tmp" || exit 1
        for e in "$@"; do
            printf '%s\n' "$e" >> "$file.tmp"
        done
        mv "$file.tmp" "$file"
        ;;
    load-emoji)
        [ -f "$file" ] && cat "$file"
        exit 0
        ;;
    *)
        echo "usage: $0 save-emoji <emoji>...|load-emoji" >&2
        exit 2
        ;;
esac
