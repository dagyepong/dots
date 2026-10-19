#!/bin/sh

# Helper for QuickSource.qml's Keep Awake tile: remembers whether Keep
# Awake was ON across a Quickshell reload, and clears out any inhibitor
# a previous load left behind, so the tile always matches reality.
#
#   keep-awake-state.sh restore    kill any leftover Keep Awake inhibitor,
#                                  then print "on" if it was ON (or
#                                  nothing at all)
#   keep-awake-state.sh save on|off
#
# Lives in ${XDG_RUNTIME_DIR:-/tmp}/sekaipop/keep-awake — the runtime dir
# (tmpfs), not ~/.local/state, on purpose: a reload keeps it, but logging
# out or rebooting wipes it, so Keep Awake never silently comes back ON in
# a fresh session. Written to a temp file and moved into place.

mode="$1"
dir="${XDG_RUNTIME_DIR:-/tmp}/sekaipop"
file="$dir/keep-awake"

case "$mode" in
    restore)
        # A reload doesn't restart Quickshell itself, so an inhibitor from
        # the previous load can still be alive while the new load thinks
        # Keep Awake is off. Kill it; QuickSource starts a fresh one if
        # the saved state says ON. ([e] keeps this pattern from matching
        # a command line that merely contains the pattern's own text.)
        pkill -f 'sekaipop-keep-awak[e]' 2>/dev/null
        [ -f "$file" ] && cat "$file"
        exit 0
        ;;
    save)
        mkdir -p "$dir" || exit 1
        printf '%s\n' "$2" > "$file.tmp" || exit 1
        mv "$file.tmp" "$file"
        ;;
    *)
        echo "usage: $0 restore|save on|off" >&2
        exit 2
        ;;
esac
