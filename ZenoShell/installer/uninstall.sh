# --uninstall: takes the lines of this installer out of your config (sourced by install.sh)
# The shell folder is moved to the backup, your own settings are left as they are.

step "1/1" "Uninstall"
mkdir -p "$bk"
for f in "$cfg/niri/config.kdl" "$cfg/hypr/hyprland.lua"; do
    [ -f "$f" ] || continue
    if grep -q "$mark_begin" "$f"; then
        backup "$f"; remove_block "$f"; say "removed our block from $f"
    fi
done
if [ -f "$cfg/niri/quickshell-dots.kdl" ]; then backup "$cfg/niri/quickshell-dots.kdl"; rm -f "$cfg/niri/quickshell-dots.kdl"; say "removed niri/quickshell-dots.kdl"; fi
if [ -d "$cfg/quickshell" ]; then
    mkdir -p "$bk/removed"; mv "$cfg/quickshell" "$bk/removed/quickshell"; say "moved ~/.config/quickshell to the backup"
fi
say "left in place: niri/quickshell*.kdl, hypr/quickshell-*.lua (harmless without the include lines) and the state in ~/.local/state/quickshell"
say "your previous config is in the backups: ls $cfg | grep quickshell-backup"
printf '\n\033[1mDone.\033[0m Reload the compositor to apply.\n'
