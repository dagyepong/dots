#!/bin/sh

# Helper for PaletteService.qml: remembers the Palette tool's own state, its working
# five colours, which are locked, where they came from, the saved favourites, and
# the theme that was worn before an Apply (for Undo), so a restart brings it all back.
#
#   palette-state.sh save <json>   replace the remembered state with <json>
#   palette-state.sh load          print the remembered JSON (or nothing at all, if
#                                  the tool has never been used)
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/palette.json, state, not data,
# same convention weathercard-state.sh uses. Written to a temp file and moved into
# place, so a crash mid-save can't leave half a file. This file never holds the theme:
# the colours an Apply put on the shell are in `custom-palette` (theme-state.sh).

mode="$1"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/palette.json"

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
