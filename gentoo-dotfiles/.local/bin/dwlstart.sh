#!/usr/bin/env bash

#sleep 2 && waybar --config=/home/ron/.config/dwl-v0.7/waybar/config.jsonc --style=/home/ron/.config/dwl-v0.7/waybar/style.css 2>&1 >~/.waybar.log &
swayidle_start.sh &
gentoo-pipewire-launcher restart &
sleep 5 && blueman-applet &
wl-paste --type text --watch cliphist store &
wl-paste --type image --watch cliphist store &

function run {
  if ! pgrep -x $(basename $1 | head -c 15) 1>/dev/null; then
    $@ &
  fi
}

# Utilities
run kanshi &
run /usr/libexec/polkit-gnome-authentication-agent-1 &
run gnome-keyring-daemon --start --components=secrets &
export $(gnome-keyring-daemon) &
run dunst -conf ~/.config/dunst/dunstrc_dwl &
run wbg /home/ron/Wallpapers/wallhaven-0j8l7w_sh_34.jpg &
#run wlsunset -l 31.8 -L -99.4 &
run mpd &
run mpdris2-rs &
run nm-applet &
#run blueman-applet &
#run safeeyes &
run steam %U &
run thunderbird-bin &
run valent &
run waycorner --config ~/.config/waycorner/config_dwl.toml &
