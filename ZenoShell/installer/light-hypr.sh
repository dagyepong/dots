# LIGHT mode, Hyprland (0.55+, Lua config): adds a block to your hyprland.lua, replaces nothing. Sourced by install.sh
#
#   ~/.config/hypr/quickshell-binds.lua    the shell shortcuts only, minus the keys you already use
#   ~/.config/hypr/hyprland.lua            +1 block between two markers (autostart, monitors, shortcuts)

step "5c/6" "Hyprland: LIGHT mode (adds a block, replaces nothing)"
hd="$cfg/hypr"
conf="$hd/hyprland.lua"
mkdir -p "$hd"

if [ ! -f "$conf" ]; then
    if ls "$hd"/hyprland.conf >/dev/null 2>&1; then
        say "your Hyprland config is hyprland.conf: LIGHT mode needs the Lua config (Hyprland 0.55+)."
        say "Skipping Hyprland. Convert your config to hyprland.lua, or use --full (it replaces it, backup saved)."
        hypr_skipped_all=1
        return 0 2>/dev/null || true
    fi
    say "no $conf: creating a minimal one"
    printf -- '-- Hyprland config\n' > "$conf"
fi
backup "$conf"

tmpd=$(mktemp -d)
skiplog="$tmpd/skipped"; : > "$skiplog"
cp "$conf" "$tmpd/user.lua"; remove_block "$tmpd/user.lua"
others=""
for f in "$hd"/*.lua; do
    case "$(basename "$f")" in quickshell-binds.lua|quickshell-outputs.lua|hyprland.lua) continue ;; esac
    [ -f "$f" ] && others="$others $f"
done
awk -f "$here/installer/keys.awk" -f "$here/installer/lua-keys.awk" "$tmpd/user.lua" $others 2>/dev/null | sort -u > "$tmpd/userkeys"

awk -v logf="$skiplog" -f "$here/installer/keys.awk" -f "$here/installer/lua-filter.awk" "$tmpd/userkeys" "$here/hypr/quickshell-binds.lua" > "$hd/quickshell-binds.lua"
say "shortcuts: $(grep -cE '^[ \t]*bind[ \t]*\(' "$hd/quickshell-binds.lua") installed, $(sort -u "$skiplog" | wc -l) skipped because you already use them"
[ -e "$hd/quickshell-outputs.lua" ] || cp "$here/hypr/quickshell-outputs.lua" "$hd/quickshell-outputs.lua"

# what the block does is skipped when the user already has it
{
    echo '-- Monitors chosen from the Monitors page of the shell (file managed by Quickshell)'
    echo 'pcall(function() package.loaded["quickshell-outputs"] = nil; require("quickshell-outputs").apply() end)'
    echo
    echo '-- Startup'
    echo 'hl.on("hyprland.start", function()'
    grep -qE 'exec_cmd\("(quickshell|qs)"\)' "$tmpd/user.lua" || echo '    hl.exec_cmd("qs")'
    echo '    hl.exec_cmd("sh ~/.config/quickshell/scripts/restore-wallpaper.sh")'
    echo '    hl.exec_cmd("mkdir -p ~/Screenshots")'
    echo '    hl.exec_cmd("sh ~/.config/quickshell/scripts/pywalfox-watch.sh")'
    echo 'end)'
    echo
    echo '-- Blur behind the welcome screen'
    echo 'pcall(function() hl.layer_rule({ name = "blur-hello", match = { namespace = "shell-hello" }, blur = true }) end)'
    echo
    echo '-- Shell shortcuts (quickshell-binds.lua). package.loaded = nil: also registered again after a reload'
    echo 'do'
    echo '    package.loaded["quickshell-binds"] = nil'
    echo '    local ok, err = pcall(function() require("quickshell-binds").apply() end)'
    echo '    if not ok then hl.exec_cmd("notify-send -u critical Hyprland quickshell-binds.lua-error") end'
    echo 'end'
} > "$tmpd/block"

if grep -qE 'require\("quickshell-binds"\)' "$tmpd/user.lua"; then
    say "hyprland.lua already loads quickshell-binds: nothing to add"
else
    add_block "$conf" "--" "$tmpd/block"
    say "hyprland.lua: added one block (backup in $bk)"
fi

hypr_skipped=$(sort -u "$skiplog" | tr '\n' ' ')
rm -rf "$tmpd"
