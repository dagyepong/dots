#! /bin/bash

dbus-update-activation-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=wlroots
kanshi &
swayidle_start.sh &
sway-audio-idle-inhibit &
# xwayland dpi scale
# echo "Xft.dpi: 140" | xrdb -merge
xrdb merge ~/.Xresources
~/.azotebg &
pipewire &
#/usr/libexec/polkit-gnome-authentication-agent-1 &
soteria &

dunst -conf ~/.config/dunst/dunstrc_mango &
waybar -c ~/.config/mango/waybar/config.jsonc -s ~/.config/mango/waybar/style.css &
/home/ron/.config/mango/waybar/shadow/panel-shadow.py &
wl-clip-persist --clipboard regular --reconnect-tries 0 &
wl-paste --type text --watch cliphist store & 

mpd &
mpdris2-rs &
playerctld daemon &
mpd-mpris &
mpd-discord-rpc 2>&1 > ~/.log/mpd-discord-rpc.log &
listenbrainz-mpd &
mpdscribble &

blueman-applet &
nm-applet &
udiskie --smart-tray &
steam %U &
heroic &

thunderbird &
/home/ron/.local/share/flatpak/exports/bin/ca.andyholmes.Valent &
foot -T logs --app-id logs -e tmuxinator start logs_mango -n logs &
