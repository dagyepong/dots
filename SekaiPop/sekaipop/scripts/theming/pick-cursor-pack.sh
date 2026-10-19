#!/bin/sh

# Helper for IconCursorService.qml: lets you choose a Windows cursor pack with a normal
# file chooser.
#
#   pick-cursor-pack.sh pick [start-folder]   open a file chooser; the chosen path is
#                                             printed. Prints nothing (exit 1) if you cancel.
#
# Pick the pack's .zip, or the install.inf of an unzipped pack. If you pick a single
# .cur / .ani that has other cursors next to it, the whole folder is the pack (so one click on
# any of them is enough). Nothing is changed here: IconCursorService hands the path to
# `icon-cursor.sh import`.
#
# The chooser is the first of kdialog, zenity or yad that's installed, and SEKAIPOP_CHOOSER
# (Settings -> General -> picker) is tried first, the same way pick-folder.sh does it.

mode="$1"
start="$2"

[ "$mode" = pick ] || { echo "usage: $0 pick [start-folder]" >&2; exit 2; }

if [ -z "$start" ] || [ ! -d "$start" ]; then
    start=$(xdg-user-dir DOWNLOAD 2>/dev/null)
    [ -d "$start" ] || start="$HOME/Downloads"
    [ -d "$start" ] || start="$HOME"
fi

title="Choose a Windows cursor pack (.zip or install.inf)"
patterns="*.zip *.ZIP *.inf *.INF *.cur *.CUR *.ani *.ANI"

chooser=""
for c in ${SEKAIPOP_CHOOSER:-} kdialog zenity yad; do
    case "$c" in
        zenity|kdialog|yad) ;;
        *) continue ;;
    esac
    if command -v "$c" >/dev/null 2>&1; then
        chooser="$c"
        break
    fi
done

case "$chooser" in
    zenity)
        # shellcheck disable=SC2086
        f=$(zenity --file-selection --title="$title" --filename="$start/" \
                --file-filter="Windows cursors | $patterns" 2>/dev/null)
        ;;
    kdialog)
        f=$(kdialog --title "$title" --getopenfilename "$start" "$patterns|Windows cursors" 2>/dev/null)
        ;;
    yad)
        # shellcheck disable=SC2086
        f=$(yad --file --title="$title" --filename="$start/" \
                --file-filter="Windows cursors | $patterns" 2>/dev/null)
        ;;
    *)
        echo "no file chooser found: install zenity (or kdialog / yad)" >&2
        command -v notify-send >/dev/null 2>&1 \
            && notify-send -a Cursors "Can't choose a file" "Install zenity (or kdialog / yad) to get a file chooser."
        exit 127
        ;;
esac

[ -n "$f" ] && [ -e "$f" ] || exit 1

# One cursor picked out of a folder of them: the folder is the pack.
low=$(printf '%s' "$f" | tr 'A-Z' 'a-z')
case "$low" in
    *.cur|*.ani)
        dir=$(dirname "$f")
        n=$(find "$dir" -maxdepth 1 -type f \( -iname '*.cur' -o -iname '*.ani' \) 2>/dev/null | wc -l)
        [ "$n" -ge 3 ] && f="$dir"
        ;;
esac

printf '%s\n' "$f"
