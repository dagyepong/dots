#!/bin/sh

# Helper for ThemeService.qml: remembers which group theme was picked
# (vs / leoneed / mmj / vbs / wxs / nightcord / mono), so a shell restart keeps
# it instead of going back to Virtual Singer.
#
#   theme-state.sh save <id>   remember this theme id
#   theme-state.sh load        print the remembered id (or nothing at
#                              all, if none is saved yet)
#   theme-state.sh save-dark on|off   remember dark mode
#   theme-state.sh load-dark   print "on" or "off" (nothing if never set)
#   theme-state.sh save-darker on|off   remember the DARKER look (vs the default dark)
#   theme-state.sh load-darker print "on" or "off" (nothing if never set)
#   theme-state.sh save-custom <c1,c2,c3,c4,c5>   remember the palette the Palette tool
#                              applied (five #rrggbb), the colours of the "custom" theme
#   theme-state.sh load-custom print it (nothing if none)
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/theme — state, not
# data, same convention barstyle-state.sh uses.

mode="$1"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/theme"
darkfile="$dir/dark"
darkerfile="$dir/darker"
customfile="$dir/custom-palette"

case "$mode" in
    save)
        id="$2"
        [ -n "$id" ] || exit 2
        mkdir -p "$dir" || exit 1
        printf '%s\n' "$id" > "$file.tmp" || exit 1
        mv "$file.tmp" "$file"
        ;;
    load)
        [ -f "$file" ] && cat "$file"
        exit 0
        ;;
    save-dark)
        [ "$2" = "on" ] || [ "$2" = "off" ] || exit 2
        mkdir -p "$dir" || exit 1
        printf '%s\n' "$2" > "$darkfile.tmp" || exit 1
        mv "$darkfile.tmp" "$darkfile"
        ;;
    load-dark)
        [ -f "$darkfile" ] && cat "$darkfile"
        exit 0
        ;;
    save-darker)
        [ "$2" = "on" ] || [ "$2" = "off" ] || exit 2
        mkdir -p "$dir" || exit 1
        printf '%s\n' "$2" > "$darkerfile.tmp" || exit 1
        mv "$darkerfile.tmp" "$darkerfile"
        ;;
    load-darker)
        [ -f "$darkerfile" ] && cat "$darkerfile"
        exit 0
        ;;
    save-custom)
        echo "$2" | grep -Eq '^#[0-9a-fA-F]{6}(,#[0-9a-fA-F]{6}){4}$' || exit 2
        mkdir -p "$dir" || exit 1
        printf '%s\n' "$2" > "$customfile.tmp" || exit 1
        mv "$customfile.tmp" "$customfile"
        ;;
    load-custom)
        [ -f "$customfile" ] && cat "$customfile"
        exit 0
        ;;
    *)
        echo "usage: $0 save <id>|load|save-dark on|off|load-dark|save-darker on|off|load-darker|save-custom <5 colours>|load-custom" >&2
        exit 2
        ;;
esac
