#!/bin/bash

# Dropdown Scratchpad for Herbstluftwm
# Opens applications in a floating scratchpad on a dedicated tag

SCRATCHPAD_TAG="dropdown"
SCRATCHPAD_FILE="/tmp/herbstluftwm_dropdown_winid"
APPS_LIST=(
    "alacritty --class=dropdown --title=dropdown"
    "kitty --class=dropdown --name=dropdown"
    "urxvt -name dropdown"
    "st -n dropdown"
    "qutebrowser"
    "thunar"
    "nautilus"
    "nemo"
    "pcmanfm"
    "ranger"
    "nvim"
    "vim"
    "nano"
    "htop"
    "btop"
    "bashtop"
    "ncmpcpp"
    "cmus"
    "cava"
    "pulsemixer"
    "pavucontrol"
    "gnome-calculator"
    "galculator"
    "feh"
    "nsxiv"
    "gimp"
    "inkscape"
    "libreoffice"
    "obs"
    "discord"
    "telegram-desktop"
    "signal-desktop"
    "element-desktop"
)

# Ensure dropdown tag exists
herbstclient add "$SCRATCHPAD_TAG" 2>/dev/null

# Function to show rofi menu
show_app_menu() {
    printf "%s\n" "${APPS_LIST[@]}" | rofi -dmenu -p "Dropdown App:" -theme-str '
        * {
            background: #0a0a12;
            text-color: #00f3ff;
            border-color: #ff00ff;
        }
        window {
            background-color: #0a0a12;
            border: 2px solid #00f3ff;
            padding: 5px;
        }
        inputbar {
            background-color: #1a1a2e;
            padding: 5px;
        }
        listview {
            background-color: #1a1a2e;
            padding: 5px;
        }
        element {
            background-color: #1a1a2e;
            padding: 5px;
        }
        element selected {
            background-color: #00f3ff;
            text-color: #0a0a12;
        }
        element-text, element-icon {
            background-color: inherit;
            text-color: inherit;
        }
    '
}

# Function to toggle scratchpad visibility
toggle_scratchpad() {
    if [[ -f "$SCRATCHPAD_FILE" ]]; then
        winid=$(cat "$SCRATCHPAD_FILE")
        if herbstclient bring "$winid" 2>/dev/null; then
            # Window exists, toggle it
            if xdotool search --onlyvisible --id "$winid" >/dev/null; then
                # Hide
                xdotool windowunmap "$winid"
            else
                # Show - move to current tag and show
                current_tag=$(herbstclient attr tags.focus.name)
                herbstclient chain , lock , move "$SCRATCHPAD_TAG" , floating on , set_attr clients."$winid".floating on , unlock
                xdotool windowmap "$winid"
                herbstclient bring "$winid"
            fi
        else
            # Window doesn't exist anymore, remove the file
            rm -f "$SCRATCHPAD_FILE"
        fi
    fi
}

# Function to create new scratchpad
create_scratchpad() {
    local app_cmd="$1"
    
    # Parse the command to get the executable name for class matching
    app_exec=$(echo "$app_cmd" | awk '{print $1}')
    
    # Launch the application on the dropdown tag
    herbstclient chain , lock , add "$SCRATCHPAD_TAG" , use "$SCRATCHPAD_TAG" , unlock
    $app_cmd &
    local pid=$!
    
    # Wait for the window to appear
    local winid=""
    local timeout=0
    while [[ -z "$winid" && $timeout -lt 50 ]]; do
        winid=$(xdotool search --pid "$pid" --class "$app_exec" 2>/dev/null | head -1)
        sleep 0.1
        ((timeout++))
    done
    
    if [[ -n "$winid" ]]; then
        # Configure the window as scratchpad
        herbstclient chain , lock , \
            sprintf WINID "%u" clients.focus.winid , \
            set_attr clients."$WINID".floating on , \
            set_attr clients."$WINID".title "dropdown" , \
            set_attr clients."$WINID".tag "$SCRATCHPAD_TAG" , \
            unlock
        
        echo "$winid" > "$SCRATCHPAD_FILE"
        
        # Set window properties for dropdown behavior
        xdotool set_window --class "dropdown" "$winid"
        xprop -id "$winid" -f _NET_WM_WINDOW_TYPE 32a -set _NET_WM_WINDOW_TYPE "_NET_WM_WINDOW_TYPE_DIALOG"
        
        echo "Scratchpad created with window ID: $winid"
    else
        echo "Failed to create scratchpad window"
        rm -f "$SCRATCHPAD_FILE"
    fi
}

# Function to close scratchpad
close_scratchpad() {
    if [[ -f "$SCRATCHPAD_FILE" ]]; then
        winid=$(cat "$SCRATCHPAD_FILE")
        xdotool windowclose "$winid" 2>/dev/null
        rm -f "$SCRATCHPAD_FILE"
    fi
}

# Main logic
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
        selected_app=$(show_app_menu)
        if [[ -n "$selected_app" ]]; then
            # Close existing scratchpad if open
            close_scratchpad
            # Create new one
            create_scratchpad "$selected_app"
            # Show it
            sleep 0.5
            toggle_scratchpad
        fi
        ;;
    *)
        echo "Usage: $0 {toggle|show|hide|close|menu}"
        echo "  toggle - Toggle scratchpad visibility"
        echo "  show   - Show scratchpad"
        echo "  hide   - Hide scratchpad"
        echo "  close  - Close scratchpad"
        echo "  menu   - Show app menu to create new scratchpad"
        exit 1
        ;;
esac