#!/bin/sh

# Game Mode for the Quick Panel tile (and the Settings switch).
#
#   gamemode-state.sh on     animations, shadows, blur, gaps and rounding off,
#                            border 1, tearing allowed; applied live
#   gamemode-state.sh off    `hyprctl reload`, which puts all of them back to
#                            whatever the Hyprland config (and our
#                            sekaipop_overrides.lua) says
#
# Same rule as hyprland-settings.sh: a Lua Hyprland config ignores
# `hyprctl keyword`, so `hyprctl eval "hl.config({...})"` goes first and
# `hyprctl keyword` (hyprlang) is the fallback when Hyprland does not answer
# the eval. Nothing in the user's config files is edited.
#
# Exit codes:  0 applied   1 hyprctl missing, or Hyprland refused the change
#              2 bad argument

command -v hyprctl >/dev/null 2>&1 || exit 1

# Left while Game Mode is on. The Quick Panel reads it when `hyprctl getoption`
# gives no answer it can read, so the tile can't turn itself off by mistake.
marker="${XDG_RUNTIME_DIR:-/tmp}/sekaipop-gamemode"

case "$1" in
    on)
        out=$(hyprctl eval 'hl.config({
            animations = { enabled = false },
            decoration = { shadow = { enabled = false }, blur = { enabled = false }, rounding = 0 },
            general = { gaps_in = 0, gaps_out = 0, border_size = 1, allow_tearing = true }
        })' 2>&1)
        case "$out" in
            ok*|"") : > "$marker"; exit 0 ;;
        esac
        out=$(hyprctl --batch 'keyword animations:enabled 0 ; keyword decoration:shadow:enabled 0 ; keyword decoration:blur:enabled 0 ; keyword general:gaps_in 0 ; keyword general:gaps_out 0 ; keyword general:border_size 1 ; keyword decoration:rounding 0 ; keyword general:allow_tearing 1' 2>&1)
        # One "ok" per keyword; anything else in the answer is an error text.
        [ -n "$out" ] && [ -z "$(printf '%s\n' "$out" | grep -v -x 'ok')" ] && { : > "$marker"; exit 0; }
        exit 1
        ;;
    off)
        out=$(hyprctl reload 2>&1)
        case "$out" in
            ok*|"") rm -f "$marker"; exit 0 ;;
        esac
        exit 1
        ;;
    *)
        exit 2
        ;;
esac
