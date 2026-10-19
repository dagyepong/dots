#!/bin/sh

# Helper for QuickSource.qml's Night Light tile: remembers how warm the
# screen goes (Kelvin) and the Automatic schedule across restarts.
#
#   nightlight-state.sh save <kelvin> on|off <from-hour> <to-hour>
#   nightlight-state.sh load      print "<kelvin> <on|off> <from> <to>" on
#                                 one line — nothing at all if never saved
#                                 (the shell then keeps its defaults)
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/nightlight — state,
# not runtime: your intensity and schedule should survive a reboot.
# Written to a temp file and moved into place.

mode="$1"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/nightlight"

case "$mode" in
    save)
        [ "$#" -ge 5 ] || exit 2
        mkdir -p "$dir" || exit 1
        printf '%s %s %s %s\n' "$2" "$3" "$4" "$5" > "$file.tmp" || exit 1
        mv "$file.tmp" "$file"
        ;;
    load)
        [ -f "$file" ] && head -n1 "$file"
        exit 0
        ;;
    *)
        echo "usage: $0 save <kelvin> on|off <from> <to> | load" >&2
        exit 2
        ;;
esac
