#!/bin/sh

# Clean old logs (older than 7 days)
find ~/.local/share/waybar/ -type f -name 'waybar-*.log' -mtime +7 -delete

# Start Waybar with timestamped log log-level error,trace,?
waybar --log-level error \
  --config ~/.config/mango/waybar/config.jsonc \
  --style ~/.config/mango/waybar/style.css \
  > ~/.local/share/waybar/waybar-$(date '+%Y-%m-%d_%H-%M-%S').log 2>&1 &