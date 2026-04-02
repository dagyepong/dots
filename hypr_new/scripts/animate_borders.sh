#!/bin/bash
# ~/.config/hypr/scripts/animate_borders.sh

while true; do
    # Cycle through rainbow colors
    hyprctl keyword general:col.active_border "rgba(ff0000ff) rgba(ff9900ff) rgba(ffff00ff) rgba(00ff00ff) rgba(00ffffff) rgba(0000ffff) rgba(9900ffff) rgba(ff00ffff)"
    sleep 0.5
    hyprctl keyword general:col.active_border "rgba(ff00ffff) rgba(ff0000ff) rgba(ff9900ff) rgba(ffff00ff) rgba(00ff00ff) rgba(00ffffff) rgba(0000ffff) rgba(9900ffff)"
    sleep 0.5
    hyprctl keyword general:col.active_border "rgba(9900ffff) rgba(ff00ffff) rgba(ff0000ff) rgba(ff9900ff) rgba(ffff00ff) rgba(00ff00ff) rgba(00ffffff) rgba(0000ffff)"
    sleep 0.5
    # Continue cycling...
done
