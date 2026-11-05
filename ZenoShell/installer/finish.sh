# Step 6: wallpapers, Firefox, autostart, start now (sourced by install.sh)
# ── wallpapers ──
step "6/6" "Wallpapers"
wp=$(sh "$cfg/quickshell/scripts/wallpaper-dir.sh")
mkdir -p "$wp"
say "folder: $wp"
if [ -d "$here/wallpapers" ] && ls "$here/wallpapers" | grep -qiE '\.(jpe?g|png|webp)$'; then
    cp -n "$here/wallpapers/"* "$wp/" 2>/dev/null || true
    say "copied the wallpapers that come with the shell"
fi
n=$(ls "$wp" 2>/dev/null | grep -ciE '\.(jpe?g|png|webp)$' || true)
say "$n image(s) there. Put more in that folder: Alt+W opens the picker."


# ── Firefox: Pywalfox reads the pywal colors (~/.cache/wal/colors) ──
if [ -z "$nodeps" ]; then
    printf '\n'
    if command -v pywalfox >/dev/null 2>&1; then
        say "Firefox: registering the Pywalfox native host (safe to repeat)"
        pywalfox install >/dev/null 2>&1 && say "registered" || say "pywalfox install failed: run it by hand"
    else
        say "Firefox: Pywalfox is not installed (package python-pywalfox, then run: pywalfox install)"
    fi
    say "Firefox also needs the add-on, installed once from the browser:"
    say "  https://addons.mozilla.org/firefox/addon/pywalfox/"
fi

# ── autostart ──
ok_auto=1
if [ -n "$want_niri" ]; then
    grep -hqE 'spawn(-sh)?-at-startup[^\n]*"(quickshell|qs)"' "$cfg"/niri/*.kdl 2>/dev/null || {
        ok_auto=""; say "WARNING: niri does not start the shell. Add to config.kdl:  spawn-at-startup \"quickshell\""; }
fi
if [ -n "$want_hypr" ] && [ -z "$hypr_skipped_all" ]; then
    grep -hqE 'exec_cmd\("(quickshell|qs)"\)' "$cfg"/hypr/*.lua 2>/dev/null || {
        ok_auto=""; say "WARNING: Hyprland does not start the shell. Add in hl.on(\"hyprland.start\"):  hl.exec_cmd(\"qs\")"; }
fi
[ -n "$ok_auto" ] && say "autostart: ok (the shell starts by itself at every login)"

# ── shortcuts that were not installed because you already use them (LIGHT mode) ──
if [ -n "$niri_skipped$hypr_skipped" ]; then
    printf '\n'
    say "These shortcuts were NOT installed because you already use them:"
    [ -n "$niri_skipped" ] && say "  niri:     $niri_skipped"
    [ -n "$hypr_skipped" ] && say "  Hyprland: $hypr_skipped"
    say "The commands still work: for example  qs ipc call theme toggle  (see the README)."
    say "To use one of them, free the key in your config and run the installer again."
fi

# ── start it now, if we are inside a session ──
if [ -n "$WAYLAND_DISPLAY" ] && { [ -n "$NIRI_SOCKET" ] || [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; } && command -v qs >/dev/null 2>&1; then
    r=y
    if [ -z "$yes" ]; then printf '\n    Start the shell now? [Y/n] '; read -r r </dev/tty || r=y; fi
    case "$r" in
        n|N) ;;
        *) pkill -x quickshell 2>/dev/null || true; sleep 0.5
           setsid qs >/dev/null 2>&1 &
           say "shell started" ;;
    esac
fi

printf '\n\033[1mDone.\033[0m Now reload:\n'
[ -n "$want_niri" ] && say "niri:     niri msg action load-config-file"
[ -n "$want_hypr" ] && say "Hyprland: hyprctl reload"
say "shell:    qs kill; qs   (if it is not already running)"
