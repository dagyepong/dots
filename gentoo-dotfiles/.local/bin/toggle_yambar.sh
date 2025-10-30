#!/usr/bin/bash

killall -q yambar

while pgrep -x yambar >/dev/null; do sleep 1; done

yambar -c /home/ron/.config/yambar/config.yml -l always &

if pgrep -x yambar >/dev/null; then
  notify-send "yambar Restarted" "yambar was restarted successfully."
else
  notify-send "yambar Error" "Failed to restart yambar."
fi

