#!/bin/bash
case "$1" in
    up)
        brightnessctl set +5%
        ;;
    down)
        brightnessctl set 5%-
        ;;
esac

# Get current brightness for notification
current=$(brightnessctl info | grep -oP '\d+%')
notify-send "Brightness" "$current" -h string:x-canonical-private-synchronous:brightness
