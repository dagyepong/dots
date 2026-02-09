#!/bin/bash
# ~/.config/hypr/scripts/set-theme.sh

if [ -z "$1" ]; then
    echo "Usage: $0 <theme_number>"
    exit 1
fi

STATE_FILE="$HOME/.config/hypr/theme-state"
[ -f "$STATE_FILE" ] || echo "1" > "$STATE_FILE"

# Load theme configurations
source ~/.config/hypr/scripts/theme-rotator.sh 2>/dev/null || {
    echo "Error: theme-rotator.sh not found"
    exit 1
}

# Validate theme number
if [ "$1" -lt 1 ] || [ "$1" -gt ${#themes[@]} ]; then
    echo "Error: Theme number must be between 1 and ${#themes[@]}"
    exit 1
fi

# Apply selected theme
apply_theme $(($1 - 1))
