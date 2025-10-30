#!/bin/bash

if pgrep -x "wlsunset" > /dev/null; then
    echo '{"text": "󰛨", "class": "on"}'
else
    echo '{"text": "󰹏", "class": "off"}'
fi
