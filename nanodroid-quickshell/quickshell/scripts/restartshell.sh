#!/bin/bash

# Asura Shell restart script
# Restarts the quickshell instance safely

# 1. Kill existing instances
killall qs quickshell 2>/dev/null
pkill -9 cava 2>/dev/null

# 2. Wait a moment to ensure they are truly dead
sleep 1

# 3. Start new instance detached from any terminal that launched this script
mkdir -p "$HOME/.cache/nandoroid"
setsid -f quickshell -c nandoroid > "$HOME/.cache/nandoroid/quickshell.log" 2>&1 < /dev/null

exit 0
