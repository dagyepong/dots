#!/bin/bash
if pgrep -x "Discord" > /dev/null; then
    pkill Discord
else
    discord &
fi
