#!/usr/bin/env bash

sleep 2 && waybar --config=/home/ron/.config/niri/waybar/config.jsonc --style=/home/ron/.config/niri/waybar/style.css &
#swaync -c /home/ron/.config/niri/swaync/config.json -s /home/ron/.config/niri/swaync/style.css &
/usr/libexec/polkit-gnome-authentication-agent-1 &
gtk-setup.sh &
sleep 10 && dunst -conf ~/.config/dunst/dunstrc_niri &
gentoo-pipewire-launcher restart &
swayidle_start_niri.sh &
sleep 10 && blueman-applet &
#waycorner -c ~/.config/waycorner/config_niri.toml &
wl-paste --type text --watch cliphist store &
wl-paste --type image --watch cliphist store &
sleep 10 && dbus-update-activation-environment --all &

function run {
  if ! pgrep -x $(basename $1 | head -c 15) 1>/dev/null; then
    $@ &
  fi
}

run kanshi &
run mpd &
run gnome-keyring-daemon --start --components=secrets &
export $(gnome-keyring-daemon) &
#run dunst -conf ~/.config/dunst/dunstrc_dwl &
run swww-daemon
run swww img /home/ron/Wallpapers/mosaic_landscape.jpg &
#waypaper --restore &
run swaybg -i /home/ron/Wallpapers/mosaic_landscape_blur.jpg &
#run wlsunset -l 31.8 -L -99.4 &
run mpdris2-rs &
run nm-applet &
#run blueman-applet &
run sway-audio-idle-inhibit &
run steam -silent %U &
run thunderbird-bin &
#run /opt/Obsidian/obsidian --ozone-platform-hint=auto --enable-features=UseOzonePlatform,WaylandWindowDecorations %U &D
run valent &
run udiskie --smart-tray &
run playerctld daemon &
run mpd-mpris &
