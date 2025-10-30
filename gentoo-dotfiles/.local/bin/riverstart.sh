#!/bin/sh

export TERMINAL="kitty"
export XDG_CURRENT_DESKTOP="river"
export XDG_SESSION_DESKTOP="river"
export XDG_SESSION_TYPE="wayland"
export _JAVA_AWT_WM_NONREPARENTING=1

export MOZ_ENABLE_WAYLAND=1
export MOZ_WEBRENDER=1
export MOZ_ACCELERATED=1

#==== kunst exports
export KUNST_SIZE="250x250"
export KUNST_POSITION="+2270+1149"
export KUNST_MUSIC_DIR="/home/ron/Music/"

sleep 20 && dbus-update-activation-environment --all &

#river
dbus-run-session river > ~/.river.log 2>&1
