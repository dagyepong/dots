#!/bin/sh

# Helper for PinnedAppsService.qml: remembers which apps are pinned to
# the dock (Dock.qml), so a shell restart keeps them pinned instead of
# starting back at an empty dock.
#
#   pinned-apps-state.sh save <class> <iconName> [<class> <iconName> ...]
#                                   replace the remembered list with
#                                   exactly these pairs, in this order
#   pinned-apps-state.sh load       print one "<class><TAB><iconName>"
#                                   line per pinned app (or nothing at
#                                   all, if none are pinned yet)
#   pinned-apps-state.sh dock-save <0|1>
#                                   remember whether the dock itself is
#                                   pinned on top of windows
#   pinned-apps-state.sh dock-load  print 0 or 1 (or nothing, if it's
#                                   never been set — treated as 0)
#   pinned-apps-state.sh layout-save <json>
#                                   remember the whole dock layout (apps,
#                                   folders, separators and saved presets)
#                                   as one JSON document
#   pinned-apps-state.sh layout-load
#                                   print that JSON (nothing if never saved)
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/pinned-apps —
# state, not data, same convention wallpaper-state.sh right next to
# this uses for the wallpaper path. Classes/icon names are passed as
# real argv entries (not a shell string), so this never has to worry
# about quoting whatever's in them.

mode="$1"
shift
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/pinned-apps"

case "$mode" in
    save)
        mkdir -p "$dir" || exit 1
        : > "$file" || exit 1
        while [ "$#" -ge 2 ]; do
            printf '%s\t%s\n' "$1" "$2" >> "$file"
            shift 2
        done
        ;;
    load)
        [ -f "$file" ] && cat "$file"
        exit 0
        ;;
    dock-save)
        mkdir -p "$dir" || exit 1
        printf '%s\n' "$1" > "$dir/dock-pinned"
        ;;
    dock-load)
        [ -f "$dir/dock-pinned" ] && cat "$dir/dock-pinned"
        exit 0
        ;;
    layout-save)
        mkdir -p "$dir" || exit 1
        # Written to a temp file first, so a crash can't leave half a layout.
        printf '%s\n' "$1" > "$dir/dock-layout.json.tmp" && mv "$dir/dock-layout.json.tmp" "$dir/dock-layout.json"
        ;;
    layout-load)
        [ -f "$dir/dock-layout.json" ] && cat "$dir/dock-layout.json"
        exit 0
        ;;
    shelf-save)
        mkdir -p "$dir" || exit 1
        printf '%s\n' "$1" > "$dir/dock-shelf.json.tmp" && mv "$dir/dock-shelf.json.tmp" "$dir/dock-shelf.json"
        ;;
    shelf-load)
        [ -f "$dir/dock-shelf.json" ] && cat "$dir/dock-shelf.json"
        exit 0
        ;;
    *)
        echo "usage: $0 save <class> <iconName> [...]|load|dock-save <0|1>|dock-load|layout-save <json>|layout-load|shelf-save <json>|shelf-load" >&2
        exit 2
        ;;
esac
