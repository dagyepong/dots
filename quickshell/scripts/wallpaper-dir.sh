#!/bin/sh
# Prints the wallpapers folder: <Pictures>/Wallpapers, where <Pictures> is the system one
# (Pictures, Immagini, Bilder...). Override with QS_WALLPAPERS=/some/folder.
if [ -n "$QS_WALLPAPERS" ]; then printf '%s\n' "$QS_WALLPAPERS"; exit 0; fi
pics=""
command -v xdg-user-dir >/dev/null 2>&1 && pics=$(xdg-user-dir PICTURES 2>/dev/null)
case "$pics" in ""|"$HOME"|"$HOME/") pics="$HOME/Pictures" ;; esac
printf '%s/Wallpapers\n' "$pics"
