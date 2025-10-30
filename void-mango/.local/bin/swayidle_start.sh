#!/bin/sh

swayidle \
  timeout 900 'swaylock' \
  timeout 1200 'wlr-randr --output DP-3 --off' \
  resume 'wlr-randr --output DP-3 --on' \
  before-sleep 'swaylock' &
