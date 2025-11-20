waybar &

set +e
# wallpaper
swaybg -i ~/.config/mango/wallpaper/SilkSong_screenshot2.png >/dev/null 2>&1 &


mako &
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=wlroots
# The next line of command is not necessary. It is only to avoid some situations where it cannot start automatically
# /usr/lib/xdg-desktop-portal-wlr &
nm-applet >/dev/null &
kdeconnect-indicator &
easyeffects --gapplication-service &

#notify
#swaync -c ~/.config/mango/swaync/config.jsonc -s ~/.config/mango/swaync/style.css >/dev/null 2>&1 &

# night light
wlsunset -T 3501 -t 3500 >/dev/null 2>&1 &

# keep clipboard content
wl-clip-persist --clipboard regular --reconnect-tries 0 >/dev/null 2>&1 &

# clipboard content manager
wl-paste --type text --watch cliphist store >/dev/null 2>&1 &

# clipboard content manager
clipse -listen &
# wl-paste --type text --watch cliphist store & 
# wl-paste --type image --watch cliphist store & 
# Permission authentication
/usr/lib/xfce-polkit/xfce-polkit &
# ime input
fcitx5 --replace -d >/dev/null 2>&1 &

# xwayland dpi scale
#echo "Xft.dpi: 140" | xrdb -merge #dpi缩放
# xrdb merge ~/.Xresources >/dev/null 2>&1

# inhibit by audio
sway-audio-idle-inhibit >/dev/null 2>&1 &

# change light value and volume value by swayosd-client in keybind
swayosd-server >/dev/null 2>&1 &

# lock

swayidle -w \
    timeout 300 'swaylock -f --effect-blur 5x5 --fade-in 1' \
    before-sleep 'swaylock -f --effect-blur 5x5 --fade-in 1'  >/dev/null 2>&1 & 
