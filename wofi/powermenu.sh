#!/usr/bin/env bash

# Options (setiap item di baris baru)
options=$'Lock\nLogout\nReboot\nShutdown'

# Tampilkan wofi dmenu
choice=$(printf "%s" "$options" | wofi --dmenu --prompt "Power:" )

# Jika tidak pilih apa-apa, keluar
[ -z "$choice" ] && exit 0

case "$choice" in
  Lock)
    # lock screen (ganti swaylock kalau pake niri/niri has swaylock)
    swaylock &
    ;;
  Logout)
    # keluar dari session niri
    niri msg action quit
    ;;
  Reboot)
    # reboot (butuh privilege)
    sudo /sbin/reboot
    ;;
  Shutdown)
    # poweroff (butuh privilege)
    sudo /sbin/poweroff
    ;;
esac
