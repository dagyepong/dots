#!/bin/sh

# Helper for ShellScale.qml: gets the per-monitor scale file ready.
#
#   scale-state.sh init <old scale.json>
#
# The scale is one of the user's own adjustments, so it lives in
# ${XDG_CONFIG_HOME:-~/.config}/sekaipop/scale.json, not next to shell.qml
# (where a fresh copy of the shell would write over it). This makes that
# folder and, when there is no file in it yet, puts one there: a copy of the
# scale.json an older version kept beside shell.qml (<old scale.json>, left
# where it was), or the defaults when there is none. A file that is already
# there is never touched.

mode="$1"
dir="${XDG_CONFIG_HOME:-$HOME/.config}/sekaipop"
file="$dir/scale.json"

case "$mode" in
    init)
        mkdir -p "$dir" || exit 1
        [ -f "$file" ] && exit 0
        if [ -n "$2" ] && [ -f "$2" ]; then
            cp -- "$2" "$file.tmp" || exit 1
        else
            printf '{\n  "default": 1,\n  "monitors": {}\n}\n' > "$file.tmp" || exit 1
        fi
        mv "$file.tmp" "$file"
        ;;
    *)
        echo "usage: $0 init <old scale.json>" >&2
        exit 2
        ;;
esac
