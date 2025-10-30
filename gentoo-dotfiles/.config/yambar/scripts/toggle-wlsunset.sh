#!/bin/bash

LOG_FILE="/tmp/wlsunset_debug.log"
echo "Script started at $(date) with args: $@" >> "$LOG_FILE"

function toggle {
  echo "Entered toggle function at $(date)" >> "$LOG_FILE"
  echo "Checking for wlsunset processes:" >> "$LOG_FILE"
  pgrep -l -x "wlsunset" >> "$LOG_FILE" 2>&1
  if pgrep -x "wlsunset" >/dev/null; then
    echo "wlsunset is running, attempting to kill" >> "$LOG_FILE"
    pkill -x "wlsunset"
    if [ $? -eq 0 ]; then
      echo "Successfully killed wlsunset at $(date)" >> "$LOG_FILE"
      notify-send -u normal "󰛨  wlsunset Inactive" --hint=string:x-canonical-private-synchronous:idleinhibit
    else
      echo "Failed to kill wlsunset at $(date)" >> "$LOG_FILE"
    fi
  else
    echo "wlsunset is not running, attempting to start" >> "$LOG_FILE"
    /usr/bin/wlsunset -l 31.8 -L -99.4 &  # Replace with `which wlsunset`
    pid=$!
    echo "Launched wlsunset with PID $pid" >> "$LOG_FILE"
    sleep 0.1
    if ps -p $pid > /dev/null; then
      echo "Confirmed wlsunset running with PID $pid at $(date)" >> "$LOG_FILE"
      notify-send -u normal "󰌵  Wlsunset Active" --hint=string:x-canonical-private-synchronous:idleinhibit
    else
      echo "wlsunset not running after launch (PID $pid) at $(date)" >> "$LOG_FILE"
      notify-send -u normal "Failed to start wlsunset"
    fi
  fi
}

case $1 in
toggle)
  echo "Case: toggle" >> "$LOG_FILE"
  toggle
  ;;
*)
  echo "Case: default loop started at $(date)" >> "$LOG_FILE"
  while true; do
    if pgrep -x "wlsunset" >/dev/null; then
      icon="󰌵 "
      echo "Loop: wlsunset active, outputting 'wlsunset|string|$icon'" >> "$LOG_FILE"
    else
      icon="󰛨 "
      echo "Loop: wlsunset inactive, outputting 'wlsunset|string|$icon'" >> "$LOG_FILE"
    fi
    echo "wlsunset|string|$icon"
    echo ""
    sleep 1
  done
  ;;
esac

echo "Script ended at $(date)" >> "$LOG_FILE"
exit 0