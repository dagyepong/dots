#!/bin/bash

BACKEND=wayland

if pgrep -x "rofi" > /dev/null; then
    pkill rofi
fi


GDK_BACKEND=$BACKEND yad --width=450 --height=850 \
    --center \
    --title="Keybindings" \
    --no-buttons \
    --list \
    --column=Key: \
    --column=Description: \
    --timeout-indicator=bottom \
" + K" "Show all KeyBindings" \
" + Enter" "Terminal" \
" + Q" "Kills Active Window" \
" + M" "Exit" \
" + E" "File Manager" \
" + F" "FullScreen" \
" + Shift + F" "Toggle Floating" \
" + A" "App Menu" \
" + Ctrl + V" "Clipboard History" \
" + Ctrl + W" "Clear Clipboard History" \
"Ctrl + Alt + P" "Logout Menu" \
" + L" "Lock Screen" \
" + Alt + E" "Emoji" \
" + Print" "Take Full Screenshot" \
" + Shift + Print" "Screenshot selected Area" \
" + Ctrl + Print" "Screenshot in 5secs" \
" + Ctrl + Shift + Print" "Screenshot in 10secs" \
" + Shift + R" "Reload Mango" \
" +  R" "Reload Waybar" \
" + T" "Title Layout" \
" + V" "Vertical Grid" \
" + C" "Spiral Layout" \
" + X" "Scroller Layout" \
" + N" "Switch Layout" \
" + G" "Toggle Gaps between windows" \
" + S" "Toggles Overview" \
" + Ctrl + [Arrow Keys]" "Switch Workspaces" \
" + Shift + [Arrow Keys]" "Switch Windows" \
"Ctrl + Shift + [Arrow Keys]" "Move Windows" \
" + [Arrow Keys]" "Move focus to window" \
" + left_mouse" "move window" \
" + right_mouse" "resize window" \
" + 1 or 2 or..." "go to that workspace" \
" + mouse_down" "next workspace" \
" + mouse_up" "previous workspace" \
" + Shift + 1 or 2 or..." "Moves active window to that workspace" \
" + I" "Decrease Workspace Size Vertically" \
" + P" "Increase Workspace Size Vertically" \
