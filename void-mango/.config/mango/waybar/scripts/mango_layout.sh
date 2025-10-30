#!/bin/bash

echo "$(date): $@" >> /tmp/mango_layout.log

OUTPUT="DP-3"

case "$1" in
  "switch-tile")
    mmsg -l "T"
    ;;
  "switch-monocle")
    mmsg -l "M"
    ;;
  "switch-grid")
    mmsg -l "G"
    ;;
  "switch-scroller")
    mmsg -l "S"
    ;;
  "switch-centertile")
    mmsg -l "CT"
    ;;
  "switch-deck")
    mmsg -l "K"
    ;;
  "get-layout")
    CURRENT_LAYOUT=$(mmsg -o "$OUTPUT" -g -l | awk '{print $2}')
    echo "[ $CURRENT_LAYOUT ]"
    ;;
  *)
    echo "Error: Invalid argument '$1'" >&2
    exit 1
    ;;
esac
