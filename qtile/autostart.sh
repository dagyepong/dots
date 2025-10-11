#!/bin/bash
#

xrandr --output DP-1 --mode 1920x1080 --pos 3840x1080 --rotate normal --output DP-2 --mode 1920x1080 --pos 3840x0 --rotate normal --output DP-3 --primary --mode 1920x1080 --pos 1920x638 --rotate normal --output HDMI-1 --mode 1920x1080 --pos 0x638 --rotate normal &


~/.fehbg & 
while pgrep -u $UID -x picom >/dev/null; do sleep 1; done
picom --config /home/matt/.config/picom/picom.conf --vsync &
dunst &
flatpak run com.core447.StreamController &
/usr/libexec/polkit-gnome-authentication-agent-1 &
clipmenud &

[ ! -s ~/.config/mpd/pid ] && mpd &
sxhkd -c $HOME/myrepo/qtile/sxhkd/sxhkdrc &
