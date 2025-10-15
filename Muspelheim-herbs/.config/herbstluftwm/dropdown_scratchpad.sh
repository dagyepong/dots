#!/bin/bash

SCRATCHPAD_TAG="dropdown"
SCRATCHPAD_FILE="/tmp/herbstluftwm_dropdown_winid"

# Custom dropdown apps with icons
DROPDOWN_APPS=(
    "󰆍 Terminal|alacritty --class=dropdown --title=dropdown"
    "󰉋 File Manager|thunar"
    "󰈬 Text Editor|nvim"
    "󰍛 System Monitor|htop"
    "󰎄 Music Player|ncmpcpp"
    "󰕾 Volume Control|pulsemixer"
    "󰃬 Calculator|gnome-calculator"
    "󰋩 Image Viewer|feh"
    "󰇧 Browser|firefox-bin"
    "󰎁 Video Player|mpv"
    "󰊗 Task Manager|btop"
    "󰦝 Network|nmtui"
    "󰇮 PDF Viewer|zathura"
    "󰙅 Screenshot|flameshot gui"
)

show_dropdown_menu() {
    for app in "${DROPDOWN_APPS[@]}"; do
        echo "${app%|*}"
    done | rofi -dmenu -p "󰏊" -config ~/.config/rofi/dropdown.rasi
}

get_app_command() {
    local app_name="$1"
    for app in "${DROPDOWN_APPS[@]}"; do
        if [[ "${app%|*}" == "$app_name" ]]; then
            echo "${app#*|}"
            return
        fi
    done
}

toggle_scratchpad() {
    if [[ -f "$SCRATCHPAD_FILE" ]]; then
        winid=$(cat "$SCRATCHPAD_FILE")
        if herbstclient bring "$winid" 2>/dev/null; then
            if xdotool search --onlyvisible --id "$winid" >/dev/null; then
                echo "Hiding dropdown"
                xdotool windowunmap "$winid"
            else
                echo "Showing dropdown"
                xdotool windowmap "$winid"
                herbstclient bring "$winid"
            fi
        else
            echo "Dropdown window not found, cleaning up"
            rm -f "$SCRATCHPAD_FILE"
        fi
    else
        echo "No dropdown session found"
    fi
}

create_scratchpad() {
    local app_name="$1"
    local app_cmd=$(get_app_command "$app_name")
    
    if [[ -z "$app_cmd" ]]; then
        echo "Unknown application: $app_name"
        return 1
    fi
    
    echo "Creating dropdown with: $app_cmd"
    
    # Ensure dropdown tag exists
    herbstclient add "$SCRATCHPAD_TAG" 2>/dev/null
    
    # Launch application
    $app_cmd &
    local pid=$!
    
    # Wait for window to appear
    local winid=""
    local timeout=0
    while [[ -z "$winid" && $timeout -lt 30 ]]; do
        winid=$(xdotool search --pid "$pid" | head -1)
        sleep 0.2
        ((timeout++))
    done
    
    if [[ -n "$winid" ]]; then
        echo "Window created with ID: $winid"
        
        # Configure window properties
        herbstclient chain , lock , \
            set_attr clients.focus.floating on , \
            set_attr clients.focus.tag "$SCRATCHPAD_TAG" , \
            set_attr clients.focus.title "dropdown" , unlock
        
        # Store window ID
        echo "$winid" > "$SCRATCHPAD_FILE"
        
        # Set window class
        xdotool set_window --class "dropdown" "$winid"
        
        echo "Dropdown setup complete"
    else
        echo "Failed to create dropdown window"
        rm -f "$SCRATCHPAD_FILE"
        return 1
    fi
}

close_scratchpad() {
    if [[ -f "$SCRATCHPAD_FILE" ]]; then
        winid=$(cat "$SCRATCHPAD_FILE")
        echo "Closing dropdown window: $winid"
        xdotool windowclose "$winid" 2>/dev/null
        rm -f "$SCRATCHPAD_FILE"
    else
        echo "No active dropdown to close"
    fi
}

case "${1:-}" in
    "toggle")
        toggle_scratchpad
        ;;
    "show")
        if [[ -f "$SCRATCHPAD_FILE" ]]; then
            winid=$(cat "$SCRATCHPAD_FILE")
            xdotool windowmap "$winid"
            herbstclient bring "$winid"
        fi
        ;;
    "hide")
        if [[ -f "$SCRATCHPAD_FILE" ]]; then
            winid=$(cat "$SCRATCHPAD_FILE")
            xdotool windowunmap "$winid"
        fi
        ;;
    "close")
        close_scratchpad
        ;;
    "menu")
        selected_app=$(show_dropdown_menu)
        if [[ -n "$selected_app" ]]; then
            echo "Selected: $selected_app"
            close_scratchpad
            sleep 0.5
            create_scratchpad "$selected_app"
            sleep 1
            toggle_scratchpad
        fi
        ;;
    "status")
        if [[ -f "$SCRATCHPAD_FILE" ]]; then
            winid=$(cat "$SCRATCHPAD_FILE")
            if xdotool search --id "$winid" >/dev/null; then
                echo "Dropdown active (Window: $winid)"
            else
                echo "Dropdown file exists but window not found"
            fi
        else
            echo "No active dropdown"
        fi
        ;;
    *)
        echo "Usage: $0 {toggle|show|hide|close|menu|status}"
        echo "  toggle - Toggle dropdown visibility"
        echo "  menu   - Show app selection menu"
        echo "  close  - Close current dropdown"
        echo "  show   - Show dropdown"
        echo "  hide   - Hide dropdown"
        echo "  status - Check dropdown status"
        exit 1
        ;;
esac