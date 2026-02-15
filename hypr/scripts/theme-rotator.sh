#!/bin/bash
# ~/.config/hypr/scripts/theme-rotator.sh

# Theme configurations
themes=(
    # 1. Nord Frost (Icy Blue & Purple)
    "rgba(8fbcbbff) rgba(88c0d0ff) rgba(81a1c1ff) rgba(5e81acff) rgba(b48eadff) rgba(8fbcbbff)|rgba(3b4252aa)|Nord Frost"
    
    # 2. Solarized Desert (Warm Earth Tones)
    "rgba(dc322fff) rgba(cb4b16ff) rgba(b58900ff) rgba(859900ff) rgba(268bd2ff) rgba(6c71c4ff) rgba(d33682ff)|rgba(073642aa)|Solarized Desert"
    
    # 3. Dracula Pro (Vampire Gothic)
    "rgba(bd93f9ff) rgba(ff79c6ff) rgba(8be9fdff) rgba(50fa7bff) rgba(ffb86cff)|rgba(282a36aa)|Dracula Pro"
    
    # 4. Tokyo Night (Japanese Neon)
    "rgba(7aa2f7ff) rgba(bb9af7ff) rgba(9ece6aff) rgba(e0af68ff) rgba(f7768eff)|rgba(1a1b26aa)|Tokyo Night"
    
    # 5. Catppuccin Mocha (Warm Latte)
    "rgba(f5e0dcff) rgba(f2cdcdff) rgba(f5c2e7ff) rgba(cba6f7ff) rgba(f38ba8ff) rgba(eba0acff) rgba(fab387ff) rgba(f9e2affff) rgba(a6e3a1ff) rgba(94e2d5ff) rgba(89dcebff) rgba(74c7ecff) rgba(89b4faff) rgba(b4befeff)|rgba(585b70aa)|Catppuccin Mocha"
    
    # 6. Cyberpunk Neon (Electric Blue & Pink)
    "rgba(00ffffff) rgba(ff00ffff) rgba(ffff00ff) rgba(00ff00ff) rgba(ff0000ff)|rgba(00000099)|Cyberpunk Neon"
    
    # 7. Forest Grove (Nature Greens)
    "rgba(7c9f2bff) rgba(5d8233ff) rgba(2e5e1aff) rgba(3c4d16ff) rgba(9caf65ff)|rgba(1a2f1aaa)|Forest Grove"
    
    # 8. Sunset Gradient (Warm Sunset)
    "rgba(ff6b6bff) rgba(ff8e53ff) rgba(ffaf40ff) rgba(ffd93dff) rgba(6bcf7fff) rgba(4d96ffff)|rgba(2c3e50aa)|Sunset Gradient"
    
    # 9. Ocean Depths (Deep Sea Blues)
    "rgba(1d3557ff) rgba(457b9dff) rgba(a8dadcff) rgba(f1faeeff) rgba(e63946ff)|rgba(0a192faa)|Ocean Depths"
    
    # 10. Monochrome Pulse (Black & White with Accent)
    "rgba(ffffffff) rgba(ccccccff) rgba(999999ff) rgba(666666ff) rgba(333333ff) rgba(000000ff) rgba(ff5555ff)|rgba(222222aa)|Monochrome Pulse"
)

# State file for current theme
STATE_FILE="$HOME/.config/hypr/theme-state"
[ -f "$STATE_FILE" ] || echo "1" > "$STATE_FILE"
CURRENT_THEME=$(cat "$STATE_FILE")

# Function to apply theme
apply_theme() {
    local index=$1
    IFS='|' read -r active_border inactive_border theme_name <<< "${themes[$index]}"
    
    hyprctl keyword general:col.active_border "$active_border"
    hyprctl keyword general:col.inactive_border "$inactive_border"
    
    echo "$index" > "$STATE_FILE"
    
    # Send notification
    if command -v notify-send &> /dev/null; then
        notify-send -t 2000 "Theme Changed" "Applied: $theme_name"
    fi
}

# Infinite loop to rotate themes
while true; do
    apply_theme $((CURRENT_THEME - 1))
    
    # Update current theme (rotate)
    CURRENT_THEME=$((CURRENT_THEME % ${#themes[@]} + 1))
    
    # Wait before next change (60 seconds)
    sleep 60
done
