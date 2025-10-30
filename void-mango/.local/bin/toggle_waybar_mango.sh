#!/usr/bin/bash

# Terminate already running bar instances

killall -q waybar

# Wait until the waybar processes have been shut down

while pgrep -x waybar >/dev/null; do sleep 1; done

# Launch main

#waybar --config=/home/ron/.config/mango/waybar/config.jsonc --style=/home/ron/.config/mango/waybar/style.css
/home/ron/.config/mango/scripts/start_waybar2.sh

