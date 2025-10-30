#!/usr/bin/bash

killall -q waybar

while pgrep -x waybar >/dev/null; do sleep 1; done

waybar --config=/home/ron/.config/dwl-v0.7/waybar/config.jsonc \
       --style=/home/ron/.config/dwl-v0.7/waybar/style.css \
       &> /tmp/waybar.log &

sleep 2

if pgrep -x waybar >/dev/null; then
    notify-send "waybar Restarted" "waybar was restarted successfully."
else
    notify-send "waybar Error" "Failed to restart Waybar. Check /tmp/waybar.log for details."
fi
