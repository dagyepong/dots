#!/bin/bash

# Kill existing dunst instances
pkill dunst

# Wait a moment
sleep 0.5

# Launch dunst with cyberpunk theme
dunst -config ~/.config/dunst/dunstrc &

echo "Dunst launched with Cyberpunk Neon theme"
