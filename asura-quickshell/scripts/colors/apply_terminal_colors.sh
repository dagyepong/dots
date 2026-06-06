#!/usr/bin/env python3
import os
import sys

# Script to apply terminal colors globally.
# Reads the sequences file (containing raw bytes) and writes to all active PTYs.

SEQUENCES_FILE = os.path.expanduser("~/.local/state/quickshell/user/generated/terminal/sequences.txt")

if not os.path.exists(SEQUENCES_FILE):
    sys.exit(0)

def apply_colors():
    try:
        # The /dev/pts/ broadcast was causing terminal emulators
        # to trigger "Activity in Background" or "Bell" desktop notifications.
        # Foot and Ghostty read their theme from config and do not need live IPC here.
        return
    except Exception as e:
        print(f"Error applying colors: {e}", file=sys.stderr)

if __name__ == "__main__":
    apply_colors()
