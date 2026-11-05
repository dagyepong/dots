#!/bin/sh
# Holds a lock on lid closing while Quickshell is alive:
# the system does not suspend and the shell takes care of locking the screen.
parent=$PPID
exec systemd-inhibit --what=handle-lid-switch --who=Quickshell \
    --why="Screen lock on lid close" --mode=block \
    sh -c "while kill -0 $parent 2>/dev/null; do sleep 2; done"
