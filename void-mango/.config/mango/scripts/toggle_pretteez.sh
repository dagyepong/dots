#!/usr/bin/env bash

if pgrep -x waybar >/dev/null; then
  killall -SIGINT waybar
  mmsg -d setoption,shadows,0
  mmsg -d setoption,layer_shadows,0
else
  waybar -c $HOME/.config/mango/waybar/config.jsonc -s $HOME/.config/mango/waybar/style.css &
  sleep 0.5
  mmsg -d reload_config
  notify-send "Reloaded config"
fi
