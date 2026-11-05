#!/bin/sh
# usage: clip-paste.sh <id>
# Puts the item back in the clipboard and pastes it into the active window.
id="$1"
[ -n "$id" ] || exit 1

cliphist decode "$id" | wl-copy || exit 1

if [ -n "$NIRI_SOCKET" ]; then
    cls=$(niri msg --json focused-window 2>/dev/null | jq -r '.app_id // ""' 2>/dev/null)
else
    cls=$(hyprctl -j activewindow 2>/dev/null | jq -r '.class // ""' 2>/dev/null)
fi

sleep 0.2

case "$cls" in
    kitty|Alacritty|alacritty|foot|footclient|org.wezfurlong.wezterm|com.mitchellh.ghostty|ghostty|konsole|org.kde.konsole|xterm|XTerm|org.gnome.Terminal|gnome-terminal-server|st|st-256color)
        wtype -M ctrl -M shift -k v -m shift -m ctrl
        ;;
    *)
        wtype -M ctrl -k v -m ctrl
        ;;
esac
