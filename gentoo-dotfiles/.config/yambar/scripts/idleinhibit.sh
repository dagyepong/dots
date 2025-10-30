#!/bin/bash

# River swayidle toggle
function toggle {
  if pgrep "swayidle" >/dev/null; then
    pkill swayidle
    notify-send -u normal "  Swayidle Inactive" --hint=string:x-canonical-private-synchronous:idleinhibit
  else
    swayidle \
      timeout 900 'swaylock' \
      timeout 1200 'wlr-randr --output DP-3 --off' \
      resume 'wlr-randr --output DP-3 --on' \
      before-sleep 'swaylock' &
    notify-send -u normal "  Swayidle Active" --hint=string:x-canonical-private-synchronous:idleinhibit
  fi
}

case $1 in
toggle)
  toggle
  ;;
*)
  while true; do
    if pgrep "swayidle" >/dev/null; then
      icon=" "
    else
      icon=" "
    fi
    echo "idleinhibit|string|$icon"
    echo ""
    sleep 1
  done
  ;;
esac
exit 0
