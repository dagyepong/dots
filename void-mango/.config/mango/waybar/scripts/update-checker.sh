#!/bin/bash

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-updates.txt"
LAST_CHECK="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-updates-last.txt"

check_updates() {
    xbps-install -Mun 2>/dev/null | tee "$CACHE" > /dev/null
    date '+%I:%M:%S' > "$LAST_CHECK"
}

if [[ ! -f "$CACHE" || $(find "$CACHE" -mmin +10) ]]; then
    check_updates &
fi

UPDATES=$(<"$CACHE")
LAST=$(<"$LAST_CHECK")

count=$(echo "$UPDATES" | grep -cE '^[^ ]')

NOTIFY_FLAG="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-updates-notified"

if [ "$count" -gt 0 ] && [ ! -f "$NOTIFY_FLAG" ]; then
    notify-send " System Updates Available" "$(echo "$UPDATES" | head -n 5; [ "$count" -gt 5 ] && echo "…and $((count - 5)) more.")"
    touch "$NOTIFY_FLAG"
elif [ "$count" -eq 0 ]; then
    rm -f "$NOTIFY_FLAG"
fi

if [ "$count" -eq 0 ]; then
    echo "{\"text\": \"\", \"tooltip\": \"System is up to date.\\n\\nLast checked: $LAST\"}"
else
    tooltip="Updates available:\n"
    i=0
    max_display=5
    while read -r pkg; do
        tooltip+="• $pkg\n"
        ((i++))
        [ "$i" -eq "$max_display" ] && break
    done <<< "$UPDATES"

    [ "$count" -gt "$max_display" ] && tooltip+="…and $((count - max_display)) more.\n"
    tooltip+="\nLast checked: $LAST"

    echo "{\"text\": \" $count\", \"tooltip\": \"$tooltip\"}"
fi
