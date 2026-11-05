# Step 2: the programs the shell needs (sourced by install.sh)
# ── dependencies ──
# command:package (Arch). awww can be swww, magick can be convert.
deps="qs:quickshell awww:awww wal:python-pywal jq:jq grim:grim slurp:slurp wf-recorder:wf-recorder
ffmpeg:ffmpeg wpctl:wireplumber playerctl:playerctl brightnessctl:brightnessctl cava:cava
cliphist:cliphist wl-mirror:wl-mirror magick:imagemagick notify-send:libnotify
inotifywait:inotify-tools pywalfox:python-pywalfox xdg-user-dir:xdg-user-dirs"

if [ -z "$nodeps" ]; then
    step "2/6" "Checking the programs the shell needs"
    miss_cmd=""; miss_pkg=""
    for d in $deps; do
        c=${d%%:*}; p=${d#*:}
        if have "$c"; then say "ok       $c"; else say "MISSING  $c  (package: $p)"; miss_cmd="$miss_cmd $c"; miss_pkg="$miss_pkg $p"; fi
    done
    if [ -z "$miss_pkg" ]; then
        say "everything is installed"
    elif ! command -v pacman >/dev/null 2>&1; then
        say "this is not Arch: install these with your package manager:$miss_pkg"
    else
        r=y
        if [ -z "$yes" ]; then
            printf '    Install the missing packages now? [Y/n] '
            read -r r </dev/tty || r=y
        fi
        case "$r" in
            n|N) say "skipped: install later:$miss_pkg" ;;
            *)
                repo=""; aur=""
                for p in $miss_pkg; do
                    if pacman -Si "$p" >/dev/null 2>&1; then repo="$repo $p"; else aur="$aur $p"; fi
                done
                if [ -n "$repo" ]; then
                    say "installing from the official repositories:$repo"
                    sudo pacman -S --needed --noconfirm $repo || say "pacman failed: continuing"
                fi
                if [ -n "$aur" ]; then
                    helper=""
                    command -v paru >/dev/null 2>&1 && helper=paru
                    [ -z "$helper" ] && command -v yay >/dev/null 2>&1 && helper=yay
                    if [ -n "$helper" ]; then
                        say "installing from the AUR with $helper:$aur"
                        $helper -S --needed --noconfirm $aur || say "$helper failed: continuing"
                    else
                        say "from the AUR (no yay/paru found, install them by hand):$aur"
                    fi
                fi
                if command -v pywalfox >/dev/null 2>&1; then
                    say "registering Pywalfox in Firefox (you still need its Firefox add-on)"
                    pywalfox install >/dev/null 2>&1 || true
                fi
                ;;
        esac
    fi
else
    step "2/6" "Programs check skipped (--no-deps)"
fi
