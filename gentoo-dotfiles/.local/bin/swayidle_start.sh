#!/bin/sh

swayidle \
  timeout 600 'swaylock' \
  timeout 900 'wlr-randr --output DP-3 --off' \
  resume 'wlr-randr --output DP-3 --on' \
  before-sleep 'swaylock' &
