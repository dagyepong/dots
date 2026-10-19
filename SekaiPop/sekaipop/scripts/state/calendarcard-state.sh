#!/bin/sh

# Helper for CalendarCardService.qml: remembers the desktop calendar card's
# events, position and on / off, so a shell restart brings it back exactly as
# you left it.
#
#   calendarcard-state.sh save <json>   replace the remembered state with <json>
#   calendarcard-state.sh load          print the remembered JSON (or nothing at
#                                       all, if the card has never been used)
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/calendarcard.json — state,
# not data, same convention todo-state.sh / weathercard-state.sh use. The JSON
# is passed as one real argv entry (not a shell string), so whatever you type
# into an event never has to be quoted. Written to a temp file and moved into
# place, so a crash mid-save can't leave half a file behind. The events are
# yours: this file is never cleaned up behind your back.

mode="$1"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/calendarcard.json"

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
