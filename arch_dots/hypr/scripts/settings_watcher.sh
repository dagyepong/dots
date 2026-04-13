#!/usr/bin/env bash

SETTINGS_FILE="$HOME/.config/hypr/settings.json"
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
ZSH_RC="$HOME/.zshrc"

# Ensure the settings file exists before we try to watch it
mkdir -p "$(dirname "$SETTINGS_FILE")"
[ ! -f "$SETTINGS_FILE" ] && echo "{}" > "$SETTINGS_FILE"

echo "Started watching $SETTINGS_FILE for changes..."

# Loop endlessly, triggering only when the file is saved (closed after writing)
while inotifywait -q -e close_write "$SETTINGS_FILE"; do
    echo "Settings updated! Applying changes..."

    # Extract values using jq (raw output to strip quotes)
    LANG=$(jq -r '.language // empty' "$SETTINGS_FILE")
    GUIDE_STARTUP=$(jq -r '.openGuideAtStartup // empty' "$SETTINGS_FILE")
    WP_DIR=$(jq -r '.wallpaperDir // empty' "$SETTINGS_FILE")

    # 1. Update Keyboard Layout
    if [ -n "$LANG" ] && [ "$LANG" != "null" ]; then
        sed -i "s/^ *kb_layout =.*/    kb_layout = $LANG/" "$HYPR_CONF"
    fi

    # 2. Update Guide Autostart (Comment / Uncomment)
    if [ "$GUIDE_STARTUP" == "true" ]; then
        # Remove any leading hash/spaces to enable the autostart
        sed -i 's|^#*[[:space:]]*exec-once = ~/.config/hypr/scripts/qs_manager.sh toggle guide.*|exec-once = ~/.config/hypr/scripts/qs_manager.sh toggle guide \&|' "$HYPR_CONF"
    elif [ "$GUIDE_STARTUP" == "false" ]; then
        # Add a hash to comment it out if it isn't already
        sed -i 's|^exec-once = ~/.config/hypr/scripts/qs_manager.sh toggle guide.*|# exec-once = ~/.config/hypr/scripts/qs_manager.sh toggle guide \&|' "$HYPR_CONF"
    fi

    # 3. Update Wallpaper Directory
    if [ -n "$WP_DIR" ] && [ "$WP_DIR" != "null" ]; then
        # We use '|' as the sed delimiter here to prevent path slashes from breaking the command
        sed -i "s|^env = WALLPAPER_DIR,.*|env = WALLPAPER_DIR,$WP_DIR|" "$HYPR_CONF"
        
        # Keep ZSH in sync if it exists (matching your install.sh logic)
        if [ -f "$ZSH_RC" ]; then
            sed -i "s|^export WALLPAPER_DIR=.*|export WALLPAPER_DIR=\"$WP_DIR\"|" "$ZSH_RC"
        fi
    fi
done
