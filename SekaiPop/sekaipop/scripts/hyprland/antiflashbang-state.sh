#!/bin/sh

# Anti-Flashbang, the way end4's dots-hyprland does it: the shader setting is
# written to a small Lua override file that hyprland.lua loads, instead of
# `hyprctl keyword` (which Hyprland's Lua config ignores).
#
#   antiflashbang-state.sh off|weak|strong
#
# The override file is  ~/.config/hypr/sekaipop_overrides.lua. Only lines ending
# in the marker below are ever touched, so other things can live in that file.
# One-time setup, in hyprland.lua:   pcall(require, "sekaipop_overrides")
#
# After writing, Hyprland is reloaded, and the setting is also applied live
# with `hyprctl eval`, so it works at once even before that line exists (it
# just won't survive the next reload until it does).

MARK='-- sekaipop:antiflashbang'
here=$(cd "$(dirname "$0")" && pwd)
dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
file="$dir/sekaipop_overrides.lua"

case "$1" in
    weak)   shader="$here/anti-flashbang-weak.glsl" ;;
    strong) shader="$here/anti-flashbang.glsl" ;;
    off)    shader="" ;;
    *) echo "usage: $0 off|weak|strong" >&2; exit 2 ;;
esac

mkdir -p "$dir" || exit 1
[ -e "$file" ] || : > "$file"
tmp=$(mktemp "$dir/.sekaipop_overrides.XXXXXX") || exit 1

# Everything except our own lines... (-e: the marker starts with "--"; and a
# grep that actually failed, exit 2, must never replace the file with nothing.
# Exit 1 just means no lines were left, which is fine.)
grep -v -F -e "$MARK" "$file" > "$tmp"
[ $? -le 1 ] || { rm -f "$tmp"; exit 1; }
# ...plus ours, when it's on. (Damage tracking off for the monitor, like end4:
# it stops odd flashes while a screen shader is active.)
if [ -n "$shader" ]; then
    printf 'hl.config({ decoration = { screen_shader = [==[%s]==] } }) %s\n' "$shader" "$MARK" >> "$tmp"
    printf 'hl.config({ debug = { damage_tracking = 1 } }) %s\n' "$MARK" >> "$tmp"
fi
chmod 644 "$tmp"
mv -f "$tmp" "$file" || { rm -f "$tmp"; exit 1; }

command -v hyprctl >/dev/null 2>&1 || exit 0
hyprctl reload >/dev/null 2>&1
# Live apply (after the reload, which would otherwise wipe it).
if [ -n "$shader" ]; then dt=1; else dt=2; fi
hyprctl eval "hl.config({ decoration = { screen_shader = [==[$shader]==] }, debug = { damage_tracking = $dt } })" >/dev/null 2>&1
exit 0
