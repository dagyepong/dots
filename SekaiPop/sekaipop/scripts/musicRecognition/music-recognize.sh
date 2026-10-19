#!/bin/sh

# Helper for QuickSource.qml's Music Recognition tile: listens to whatever
# the speakers are playing for a few seconds and says what song it is, as a
# notification. Needs `songrec` (the Shazam client) and `ffmpeg`; with either
# missing it just says so. Works from the default output's monitor, so it
# hears system audio rather than the microphone.

# Sent under its own app name, with a Material Symbols glyph as its icon
# ("material:<name>" is understood by this shell's notification cards), so it
# doesn't show up as "notify-send" with the placeholder.
note() { notify-send -a "Music Recognition" -i "material:music_cast" "Music Recognition" "$1" 2>/dev/null; }

command -v songrec >/dev/null 2>&1 || { note "songrec isn't installed"; exit 0; }
command -v ffmpeg >/dev/null 2>&1 || { note "ffmpeg isn't installed"; exit 0; }

f=$(mktemp --suffix=.wav) || exit 1
trap 'rm -f "$f"' EXIT

src="$(pactl get-default-sink 2>/dev/null).monitor"
ffmpeg -loglevel error -y -f pulse -i "$src" -t 8 -ac 1 -ar 16000 "$f" 2>/dev/null

# Newer songrec: `recognize <file>`; older: `audio-file-to-recognized-song`.
out=$(songrec recognize "$f" 2>/dev/null || songrec audio-file-to-recognized-song "$f" 2>/dev/null)

# Some versions print the Shazam JSON; pull "Artist - Title" out of it.
case "$out" in
    "{"*)
        flat=$(printf '%s' "$out" | tr -d '\n')
        t=$(printf '%s' "$flat" | grep -o '"title" *: *"[^"]*"' | head -n1 | sed 's/^[^:]*: *"//; s/"$//')
        a=$(printf '%s' "$flat" | grep -o '"subtitle" *: *"[^"]*"' | head -n1 | sed 's/^[^:]*: *"//; s/"$//')
        out="${a:+$a - }$t"
        ;;
esac

if [ -n "$out" ]; then
    note "$out"
else
    note "Couldn't recognise that"
fi
