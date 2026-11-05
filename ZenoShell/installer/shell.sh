# Step 5: copy the shell to ~/.config/quickshell (sourced by install.sh)

step "5/6" "Installing the shell"
say "shell -> $cfg/quickshell"
backup "$cfg/quickshell"
mkdir -p "$cfg/quickshell"

# Files of an older version that no longer exist in the repo are removed (they are in the backup).
# Only inside folders that belong to this shell: other shells' files are never touched.
if [ -d "$cfg/quickshell" ]; then
    stale=""
    for f in $(cd "$cfg/quickshell" && find . -type f \( -name '*.qml' -o -name '*.js' -o -name '*.sh' -o -name qmldir \) 2>/dev/null | sed 's|^\./||'); do
        top=${f%%/*}
        if [ "$top" = "$f" ]; then
            [ -e "$here/quickshell/$f" ] && continue
        else
            [ -d "$here/quickshell/$top" ] || continue
            [ -e "$here/quickshell/$f" ] && continue
        fi
        stale="$stale $f"
    done
    for f in $stale; do
        rm -f "$cfg/quickshell/$f"
        say "removed old file: $f"
    done
fi

cp -a "$here/quickshell/." "$cfg/quickshell/"
chmod +x "$cfg/quickshell/scripts/"*.sh
