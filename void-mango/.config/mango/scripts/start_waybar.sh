#!/bin/sh

while ! pgrep -x "mango" > /dev/null; do
    sleep 1
done

sleep 1

if ! pgrep -x "waybar" > /dev/null; then
    waybar --log-level error \
        --config "$HOME/.config/sway/waybar/config.jsonc" \
        --style "$HOME/.config/sway/waybar/style.css" &
fi
