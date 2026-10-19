#!/bin/sh

# Used by QuickSource.qml's Log out action: ask every open window's program
# to quit first (SIGTERM, so apps can save), give them a moment, then end
# the Hyprland session.
#
# Reads the pids out of `hyprctl clients -j` with grep, so it needs no jq
# and no particular Hyprland dispatcher syntax. Hyprland reports pid -1 for
# some windows; anything <= 1 is skipped so this can never signal init.
#
#   session-logout.sh [grace-seconds]     (default 1.5)

grace="${1:-1.5}"

for pid in $(hyprctl clients -j 2>/dev/null | grep -o '"pid": *[0-9]*' | grep -o '[0-9]*$' | sort -u); do
    [ "$pid" -gt 1 ] 2>/dev/null && kill "$pid" 2>/dev/null
done

sleep "$grace"

# End the Hyprland session. Hyprland 0.55+ with a Lua config takes dispatchers as Lua
# (`hl.dsp.exit()`); the old plain `dispatch exit` does nothing there, which is why Log
# out seemed dead. Try the Lua form first, then the old form, then ask systemd-logind to
# end this login session. Each step waits a moment: when one works, Hyprland (and this
# script with it) is gone, so the next line never runs.
hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1
sleep 1
hyprctl dispatch exit >/dev/null 2>&1
sleep 1
if [ -n "$XDG_SESSION_ID" ]; then
    loginctl terminate-session "$XDG_SESSION_ID" >/dev/null 2>&1
else
    loginctl terminate-user "$USER" >/dev/null 2>&1
fi
