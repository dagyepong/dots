# LIGHT mode, niri: adds a few lines to your config.kdl, replaces nothing. Sourced by install.sh
#
#   ~/.config/niri/quickshell-dots.kdl   startup programs + layer rules (only what you do not already have)
#   ~/.config/niri/quickshell.kdl        the shell shortcuts, minus the keys you already use
#   ~/.config/niri/config.kdl            +4 "include" lines between two markers

step "5b/6" "niri: LIGHT mode (adds a few lines, replaces nothing)"
nd="$cfg/niri"
conf="$nd/config.kdl"
mkdir -p "$nd"
[ -f "$conf" ] || { say "no $conf: creating a minimal one"; printf '// niri config\n' > "$conf"; }
backup "$conf"

# shortcuts the user already has: every kdl file except the ones this installer writes
others=""
for f in "$nd"/*.kdl; do
    case "$(basename "$f")" in quickshell.kdl|quickshell-dots.kdl|quickshell-outputs.kdl|quickshell-tweaks.kdl) continue ;; esac
    [ -f "$f" ] && others="$others $f"
done
tmpd=$(mktemp -d)
skiplog="$tmpd/skipped"; : > "$skiplog"
# the user's config without our own block, so a second run does not see our keys as "his"
cp "$conf" "$tmpd/user.kdl"; remove_block "$tmpd/user.kdl"
awk -f "$here/installer/keys.awk" -f "$here/installer/niri-keys.awk" "$tmpd/user.kdl" $(for f in $others; do [ "$f" != "$conf" ] && printf '%s ' "$f"; done) 2>/dev/null | sort -u > "$tmpd/userkeys"

awk -v logf="$skiplog" -f "$here/installer/keys.awk" -f "$here/installer/niri-filter.awk" "$tmpd/userkeys" "$here/niri/quickshell.kdl" > "$nd/quickshell.kdl"
say "shortcuts: $(grep -cE '^[ \t]*[A-Z][A-Za-z0-9_+]*([ \t]+[a-z-]+=[^ \t]+)*[ \t]*\{' "$nd/quickshell.kdl") installed, $(sort -u "$skiplog" | wc -l) skipped because you already use them"

# startup + layer rules, only what is missing
{
    echo "// Startup of the shell and layer rules (written by quickshell-dots; regenerated on every install)"
    echo 'spawn-sh-at-startup "mkdir -p ~/Screenshots"'
    grep -qE 'spawn(-sh)?-at-startup.*"(quickshell|qs)"' "$tmpd/user.kdl" || echo 'spawn-at-startup "quickshell"'
    if ! grep -qE 'awww-daemon|swww-daemon' "$tmpd/user.kdl"; then
        if command -v awww >/dev/null 2>&1; then
            echo 'spawn-at-startup "awww-daemon"'
            echo 'spawn-at-startup "awww-daemon" "-n" "backdrop"'
        elif command -v swww >/dev/null 2>&1; then
            echo 'spawn-at-startup "swww-daemon"'
            echo 'spawn-at-startup "swww-daemon" "-n" "backdrop"'
        fi
    fi
    echo 'spawn-sh-at-startup "sleep 1; sh ~/.config/quickshell/scripts/restore-wallpaper.sh"'
    echo 'spawn-sh-at-startup "sh ~/.config/quickshell/scripts/pywalfox-watch.sh"'
    echo
    cat "$here/niri/light-base.kdl"
} > "$nd/quickshell-dots.kdl"

for f in quickshell-outputs.kdl quickshell-tweaks.kdl; do
    [ -e "$nd/$f" ] || cp "$here/niri/$f" "$nd/$f"
done

# the include lines in config.kdl (only if the user does not have them already)
if grep -qE '^[ \t]*include[ \t]+"quickshell\.kdl"' "$tmpd/user.kdl"; then
    say "config.kdl already includes quickshell.kdl: nothing to add"
else
    cat > "$tmpd/block" <<'B'
include "quickshell-dots.kdl"
include "quickshell.kdl"
include "quickshell-outputs.kdl"
include "quickshell-tweaks.kdl"
B
    add_block "$conf" "//" "$tmpd/block"
    say "config.kdl: added 4 include lines (backup in $bk)"
fi

niri_skipped=$(sort -u "$skiplog" | tr '\n' ' ')
rm -rf "$tmpd"
