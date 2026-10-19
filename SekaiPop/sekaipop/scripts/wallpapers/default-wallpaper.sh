#!/bin/sh

# Helper for shell.qml: the wallpaper that ships with the shell, for a first run.
#
#   default-wallpaper.sh seed <bundled-file> <wallpaper-folder>
#
# Copies the bundled picture into the wallpaper folder (the one the picker
# lists, ~/Pictures/Wallpapers by default) so it shows up in the picker with a
# thumbnail like any other wallpaper, and prints the path to use. An existing
# copy is never overwritten (you may have edited or renamed over it). If the
# folder can't be made or written to, it prints the bundled file's own path
# instead, so the desktop still gets a wallpaper. Prints nothing (exit 1) only
# when the bundled file itself is missing.

mode="$1"

case "$mode" in
    seed)
        src="$2"
        dir="$3"
        [ -f "$src" ] || exit 1
        name=$(basename "$src")
        if [ -n "$dir" ] && mkdir -p "$dir" 2>/dev/null; then
            if [ -f "$dir/$name" ]; then
                printf '%s' "$dir/$name"
                exit 0
            fi
            # Copied under a temp name and moved into place, so the folder
            # watcher never sees (and the picker never lists) half a picture.
            if cp "$src" "$dir/.$name.tmp" 2>/dev/null && mv "$dir/.$name.tmp" "$dir/$name" 2>/dev/null; then
                printf '%s' "$dir/$name"
                exit 0
            fi
            rm -f "$dir/.$name.tmp" 2>/dev/null
        fi
        printf '%s' "$src"
        ;;
    *)
        echo "usage: $0 seed <bundled-file> <wallpaper-folder>" >&2
        exit 2
        ;;
esac
