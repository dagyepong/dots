#!/bin/bash

if pgrep -x "waybar" > /dev/null; then
    killall -SIGUSR1 waybar
else
    waybar --log-level error --config /home/ron/.config/hypr/waybar/config.jsonc --style /home/ron/.config/hypr/waybar/style.css &
fi

