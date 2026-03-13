#!/bin/bash
# Path: ~/.config/eww/scripts/brightness.sh

# Get the current brightness percentage
brightnessctl info | grep -oP '\d+%' | head -1
