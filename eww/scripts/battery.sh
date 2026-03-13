#!/bin/bash
battery=BAT1
capacity=$(cat /sys/class/power_supply/$battery/capacity 2>/dev/null)
status=$(cat /sys/class/power_supply/$battery/status 2>/dev/null)

if [ "$1" = "icon" ]; then
    if [ "$status" = "Charging" ]; then
        echo ""   # plug icon (or use  for bolt)
    else
        if [ "$capacity" -ge 80 ]; then
            echo ""  # full battery
        elif [ "$capacity" -ge 60 ]; then
            echo ""
        elif [ "$capacity" -ge 40 ]; then
            echo ""
        elif [ "$capacity" -ge 15 ]; then
            echo ""
        else
            echo ""  # empty
        fi
    fi
elif [ "$1" = "percent" ]; then
    echo "$capacity%"
fi
