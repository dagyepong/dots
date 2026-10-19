#!/bin/sh

# Helper for WallpaperService.qml: remembers which wallpaper path was
# last picked, so a shell restart restores it instead of falling back
# to shell.qml's "first file in the folder" convenience.
#
#   wallpaper-state.sh save <path>   remember this path
#   wallpaper-state.sh load          print the remembered path (or
#                                     nothing at all, if none is saved
#                                     yet — a fresh config, or the
#                                     saved file has since been deleted)
#   wallpaper-state.sh savescreens <name> <path> [<name> <path> ...]
#                                     remember one wallpaper per monitor
#                                     (called with no pairs, it forgets them all)
#   wallpaper-state.sh loadscreens   print them, one "<name><TAB><path>" per line
#
# Per-monitor wallpapers (Settings -> Desktop -> Wallpaper -> One wallpaper per
# monitor) live in a second file, `wallpaper-screens`, next to `wallpaper`. The
# plain `wallpaper` file stays "the default": what every monitor shows when it
# has no wallpaper of its own.
#
# Settings -> Desktop -> Wallpaper -> Separate Lockscreen Wallpaper keeps the same
# two shapes in `lockwallpaper` (the one for every monitor) and
# `lockwallpaper-screens` (one per monitor), so the lockscreen's picks are
# remembered on their own and never touch the desktop's files above. They are
# kept while the option is off (the lockscreen just ignores them then).
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/wallpaper — state,
# not data (contrast pick-image.sh's ~/.local/share/sekaipop/, which
# holds actual copied picture files): this is just a pointer back into
# wherever your real wallpapers already live (WallpaperService.qml's
# `directory`), nothing gets copied or duplicated here.

mode="$1"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/wallpaper"
screens="$dir/wallpaper-screens"
lockfile="$dir/lockwallpaper"
lockscreens="$dir/lockwallpaper-screens"

case "$mode" in
    save)
        path="$2"
        [ -n "$path" ] || exit 2
        mkdir -p "$dir" || exit 1
        printf '%s' "$path" > "$file" || exit 1
        ;;
    load)
        [ -f "$file" ] && cat "$file"
        exit 0
        ;;
    savescreens)
        shift
        mkdir -p "$dir" || exit 1
        tmp="$screens.tmp.$$"
        : > "$tmp" || exit 1
        while [ "$#" -ge 2 ]; do
            [ -n "$1" ] && [ -n "$2" ] && printf '%s\t%s\n' "$1" "$2" >> "$tmp"
            shift 2
        done
        mv "$tmp" "$screens" || exit 1
        ;;
    loadscreens)
        [ -f "$screens" ] && cat "$screens"
        exit 0
        ;;
    savelock)
        path="$2"
        [ -n "$path" ] || exit 2
        mkdir -p "$dir" || exit 1
        printf '%s' "$path" > "$lockfile" || exit 1
        ;;
    loadlock)
        [ -f "$lockfile" ] && cat "$lockfile"
        exit 0
        ;;
    savelockscreens)
        shift
        mkdir -p "$dir" || exit 1
        tmp="$lockscreens.tmp.$$"
        : > "$tmp" || exit 1
        while [ "$#" -ge 2 ]; do
            [ -n "$1" ] && [ -n "$2" ] && printf '%s\t%s\n' "$1" "$2" >> "$tmp"
            shift 2
        done
        mv "$tmp" "$lockscreens" || exit 1
        ;;
    loadlockscreens)
        [ -f "$lockscreens" ] && cat "$lockscreens"
        exit 0
        ;;
    *)
        echo "usage: $0 save <path>|load|savescreens <name> <path>...|loadscreens|savelock <path>|loadlock|savelockscreens <name> <path>...|loadlockscreens" >&2
        exit 2
        ;;
esac
