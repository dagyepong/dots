#!/bin/sh
# Play an alert (if the system sound theme is installed)
for f in /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga \
         /usr/share/sounds/freedesktop/stereo/complete.oga \
         /usr/share/sounds/freedesktop/stereo/bell.oga; do
    if [ -f "$f" ]; then
        pw-play "$f" 2>/dev/null || paplay "$f" 2>/dev/null
        exit 0
    fi
done
