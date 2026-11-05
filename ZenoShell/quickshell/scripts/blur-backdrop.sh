#!/bin/sh
# niri overview backdrop (where the shrunken windows rest): the blurred wallpaper.
# Usage: blur-backdrop.sh [/path/to/wallpaper]   (without argument: the current wallpaper)
# Does nothing outside niri (Hyprland has no backdrop).
[ -n "$NIRI_SOCKET" ] || exit 0
img="$1"
[ -n "$img" ] || img=$(cat "$HOME/.cache/quickshell-wallpaper-current" 2>/dev/null)
[ -f "$img" ] || exit 0

if command -v awww >/dev/null 2>&1; then bin=awww; else bin=swww; fi
# wait for the "backdrop" daemon (started by niri at login), up to ~10 s
i=0
while ! "$bin" query -n backdrop >/dev/null 2>&1; do
    i=$((i+1)); [ "$i" -gt 20 ] && exit 0
    sleep 0.5
done

mkdir -p "$HOME/.cache"
out="$HOME/.cache/quickshell-wallpaper-blur.jpg"
if command -v magick >/dev/null 2>&1; then
    magick "$img" -resize 1920x -blur 0x24 -fill black -colorize 18% "$out"
elif command -v convert >/dev/null 2>&1; then
    convert "$img" -resize 1920x -blur 0x24 -fill black -colorize 18% "$out"
elif command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -y -v error -i "$img" -vf "scale=1920:-2,gblur=sigma=30,eq=brightness=-0.08" -frames:v 1 "$out"
else
    exit 0
fi

"$bin" img -n backdrop "$out" --transition-type none 2>/dev/null \
    || "$bin" -n backdrop img "$out" --transition-type none 2>/dev/null
exit 0
