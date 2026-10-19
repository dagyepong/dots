#!/bin/sh

# Helper for WallpaperService.qml: lets you choose the folder the wallpaper
# picker lists, with a normal folder chooser.
#
#   pick-folder.sh pick [start-folder]   open a folder chooser (starting in
#                                        <start-folder> if it exists); the
#                                        chosen folder is printed. Prints
#                                        nothing (exit 1) if you cancel.
#
# Nothing is copied or moved: the shell just lists that folder from now on
# (Settings -> Desktop -> Wallpaper -> Wallpaper folder is saved by the caller).
#
# The chooser is the first of kdialog, zenity or yad that's installed, the same
# way pick-image.sh does it, and SEKAIPOP_CHOOSER (Settings -> General -> picker)
# is tried first. A chooser that is not installed is skipped.

mode="$1"
start="$2"

[ "$mode" = pick ] || { echo "usage: $0 pick [start-folder]" >&2; exit 2; }

# Start in the folder already in use, else Pictures, else home.
if [ -z "$start" ] || [ ! -d "$start" ]; then
    start=$(xdg-user-dir PICTURES 2>/dev/null)
    [ -d "$start" ] || start="$HOME/Pictures"
    [ -d "$start" ] || start="$HOME"
fi

title="Choose your wallpaper folder"

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
        f=$(zenity --file-selection --directory --title="$title" --filename="$start/" 2>/dev/null)
        ;;
    kdialog)
        f=$(kdialog --title "$title" --getexistingdirectory "$start" 2>/dev/null)
        ;;
    yad)
        f=$(yad --file --directory --title="$title" --filename="$start/" 2>/dev/null)
        ;;
    *)
        echo "no folder chooser found: install zenity (or kdialog / yad)" >&2
        command -v notify-send >/dev/null 2>&1 \
            && notify-send -a Wallpapers "Can't choose a folder" "Install zenity (or kdialog / yad) to get a folder chooser."
        exit 127
        ;;
esac

# Cancelled, or nothing usable picked.
[ -n "$f" ] && [ -d "$f" ] || exit 1

# No trailing slash (zenity adds one).
while [ "${#f}" -gt 1 ] && [ "${f%/}" != "$f" ]; do
    f="${f%/}"
done

printf '%s\n' "$f"
