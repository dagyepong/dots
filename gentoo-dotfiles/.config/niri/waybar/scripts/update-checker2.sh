#!/bin/bash

# Cache paths
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-updates.txt"
LAST_CHECK="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-updates-last.txt"
NOTIFY_FLAG="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-updates-notified"

check_updates() {
    emerge -pvuDN --with-bdeps=y @world | awk '/^\[ebuild/ { print $4 }' > "$CACHE"
    date '+%I:%M:%S' > "$LAST_CHECK"
}

# Update cache if older than 10 minutes
if [[ ! -f "$CACHE" || $(find "$CACHE" -mmin +10) ]]; then
    check_updates
    wait
fi

# Read cached data
if [[ -f "$CACHE" && -s "$CACHE" ]]; then
    UPDATES=$(<"$CACHE")
else
    UPDATES=""
fi
[[ -f "$LAST_CHECK" ]] && LAST=$(<"$LAST_CHECK") || LAST="unknown"

# Count update lines
count=$(echo "$UPDATES" | grep -c .)

# Notify if updates found and not already notified
if [ "$count" -gt 0 ] && [ ! -f "$NOTIFY_FLAG" ]; then
    notify-send " Gentoo Updates Available" "$(echo "$UPDATES" | head -n 5; [ "$count" -gt 5 ] && echo "…and $((count - 5)) more.")"
    touch "$NOTIFY_FLAG"
elif [ "$count" -eq 0 ]; then
    rm -f "$NOTIFY_FLAG"
fi

# Output for Waybar
if [ "$count" -eq 0 ]; then
    echo "{\"text\": \"\", \"tooltip\": \"System is up to date. Last checked: $LAST\"}"
else
    tooltip="Updates available:\n"
    i=0
    max_display=5
    while read -r pkg; do
        tooltip+="• $pkg\n"
        ((i++))
        [ "$i" -eq "$max_display" ] && break
    done <<< "$UPDATES"

    if [ "$count" -gt "$max_display" ]; then
        tooltip+="…and $((count - max_display)) more.\n"
    fi

    tooltip+="\nLast checked: $LAST"

    # Output JSON with actual newlines preserved
    printf '{"text": " %s", "tooltip": "%s"}' "$count" "$tooltip"
fi