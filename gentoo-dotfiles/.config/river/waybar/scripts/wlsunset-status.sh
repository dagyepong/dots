#!/bin/bash

# Check if wlsunset is running 󰛨 󱩌 󰹏 
if pgrep -x "wlsunset" > /dev/null; then
    # If running, show an active lightbulb icon
    echo '{"text": "󰛨", "class": "on"}'
else
    # If not running, show an inactive lightbulb icon 
    echo '{"text": "󰹏", "class": "off"}'
fi
