#!/bin/sh
# Installer of the Quickshell shell (niri + Hyprland, same shortcuts, same styles).
#
#   sh install.sh               asks which kind of install you want
#   sh install.sh --light       LIGHT: adds a few lines to your niri / Hyprland config, replaces nothing
#   sh install.sh --full        FULL: also installs the compositor config of the author (replaces yours, backup saved)
#   sh install.sh --niri | --hyprland | --all     which compositor (default: the ones you have)
#   sh install.sh --yes         do not ask anything (LIGHT unless --full; installs missing programs too)
#   sh install.sh --no-deps     skip the check for missing programs
#   sh install.sh --purge       also uninstall the packages of other shells (noctalia, caelestia, DMS)
#   sh install.sh --uninstall   takes our lines out of your config and moves the shell to the backup
#
# Everything it replaces is saved first in ~/.config/quickshell-backup-DATE.
# The work is split in small files in installer/ (one per step).
set -e
here=$(cd "$(dirname "$0")" && pwd)
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
bk="$cfg/quickshell-backup-$(date +%Y%m%d-%H%M%S)"

want_niri=""; want_hypr=""; yes=""; nodeps=""; purge=""; mode=""; uninstall=""
for a in "$@"; do
    case "$a" in
        --niri) want_niri=1 ;;
        --hyprland|--hypr) want_hypr=1 ;;
        --all) want_niri=1; want_hypr=1 ;;
        --light) mode=light ;;
        --full) mode=full ;;
        --yes|-y) yes=1 ;;
        --no-deps) nodeps=1 ;;
        --purge) purge=1 ;;
        --uninstall) uninstall=1 ;;
        -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
        *) echo "unknown option: $a"; exit 1 ;;
    esac
done

[ -d "$here/installer" ] || { echo "installer/ folder not found next to install.sh"; exit 1; }
. "$here/installer/lib.sh"

if [ -n "$uninstall" ]; then
    . "$here/installer/uninstall.sh"
    exit 0
fi

# ── 1. compositors ──
if [ -z "$want_niri$want_hypr" ]; then
    [ -d "$cfg/niri" ] && want_niri=1
    [ -d "$cfg/hypr" ] && want_hypr=1
    if [ -z "$want_niri$want_hypr" ]; then
        command -v niri >/dev/null 2>&1 && want_niri=1
        command -v Hyprland >/dev/null 2>&1 && want_hypr=1
    fi
    [ -z "$want_niri$want_hypr" ] && { echo "niri / Hyprland not found: use --niri, --hyprland or --all"; exit 1; }
fi
step "1/6" "Looking for niri / Hyprland"
[ -n "$want_niri" ] && say "niri: found"
[ -n "$want_hypr" ] && say "Hyprland: found"

# ── which kind of install ──
if [ -z "$mode" ]; then
    if [ -n "$yes" ]; then
        mode=light
    else
        cat <<'M'

    Which kind of install?

      1) LIGHT  (recommended if you already have your own config)
         Installs the shell and adds only a few lines to your niri / Hyprland config
         (an include for the shell shortcuts + the startup of the shell).
         Your config is not replaced. If a shortcut is already yours, it is skipped
         and listed at the end.

      2) FULL   (what the author uses)
         Also installs the author's compositor config (gaps, rules, window shortcuts,
         animations...). Your config.kdl / hyprland.lua are replaced, a backup is saved first.

M
        printf '    Choose [1/2] (default 1): '
        read -r c </dev/tty || c=1
        case "$c" in 2) mode=full ;; *) mode=light ;; esac
    fi
fi
say "install type: $mode"

. "$here/installer/deps.sh"       # 2. programs
mkdir -p "$bk"
step "3/6" "Backup of what will be replaced"
say "backup in $bk"
. "$here/installer/shells.sh"      # 4. other shells
. "$here/installer/shell.sh"       # 5. the shell itself

if [ "$mode" = full ]; then
    . "$here/installer/full.sh"
else
    [ -n "$want_niri" ] && . "$here/installer/light-niri.sh"
    [ -n "$want_hypr" ] && . "$here/installer/light-hypr.sh"
fi

. "$here/installer/finish.sh"      # 6. wallpapers, Firefox, autostart, start
