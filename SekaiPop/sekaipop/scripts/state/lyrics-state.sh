#!/bin/sh

# Helper for LyricsService.qml: remembers the desktop lyrics widget's position,
# visibility and sync nudge, so a shell restart brings it back as you left it.
#
#   lyrics-state.sh save <json>   replace the remembered state with <json>
#   lyrics-state.sh load          print the remembered JSON (or nothing at all, if
#                                 the widget has never been used)
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/lyrics.json: state, not data,
# same convention clock-state.sh / usercard-state.sh use. Written to a temp file and
# moved into place, so a crash mid-save can't leave half a file.

mode="$1"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/lyrics.json"

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
