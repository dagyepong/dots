#!/bin/sh

# Helper for ImageService.qml: remembers the Custom Image widget's pictures (which
# file, where, how big, how it is cropped and dressed), so a shell restart
# brings every one of them back exactly as you left it.
#
#   image-state.sh save <json>   replace the remembered state with <json>
#   image-state.sh load          print the remembered JSON (or nothing at all, if
#                                no picture has ever been added)
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/images.json — state, not
# data, same convention usercard-state.sh uses. (The pictures themselves are
# copies kept in ~/.local/share/sekaipop/custom-images/, see
# scripts/images/pick-custom-image.sh.) Written to a temp file and moved into
# place, so a crash mid-save can't leave half a file.

mode="$1"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/images.json"

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
