#!/bin/sh

# Helper for QuickSource.qml: remembers which buttons are on the Quick
# Panel, in what order and at what size (edit mode), so a shell restart
# keeps your layout instead of starting back at the default.
#
#   qp-tiles-state.sh save <id> <size> [<id> <size> ...]
#                                   replace the remembered layout with
#                                   exactly these pairs, in this order
#                                   (no pairs = an empty panel). The file
#                                   starts with a "#v2" format line.
#                                   One extra pair is stored the same way:
#                                   "@columns <1-5>" — how many buttons a row
#                                   may hold (edit mode's Columns setting).
#   qp-tiles-state.sh load          print one "<id><TAB><size>" line per
#                                   button — nothing at all if a layout
#                                   was never saved (the shell then uses
#                                   its default). An empty-but-saved
#                                   layout prints "-". Output includes the
#                                   "#v2" line.
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/qp-tiles — state,
# not data, same convention as pinned-apps-state.sh next to this one.

mode="$1"
shift
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/qp-tiles"

case "$mode" in
    save)
        mkdir -p "$dir" || exit 1
        # First line is a format marker: QuickSource ignores a file that
        # doesn't start with the current one (an older layout, from before
        # Microphone / Speaker joined the grid) and uses the default.
        printf '#v2\n' > "$file.tmp" || exit 1
        if [ "$#" -lt 2 ]; then
            echo "-" >> "$file.tmp"
        fi
        while [ "$#" -ge 2 ]; do
            printf '%s\t%s\n' "$1" "$2" >> "$file.tmp"
            shift 2
        done
        mv "$file.tmp" "$file"
        ;;
    load)
        [ -f "$file" ] && cat "$file"
        exit 0
        ;;
    *)
        echo "usage: $0 save <id> <size> [...]|load" >&2
        exit 2
        ;;
esac
