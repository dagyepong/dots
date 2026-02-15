#!/bin/bash
# ~/.config/hypr/scripts/next-theme.sh

STATE_FILE="$HOME/.config/hypr/theme-state"
[ -f "$STATE_FILE" ] || echo "1" > "$STATE_FILE"
CURRENT_THEME=$(cat "$STATE_FILE")

# Load theme configurations from rotator script
source ~/.config/hypr/scripts/theme-rotator.sh 2>/dev/null || {
    echo "Error: theme-rotator.sh not found"
    exit 1
}

# Next theme
NEXT_THEME=$((CURRENT_THEME % ${#themes[@]} + 1))
apply_theme $((NEXT_THEME - 1))
