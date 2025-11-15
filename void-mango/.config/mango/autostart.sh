#! /bin/bash

waybar &
swaybg -i $HOME/Pictures/wallpapers/Anime-Girl1.png &
mako &
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=wlroots
# The next line of command is not necessary. It is only to avoid some situations where it cannot start automatically
# /usr/lib/xdg-desktop-portal-wlr &
nm-applet >/dev/null &
kdeconnect-indicator &
easyeffects --gapplication-service &
# clipboard content manager
clipse -listen &
# wl-paste --type text --watch cliphist store & 
# wl-paste --type image --watch cliphist store & 
# Permission authentication
/usr/lib/xfce-polkit/xfce-polkit &


swayidle_start.sh &
sway-audio-idle-inhibit &
# xwayland dpi scale
# echo "Xft.dpi: 140" | xrdb -merge
xrdb merge ~/.Xresources
~/.azotebg &
pipewire &
#/usr/libexec/polkit-gnome-authentication-agent-1 &
soteria &

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

foot -T logs --app-id logs -e tmuxinator start logs_mango -n logs &
