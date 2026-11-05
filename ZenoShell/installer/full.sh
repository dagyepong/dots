# FULL mode: the compositor config of the author replaces yours (a backup is saved first). Sourced by install.sh
step "5b/6" "Compositor config: FULL (replaces config.kdl / hyprland.lua)"
# ── niri ──
if [ -n "$want_niri" ]; then
    say "niri -> $cfg/niri (config.kdl, quickshell.kdl)"
    mkdir -p "$cfg/niri"
    put "$here/niri/config.kdl" "$cfg/niri/config.kdl"
    put "$here/niri/quickshell.kdl" "$cfg/niri/quickshell.kdl"
    # managed by the shell: created only if missing
    for f in quickshell-tweaks.kdl quickshell-outputs.kdl; do
        [ -e "$cfg/niri/$f" ] || cp "$here/niri/$f" "$cfg/niri/$f"
    done
    # leftovers of older setups
    for f in config.kdl.old backdrop.fish noctalia.kdl; do
        [ -e "$cfg/niri/$f" ] && { backup "$cfg/niri/$f"; rm -f "$cfg/niri/$f"; }
    done
fi

# ── Hyprland ──
if [ -n "$want_hypr" ]; then
    say "Hyprland -> $cfg/hypr (hyprland.lua, quickshell-binds.lua)"
    mkdir -p "$cfg/hypr"
    put "$here/hypr/hyprland.lua" "$cfg/hypr/hyprland.lua"
    cp "$here/hypr/quickshell-binds.lua" "$cfg/hypr/quickshell-binds.lua"
    [ -e "$cfg/hypr/quickshell-outputs.lua" ] || cp "$here/hypr/quickshell-outputs.lua" "$cfg/hypr/quickshell-outputs.lua"
    for f in monitors.conf workspaces.conf monitors.lua scripts/record.sh scripts/qs-record.sh pywalfox-autoupdate.sh; do
        [ -e "$cfg/hypr/$f" ] && { backup "$cfg/hypr/$f"; rm -f "$cfg/hypr/$f"; }
    done
fi
