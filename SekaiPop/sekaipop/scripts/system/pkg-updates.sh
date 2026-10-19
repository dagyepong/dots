#!/bin/sh

# Helper for PackageUpdatesService.qml: how many package updates are waiting
# on an Arch system.
#
#   pkg-updates.sh check <aur: 1|0>
#
# Prints, one per line:
#   status=ok|nocmd|error        nocmd = `checkupdates` (pacman-contrib) is missing
#   repo=<n>                     updates from the repositories
#   aur=<n>                      updates from the AUR (paru or yay, if installed and asked for)
#   pkg=<name> <old> -> <new>    the first 40 repository updates
#   aurpkg=<name> <old> -> <new> the first 20 AUR updates
#
# `checkupdates` is used (rather than `pacman -Qu`) because it works on a
# private copy of the sync database: it never needs root and never leaves the
# system in the "partial upgrade" state that `pacman -Sy` would. Its exit
# codes are 0 (updates), 2 (none) and 1 (error).

mode="$1"
want_aur="${2:-0}"

case "$mode" in
    check)
        if ! command -v checkupdates >/dev/null 2>&1; then
            echo "status=nocmd"
            exit 0
        fi
        out=$(checkupdates 2>/dev/null)
        rc=$?
        case "$rc" in
            0) repo=$(printf '%s\n' "$out" | grep -c .) ;;
            2) repo=0; out="" ;;
            *) echo "status=error"; exit 0 ;;
        esac
        aur=0
        aurout=""
        if [ "$want_aur" = "1" ]; then
            if command -v paru >/dev/null 2>&1; then
                aurout=$(paru -Qua 2>/dev/null)
            elif command -v yay >/dev/null 2>&1; then
                aurout=$(yay -Qua 2>/dev/null)
            fi
            [ -n "$aurout" ] && aur=$(printf '%s\n' "$aurout" | grep -c .)
        fi
        echo "status=ok"
        echo "repo=$repo"
        echo "aur=$aur"
        [ -n "$out" ] && printf '%s\n' "$out" | head -n 40 | awk 'NF >= 4 { print "pkg=" $1 " " $2 " -> " $4 }'
        [ -n "$aurout" ] && printf '%s\n' "$aurout" | head -n 20 | awk 'NF >= 4 { print "aurpkg=" $1 " " $2 " -> " $4 }'
        exit 0
        ;;
    *)
        echo "usage: $0 check <aur 1|0>" >&2
        exit 2
        ;;
esac
