#!/bin/bash
# ~/.config/hypr/scripts/prev-theme.sh

STATE_FILE="$HOME/.config/hypr/theme-state"
[ -f "$STATE_FILE" ] || echo "1" > "$STATE_FILE"
CURRENT_THEME=$(cat "$STATE_FILE")

# Load theme configurations
source ~/.config/hypr/scripts/theme-rotator.sh 2>/dev/null || {
    echo "Error: theme-rotator.sh not found"
    exit 1
}

# Previous theme
if [ $CURRENT_THEME -eq 1 ]; then
    PREV_THEME=${#themes[@]}
else
    PREV_THEME=$((CURRENT_THEME - 1))
fi

apply_theme $((PREV_THEME - 1))
