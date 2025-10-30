#!/bin/bash

# Log the arguments for debugging
echo "$(date): $@" >> /tmp/dwl_layout.log

# Define the output (e.g., DP-3, eDP-1)
OUTPUT="DP-3"

# Handle command-line arguments for interaction
case "$1" in
  "switch-tile")
    #dwlmsg -o $OUTPUT -s -l "[]="
    dwlmsg -l 0
    ;;
  "switch-monocle")
    dwlmsg -o $OUTPUT -s -l "[M]"
    ;;
  "switch-bstack")
    #dwlmsg -o $OUTPUT -s -l '󰕯'
    dwlmsg -s -l 4
    ;;
  "switch-bstackhoriz")
    #dwlmsg -o $OUTPUT -s -l '󰕯'
    dwlmsg -s -l 5
    ;;
  "switch-centeredmaster")
    #dwlmsg -o $OUTPUT -s -l '󰕯'
    dwlmsg -s -l 3
    ;;
  "get-layout")
    # Get the current layout and extract the layout symbol
    CURRENT_LAYOUT=$(dwlmsg -o $OUTPUT -g -l | awk '{print $2}')
    echo "$CURRENT_LAYOUT"
    ;;
  *)
    echo "Error: Invalid argument '$1'" >&2
    exit 1
    ;;
esac
