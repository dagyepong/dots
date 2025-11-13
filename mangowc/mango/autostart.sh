waybar &

# wallpaper
swaybg -i ~/.config/mango/wallpaper/10.png >/dev/null 2>&1 &
mako &
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=wlroots
# The next line of command is not necessary. It is only to avoid some situations where it cannot start automatically
# /usr/lib/xdg-desktop-portal-wlr &
nm-applet >/dev/null &
kdeconnect-indicator &
easyeffects --gapplication-service &
# keep clipboard content
wl-clip-persist --clipboard regular --reconnect-tries 0 &
# clipboard content manager
clipse -listen &
# wl-paste --type text --watch cliphist store & 
# wl-paste --type image --watch cliphist store & 
# Permission authentication
/usr/lib/xfce-polkit/xfce-polkit &
