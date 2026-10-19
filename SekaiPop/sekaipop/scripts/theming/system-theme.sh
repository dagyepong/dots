#!/bin/sh

# Helper for ThemeService.qml: puts the shell's colours on GTK, Qt and KDE apps
# (the way DankMaterialShell does), by running matugen with templates from
# system-templates/, and recolours the apps that are already open.
#
#   system-theme.sh apply source=image|color value=<path|#hex> mode=dark|light
#                         [type=scheme-tonal-spot] [targets=gtk,qt,kde]
#                         [gtktheme=on|off] [scheme=on|off] [force=1]
#                         [reload=on|off|gtk3,gtk4,qt,kde] [bouncedark=on|off]
#   system-theme.sh reload [gtk3|gtk4|qt|kde ...]   only the live-reload steps
#   system-theme.sh check      what is installed / set up, for debugging
#   system-theme.sh revert     undo everything this script wrote
#
# source=image  the colours come from that wallpaper (the "Wallpaper (matugen)" theme)
# source=color  the colours come from that one seed colour (a group theme's accent):
#               matugen builds a full Material scheme around it
#
# WHAT IT WRITES (matugen renders these; nothing else of yours is replaced)
#   gtk   ~/.config/gtk-3.0/sekaipop-colors.css and ~/.config/gtk-4.0/sekaipop-colors.css,
#         plus ONE line `@import url("sekaipop-colors.css");` at the top of each gtk.css
#         (added once; a gtk.css that is a symlink is left alone and you are told).
#         If adw-gtk3 is installed, also a copy of it with the colours added to the theme
#         itself, ~/.local/share/themes/sekaipop-adw-gtk3[-dark], which gtk-theme is set to
#         (GTK3 re-reads a theme from disk when the theme setting changes, but reads the
#         user's gtk.css only once per app, so this copy is what makes GTK3 apps live).
#   qt    ~/.config/qt5ct/colors/sekaipop.conf and ~/.config/qt6ct/colors/sekaipop.conf, and in
#         qt5ct.conf / qt6ct.conf only `color_scheme_path` and `custom_palette=true`
#         (the files are created, with style=Fusion, if they don't exist; style is
#         never changed on an existing file). Stock qt5ct/qt6ct only read this format.
#   kde   a KDE colour scheme, ~/.local/share/color-schemes/SekaipopA.colors or SekaipopB.colors
#         (they take turns), its [Colors:*] / [ColorEffects:*] / [WM] sections merged into
#         ~/.config/kdeglobals (a backup is kept once, as kdeglobals.sekaipop-bak) and
#         [General] ColorScheme there set to it. Dolphin and the other KDE apps read this
#         through QT_QPA_PLATFORMTHEME=kde (plasma-integration); stock qt6ct can't read it.
#   plus, when scheme=on, GNOME's color-scheme setting (prefer-dark / prefer-light).
#   GNOME settings are written with dconf when it is installed (that is what GTK reads),
#   otherwise with gsettings.
#
# LIVE RECOLOURING (reload=on by default; a comma list picks the kinds). After the files are
# written, each kind of open app is told in the way it listens:
#   gtk4  libadwaita apps only re-read their colours when GNOME's color-scheme changes, so it
#         is switched to the opposite value and back (gtk.css is touched too). In LIGHT mode
#         that is a short dark flash. In DARK mode it would be a light flash (browsers and
#         Discord follow the portal's scheme and show it too), so dark mode skips the switch
#         unless bouncedark=on: open libadwaita apps then pick the new colours up the next
#         time they start. Some apps that follow the portal's colour scheme, notably
#         Chromium, can also miss the restore: drop gtk4 from reload= if that happens.
#   gtk3  gtk-theme is switched to another theme and back, so GTK3 apps re-read the theme
#         files (the sekaipop-adw-gtk3 copy above). A dark theme goes through a dark one
#         (Adwaita-dark, or HighContrastInverse), so it never flashes light.
#   qt    qt5ct.conf / qt6ct.conf are replaced last; qt5ct / qt6ct watch their config
#         folder and re-apply the palette in every running Qt app
#   kde   the colour scheme is applied with plasma-apply-colorscheme (two names, A and B,
#         alternate because it ignores a scheme that is already the current one). Without
#         that tool, kdeglobals is updated here and ConfigChanged / notifyChange
#         signals are sent on the session bus (gdbus).
# If the colour scheme or gtk-theme really changed in this run, that change already makes
# apps reload, so the matching switch-and-back is skipped.
#
# It skips the whole run if nothing changed since the last one (a stamp in
# ${XDG_CACHE_HOME:-~/.cache}/sekaipop/system), unless force=1.
#
# Exit codes: 0 done (or nothing to do), 2 bad arguments, 3 matugen ran but an output is
# missing, 127 matugen not installed, anything else is matugen's own.

mode_cmd="$1"
[ $# -gt 0 ] && shift

here="$(cd "$(dirname "$0")" && pwd)"
tpl="$here/system-templates"
cfgdir="${XDG_CONFIG_HOME:-$HOME/.config}"
datadir="${XDG_DATA_HOME:-$HOME/.local/share}"
cachedir="${XDG_CACHE_HOME:-$HOME/.cache}/sekaipop/system"
stamp="$cachedir/stamp"

gtk3_css="$cfgdir/gtk-3.0/sekaipop-colors.css"
gtk4_css="$cfgdir/gtk-4.0/sekaipop-colors.css"
qt5_conf="$cfgdir/qt5ct/colors/sekaipop.conf"
qt6_conf="$cfgdir/qt6ct/colors/sekaipop.conf"
kde_render="$cachedir/kde-colors.colors"
kdeglobals="$cfgdir/kdeglobals"
schemes_dir="$datadir/color-schemes"
themes_dir="$datadir/themes"
import_line='@import url("sekaipop-colors.css");'

say() { printf 'system-theme: %s\n' "$*" >&2; }

# ===== small helpers =====

is_link() { [ -L "$1" ]; }

# ini_set FILE SECTION KEY VALUE: sets KEY=VALUE inside [SECTION], adding the key or the
# whole section (or the file) if it isn't there. Everything else is copied as it was.
ini_set() {
    f="$1"
    if is_link "$f"; then say "$f is a symlink, not editing it (set $3=$4 under [$2] yourself)"; return 0; fi
    mkdir -p "$(dirname "$f")" || return 1
    [ -f "$f" ] || : > "$f"
    SEC="$2" KEY="$3" VAL="$4" awk '
        function put_key() { print ENVIRON["KEY"] "=" ENVIRON["VAL"]; done = 1 }
        function release() { for (; held > 0; held--) print ""; }
        function close_section() { if (insec && !done) put_key(); release() }
        /^\[.*\][ \t]*$/ {
            close_section()
            insec = ($0 == "[" ENVIRON["SEC"] "]")
            if (insec) seen = 1
            print
            next
        }
        insec && /^[ \t]*$/ { held++; next }
        insec && index($0, ENVIRON["KEY"] "=") == 1 {
            release()
            if (!done) put_key()
            next
        }
        { release(); print }
        END {
            if (!seen) {
                if (NR > 0) print ""
                print "[" ENVIRON["SEC"] "]"
                print ENVIRON["KEY"] "=" ENVIRON["VAL"]
            } else close_section()
        }
    ' "$f" > "$f.sekaipop-tmp" && mv "$f.sekaipop-tmp" "$f"
}

# ensure_import FILE: puts the @import line at the top of a gtk.css, once.
ensure_import() {
    f="$1"
    if is_link "$f"; then
        say "$f is a symlink, not editing it. Add this line to it yourself: $import_line"
        return 0
    fi
    mkdir -p "$(dirname "$f")" || return 1
    if [ -f "$f" ]; then
        grep -qF 'sekaipop-colors.css' "$f" && return 0
        { printf '%s\n' "$import_line"; cat "$f"; } > "$f.sekaipop-tmp" && mv "$f.sekaipop-tmp" "$f"
    else
        printf '%s\n' "$import_line" > "$f"
    fi
}

# merge_kde SRC DST: replaces the [Colors:*], [ColorEffects:*] and [WM] sections of DST with
# the ones in SRC (a KDE colour scheme). Nothing else in DST is touched.
merge_kde() {
    src="$1"; dst="$2"
    if is_link "$dst"; then say "$dst is a symlink, not editing it"; return 0; fi
    if [ -f "$dst" ]; then
        [ -f "$dst.sekaipop-bak" ] || cp "$dst" "$dst.sekaipop-bak"
        awk '/^\[/ { skip = ($0 ~ /^\[(Colors:|ColorEffects:|WM\])/) } !skip { print }' "$dst" > "$dst.sekaipop-tmp" || return 1
        # one blank line between what stays and what we add
        if [ -s "$dst.sekaipop-tmp" ]; then
            tail -n 1 "$dst.sekaipop-tmp" | grep -q '^[[:space:]]*$' || printf '\n' >> "$dst.sekaipop-tmp"
        fi
    else
        mkdir -p "$(dirname "$dst")" || return 1
        : > "$dst.sekaipop-tmp"
    fi
    awk '/^\[/ { keep = ($0 ~ /^\[(Colors:|ColorEffects:|WM\])/) } keep { print }' "$src" >> "$dst.sekaipop-tmp" \
        && mv "$dst.sekaipop-tmp" "$dst"
}

# GNOME interface settings. dconf is what GTK actually reads; a `gsettings` from a GLib
# without the dconf backend can succeed without changing anything, so dconf goes first.
iface_get() {
    v=""
    if command -v dconf >/dev/null 2>&1; then
        v="$(dconf read "/org/gnome/desktop/interface/$1" 2>/dev/null | tr -d "'")"
    fi
    if [ -z "$v" ] && command -v gsettings >/dev/null 2>&1; then
        v="$(gsettings get org.gnome.desktop.interface "$1" 2>/dev/null | tr -d "'")"
    fi
    printf '%s' "$v"
}
iface_set() {
    if command -v dconf >/dev/null 2>&1; then
        dconf write "/org/gnome/desktop/interface/$1" "'$2'" 2>/dev/null && return 0
    fi
    command -v gsettings >/dev/null 2>&1 && gsettings set org.gnome.desktop.interface "$1" "$2" 2>/dev/null
}
have_iface_tool() { command -v dconf >/dev/null 2>&1 || command -v gsettings >/dev/null 2>&1; }

# find_theme NAME: prints the folder of an installed GTK theme.
find_theme() {
    for d in "$themes_dir" "$HOME/.themes" /usr/share/themes /usr/local/share/themes; do
        [ -d "$d/$1" ] && { printf '%s' "$d/$1"; return 0; }
    done
    return 1
}

# build_gtk3_theme MODE: copies adw-gtk3 (adw-gtk3-dark for dark) to
# ~/.local/share/themes/sekaipop-<that> with the rendered colours added at the end of its
# CSS, and prints the new theme's name. Prints nothing and fails if adw-gtk3 isn't installed
# or the target folder is somebody else's.
build_gtk3_theme() {
    base=adw-gtk3; [ "$1" = dark ] && base=adw-gtk3-dark
    src="$(find_theme "$base")" || return 1
    name="sekaipop-$base"
    dst="$themes_dir/$name"
    if [ -e "$dst" ] && [ ! -f "$dst/.sekaipop" ]; then
        say "$dst exists and is not ours, not touching it"
        return 1
    fi
    rm -rf "$dst.tmp"
    mkdir -p "$themes_dir" && cp -rL "$src" "$dst.tmp" || { rm -rf "$dst.tmp"; return 1; }
    for f in "$dst.tmp/gtk-3.0/gtk.css" "$dst.tmp/gtk-3.0/gtk-dark.css" "$dst.tmp/gtk-4.0/gtk.css" "$dst.tmp/gtk-4.0/gtk-dark.css"; do
        if [ -f "$f" ]; then
            chmod u+w "$f" 2>/dev/null
            { printf '\n'; cat "$gtk3_css"; } >> "$f"
        fi
    done
    : > "$dst.tmp/.sekaipop"
    rm -rf "$dst" && mv "$dst.tmp" "$dst" || return 1
    printf '%s' "$name"
}

# Writes the next scheme file (SekaipopA / SekaipopB, alternating) and nothing else.
# kdeglobals is NOT touched here on purpose: plasma-apply-colorscheme has to be the one that changes it.
# If we wrote the new colours into kdeglobals first, it would find nothing to change, KDE would send
# no "colours changed" signal, and an open Dolphin would keep the old colours until restarted.
kde_publish() {
    [ -s "$kde_render" ] || { say "no KDE colours rendered yet (run apply first)"; return 1; }
    if [ "$(cat "$cachedir/kde-slot" 2>/dev/null)" = A ]; then slot=B; else slot=A; fi
    kde_scheme="Sekaipop$slot"
    mkdir -p "$schemes_dir" || return 1
    sed "s/@@NAME@@/$kde_scheme/g" "$kde_render" > "$schemes_dir/$kde_scheme.colors" || return 1
    printf '%s\n' "$slot" > "$cachedir/kde-slot"
}

# Puts the scheme into kdeglobals ourselves: only when plasma-apply-colorscheme is missing or failed,
# or live update is off (then nothing else would save the colours).
kde_commit_manual() {
    [ -n "${kde_scheme:-}" ] || return 1
    merge_kde "$schemes_dir/$kde_scheme.colors" "$kdeglobals"
    ini_set "$kdeglobals" General ColorScheme "$kde_scheme"
}

# The signal KDE itself sends when the palette changes (plasma-integration repaints open apps on it).
kde_notify_palette() {
    if command -v dbus-send >/dev/null 2>&1; then
        dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:0 int32:0 >/dev/null 2>&1
    elif command -v gdbus >/dev/null 2>&1; then
        gdbus emit --session --object-path /KGlobalSettings --signal org.kde.KGlobalSettings.notifyChange 0 0 >/dev/null 2>&1
    fi
}

# ===== live reload =====
bounce_gap=0.25
pause() { sleep "$bounce_gap" 2>/dev/null || :; }

# Replaces a file by a copy of itself: a rename, which watchers of the folder notice.
retouch() {
    [ -f "$1" ] && ! is_link "$1" || return 0
    cp -p "$1" "$1.sekaipop-tmp" && mv "$1.sekaipop-tmp" "$1"
}

reload_gtk3() {
    have_iface_tool || { say "reload gtk3: neither dconf nor gsettings found"; return 0; }
    cur="$(iface_get gtk-theme)"
    [ -n "$cur" ] || { say "reload gtk3: no gtk-theme set"; return 0; }
    # Rest on a theme of the same lightness, so dark never flashes light.
    case "$cur" in
        *[Dd]ark*|HighContrastInverse)
            if find_theme Adwaita-dark >/dev/null; then tmp=Adwaita-dark; else tmp=HighContrastInverse; fi
            [ "$cur" = "$tmp" ] && tmp=HighContrastInverse
            [ "$cur" = "$tmp" ] && tmp=Adwaita-dark
            ;;
        *)  tmp=Adwaita; [ "$cur" = Adwaita ] && tmp=HighContrast ;;
    esac
    iface_set gtk-theme "$tmp"
    pause
    iface_set gtk-theme "$cur"
}

reload_gtk4() {
    have_iface_tool || { say "reload gtk4: neither dconf nor gsettings found"; return 0; }
    retouch "$cfgdir/gtk-3.0/gtk.css"
    retouch "$cfgdir/gtk-4.0/gtk.css"
    cur="$(iface_get color-scheme)"
    [ -n "$cur" ] || cur=default
    # Dark has no dark stand-in: the only other values are light ones. Don't flash light.
    if [ "$cur" = prefer-dark ] && [ "${bouncedark:-on}" != on ]; then
        say "reload gtk4: dark mode, skipping the colour-scheme switch (open libadwaita apps recolour on their next start; Settings > Desktop > System colours turns the switch back on)"
        return 0
    fi
    if [ "$cur" = prefer-dark ]; then tmp=prefer-light; elif [ "$cur" = prefer-light ]; then tmp=prefer-dark; else tmp=prefer-light; fi
    iface_set color-scheme "$tmp"
    pause
    iface_set color-scheme "$cur"
    [ "$(iface_get color-scheme)" = "$cur" ] || iface_set color-scheme "$cur"
}

# qt5ct / qt6ct watch their own config folder and re-apply the palette when something in it
# is created, renamed or removed.
reload_qt() {
    retouch "$cfgdir/qt5ct/qt5ct.conf"
    retouch "$cfgdir/qt6ct/qt6ct.conf"
}

reload_kde() {
    [ -n "${kde_scheme:-}" ] || kde_publish || return 0
    if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
        if out="$(plasma-apply-colorscheme "$kde_scheme" 2>&1)"; then
            kde_done=1
            kde_notify_palette
            say "kde: $kde_scheme applied with plasma-apply-colorscheme"
            return 0
        fi
        say "reload kde: plasma-apply-colorscheme failed ($out), writing kdeglobals ourselves and sending the signals by hand"
    fi
    kde_commit_manual && kde_done=1
    command -v gdbus >/dev/null 2>&1 || { kde_notify_palette; say "reload kde: neither plasma-apply-colorscheme nor gdbus found, KDE apps repaint when restarted"; return 0; }
    gdbus emit --session --object-path /kdeglobals --signal org.kde.kconfig.notify.ConfigChanged \
        "{'General': @aay [], 'Colors:View': @aay [], 'Colors:Window': @aay [], 'Colors:Button': @aay [], 'Colors:Selection': @aay [], 'Colors:Tooltip': @aay [], 'Colors:Complementary': @aay [], 'Colors:Header': @aay []}" \
        >/dev/null 2>&1 || say "reload kde: gdbus could not send ConfigChanged (no session bus?)"
    kde_notify_palette
}

# do_reload TARGET...: the steps for the given kinds (gtk3 gtk4 qt kde). theme_changed and
# cs_changed (set by apply) skip the switch-and-back that the change itself already caused.
do_reload() {
    for t in "$@"; do
        case "$t" in
            gtk3) [ "${theme_changed:-0}" = 1 ] || reload_gtk3 ;;
            gtk4) [ "${cs_changed:-0}" = 1 ] || reload_gtk4 ;;
            qt)   reload_qt ;;
            kde)  reload_kde ;;
            *)    say "reload: unknown kind $t (gtk3 gtk4 qt kde)" ;;
        esac
    done
}

# ===== check =====
do_check() {
    if command -v matugen >/dev/null 2>&1; then
        echo "matugen:        $(command -v matugen) ($(matugen --version 2>&1 | head -n 1))"
    else
        echo "matugen:        NOT FOUND on PATH ($PATH)"
    fi
    for f in gtk-colors.css qt5ct-colors.conf qt6ct-colors.conf kde-colors.colors; do
        echo "template:       $f ($([ -f "$tpl/$f" ] && echo ok || echo MISSING))"
    done
    echo "dconf:          $(command -v dconf || echo 'not found (gsettings is used for GNOME settings; if it has no dconf backend nothing is changed)')"
    echo "gsettings:      $(command -v gsettings || echo 'not found')"
    if have_iface_tool; then
        echo "  color-scheme: $(iface_get color-scheme)"
        echo "  gtk-theme:    $(iface_get gtk-theme)"
    else
        echo "  neither dconf nor gsettings: GNOME settings are not set, GTK apps are not recoloured live"
    fi
    echo "gdbus:          $(command -v gdbus || echo 'not found (only matters for KDE apps when plasma-apply-colorscheme is missing too)')"
    echo "plasma-apply-colorscheme: $(command -v plasma-apply-colorscheme || echo 'not found (KDE apps are told through D-Bus signals instead, less certain)')"
    if find_theme adw-gtk3 >/dev/null; then echo "adw-gtk3:       installed (GTK3 apps get the sekaipop-adw-gtk3 copy and can recolour live)"; else echo "adw-gtk3:       NOT installed (GTK3 apps can't recolour live; install adw-gtk3)"; fi
    echo "qt5ct / qt6ct:  $(command -v qt5ct || echo 'qt5ct missing') / $(command -v qt6ct || echo 'qt6ct missing')"
    echo "QT_QPA_PLATFORMTHEME in this shell: '${QT_QPA_PLATFORMTHEME:-}'"
    case "${QT_QPA_PLATFORMTHEME:-}" in
        kde) echo "  kde: Dolphin and the other KDE apps follow the SekaipopA/B colour scheme (needs plasma-integration)" ;;
        qt5ct|qt6ct) echo "  $QT_QPA_PLATFORMTHEME: plain Qt apps follow the qt*ct palette, but Dolphin and other KDE apps do NOT follow the colour scheme this way (stock qt6ct can't read KDE schemes). Use QT_QPA_PLATFORMTHEME=kde for them." ;;
        *) echo "  not kde / qt5ct / qt6ct: Qt apps ignore these colours. Set it before the apps start, e.g. in hyprland.conf: env = QT_QPA_PLATFORMTHEME,kde" ;;
    esac
    for f in "$cfgdir/gtk-3.0/gtk.css" "$cfgdir/gtk-4.0/gtk.css"; do
        if [ -L "$f" ]; then s="symlink (will not be edited)"; elif grep -qF sekaipop-colors.css "$f" 2>/dev/null; then s="imports sekaipop-colors.css"; elif [ -f "$f" ]; then s="exists, import not added yet"; else s="missing (created on the first apply)"; fi
        echo "$f: $s"
    done
    for f in "$gtk3_css" "$gtk4_css" "$qt5_conf" "$qt6_conf" "$schemes_dir/SekaipopA.colors" "$schemes_dir/SekaipopB.colors" "$themes_dir/sekaipop-adw-gtk3" "$themes_dir/sekaipop-adw-gtk3-dark"; do
        echo "output:         $f ($([ -e "$f" ] && echo exists || echo 'not written yet'))"
    done
    echo "kdeglobals:     $kdeglobals ($([ -L "$kdeglobals" ] && echo symlink || { [ -f "$kdeglobals" ] && echo "exists, ColorScheme=$(sed -n 's/^ColorScheme=//p' "$kdeglobals" | head -n 1)" || echo missing; }))"
    pinned="$(grep -l '^ColorScheme=' "$cfgdir"/*rc 2>/dev/null | tr '\n' ' ')"
    [ -n "$pinned" ] && echo "KDE apps with their own colour scheme (they ignore the system one, delete the ColorScheme= line or pick \"Default\" in the app): $pinned"
    echo "last stamp:     $(cat "$stamp" 2>/dev/null || echo none)"
}

# ===== hints (short list of what stops apps following, for Settings) =====
# one line each: "<short> :: <long>"
do_hints() {
    command -v matugen >/dev/null 2>&1 || { echo "matugen is not installed :: Install matugen (it is not on the shell's PATH). Nothing below works without it"; return 0; }
    case "${QT_QPA_PLATFORMTHEME:-}" in
        kde) ;;
        qt5ct|qt6ct) echo "KDE apps ignore the colours :: QT_QPA_PLATFORMTHEME is $QT_QPA_PLATFORMTHEME. Plain Qt apps follow it, but Dolphin and other KDE apps do not. Put env = QT_QPA_PLATFORMTHEME,kde in hyprland.conf (needs plasma-integration) and log in again" ;;
        *) echo "Qt apps ignore the colours :: QT_QPA_PLATFORMTHEME is empty in the shell. Put env = QT_QPA_PLATFORMTHEME,kde in hyprland.conf (needs plasma-integration) and log in again" ;;
    esac
    have_iface_tool || echo "dconf/gsettings missing :: Neither dconf nor gsettings was found, so GTK apps are not recoloured live"
    find_theme adw-gtk3 >/dev/null || echo "Install adw-gtk3 :: adw-gtk3 is missing, so GTK3 apps cannot recolour live"
    if ! command -v plasma-apply-colorscheme >/dev/null 2>&1; then
        echo "plasma-apply-colorscheme missing :: KDE apps are told by D-Bus signals instead, which is less sure. The command usually comes with plasma-workspace"
    fi
    pinned="$(grep -l '^ColorScheme=' "$cfgdir"/*rc 2>/dev/null | sed 's|.*/||' | tr '\n' ' ')"
    [ -n "$pinned" ] && echo "Some KDE apps keep their own colours :: $pinned have their own ColorScheme= line, so they ignore the system one. Delete that line or pick Default in the app"
    return 0
}

# ===== revert =====
do_revert() {
    for f in "$cfgdir/gtk-3.0/gtk.css" "$cfgdir/gtk-4.0/gtk.css"; do
        if [ -f "$f" ] && ! is_link "$f"; then
            # grep exits 1 when nothing is left to print (a file that was only our line)
            grep -vF 'sekaipop-colors.css' "$f" > "$f.sekaipop-tmp"
            if [ $? -le 1 ]; then mv "$f.sekaipop-tmp" "$f"; else rm -f "$f.sekaipop-tmp"; fi
            [ -s "$f" ] || rm -f "$f"
        fi
    done
    cur="$(iface_get gtk-theme)"
    case "$cur" in sekaipop-adw-gtk3|sekaipop-adw-gtk3-dark) iface_set gtk-theme "${cur#sekaipop-}" ;; esac
    for t in sekaipop-adw-gtk3 sekaipop-adw-gtk3-dark; do
        [ -f "$themes_dir/$t/.sekaipop" ] && rm -rf "$themes_dir/$t"
    done
    rm -f "$gtk3_css" "$gtk4_css" "$qt5_conf" "$qt6_conf" "$kde_render" "$stamp" "$cachedir/kde-slot" \
          "$schemes_dir/SekaipopA.colors" "$schemes_dir/SekaipopB.colors"
    for q in qt5ct qt6ct; do
        [ -f "$cfgdir/$q/$q.conf" ] && ini_set "$cfgdir/$q/$q.conf" Appearance custom_palette false
    done
    if [ -f "$kdeglobals.sekaipop-bak" ] && ! is_link "$kdeglobals"; then
        cp "$kdeglobals.sekaipop-bak" "$kdeglobals" && rm -f "$kdeglobals.sekaipop-bak"
        say "kdeglobals restored from its backup"
    fi
    say "reverted (the GNOME color-scheme setting was left as it is)"
}

# ===== apply =====
do_apply() {
    source=""; value=""; mode="dark"; type="scheme-tonal-spot"; targets="gtk,qt,kde"
    gtktheme="on"; scheme="off"; reload="on"; force=""; bouncedark="on"
    for a in "$@"; do
        case "$a" in
            source=*)   source="${a#*=}" ;;
            value=*)    value="${a#*=}" ;;
            mode=*)     mode="${a#*=}" ;;
            type=*)     type="${a#*=}" ;;
            targets=*)  targets="${a#*=}" ;;
            gtktheme=*) gtktheme="${a#*=}" ;;
            scheme=*)   scheme="${a#*=}" ;;
            reload=*)   reload="${a#*=}" ;;
            force=*)    force="${a#*=}" ;;
            bouncedark=*) bouncedark="${a#*=}" ;;
        esac
    done
    case "$source" in image|color) ;; *) say "source must be image or color"; exit 2 ;; esac
    case "$mode" in dark|light) ;; *) say "mode must be dark or light"; exit 2 ;; esac
    [ -n "$value" ] || { say "no value given"; exit 2; }
    if [ "$source" = image ]; then
        [ -f "$value" ] || { say "no such image: $value"; exit 2; }
    else
        case "$value" in
            \#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) ;;
            *) say "colour must look like #rrggbb: $value"; exit 2 ;;
        esac
    fi
    command -v matugen >/dev/null 2>&1 || { say "matugen is not installed (not on the shell's PATH)"; exit 127; }

    want() { case ",$targets," in *",$1,"*) return 0 ;; esac; return 1; }

    # Skip when nothing changed and the files are all still there.
    now="$source|$value|$mode|$type|$targets|$gtktheme|$scheme"
    if [ -z "$force" ] && [ "$(cat "$stamp" 2>/dev/null)" = "$now" ]; then
        ok=1
        want gtk && { [ -f "$gtk3_css" ] && [ -f "$gtk4_css" ] || ok=0; }
        want qt  && { [ -f "$qt6_conf" ] || ok=0; }
        want kde && { [ -f "$schemes_dir/SekaipopA.colors" ] || [ -f "$schemes_dir/SekaipopB.colors" ] || ok=0; }
        [ "$ok" = 1 ] && exit 0
    fi

    mkdir -p "$cachedir" || exit 1
    cfg="$cachedir/config.toml"
    {
        printf '[config]\n'
        if want gtk; then
            mkdir -p "$cfgdir/gtk-3.0" "$cfgdir/gtk-4.0" || exit 1
            printf "\n[templates.sekaipop-gtk3]\ninput_path = '%s'\noutput_path = '%s'\n" "$tpl/gtk-colors.css" "$gtk3_css"
            printf "\n[templates.sekaipop-gtk4]\ninput_path = '%s'\noutput_path = '%s'\n" "$tpl/gtk-colors.css" "$gtk4_css"
        fi
        if want qt; then
            mkdir -p "$cfgdir/qt5ct/colors" "$cfgdir/qt6ct/colors" || exit 1
            printf "\n[templates.sekaipop-qt5ct]\ninput_path = '%s'\noutput_path = '%s'\n" "$tpl/qt5ct-colors.conf" "$qt5_conf"
            printf "\n[templates.sekaipop-qt6ct]\ninput_path = '%s'\noutput_path = '%s'\n" "$tpl/qt6ct-colors.conf" "$qt6_conf"
        fi
        if want kde; then
            printf "\n[templates.sekaipop-kde]\ninput_path = '%s'\noutput_path = '%s'\n" "$tpl/kde-colors.colors" "$kde_render"
        fi
    } > "$cfg" || exit 1
    want kde && rm -f "$kde_render"

    # matugen's flags differ between versions: try the full set, then drop them one
    # group at a time (same ladder matugen-state.sh uses).
    if [ "$source" = image ]; then
        matugen image "$value" --config "$cfg" --mode "$mode" --type "$type" --source-color-index 0 --quiet
        rc=$?
        if [ "$rc" -ne 0 ]; then
            say "run failed (exit $rc), retrying without --quiet"
            matugen image "$value" --config "$cfg" --mode "$mode" --type "$type" --source-color-index 0
            rc=$?
        fi
        if [ "$rc" -ne 0 ]; then
            say "run failed (exit $rc), retrying without --source-color-index (older matugen)"
            matugen image "$value" --config "$cfg" --mode "$mode" --type "$type"
            rc=$?
        fi
    else
        matugen color hex "$value" --config "$cfg" --mode "$mode" --type "$type" --quiet
        rc=$?
        if [ "$rc" -ne 0 ]; then
            say "run failed (exit $rc), retrying without --quiet"
            matugen color hex "$value" --config "$cfg" --mode "$mode" --type "$type"
            rc=$?
        fi
    fi
    [ "$rc" -eq 0 ] || exit "$rc"

    missing=""
    want gtk && for f in "$gtk3_css" "$gtk4_css"; do [ -s "$f" ] || missing="$missing $f"; done
    want qt  && for f in "$qt5_conf" "$qt6_conf"; do [ -s "$f" ] || missing="$missing $f"; done
    want kde && { [ -s "$kde_render" ] || missing="$missing $kde_render"; }
    if [ -n "$missing" ]; then
        say "matugen exited fine but these were not written (template not rendered?):$missing"
        exit 3
    fi

    # ===== wire the files in =====
    if want gtk; then
        ensure_import "$cfgdir/gtk-3.0/gtk.css"
        ensure_import "$cfgdir/gtk-4.0/gtk.css"
    fi
    if want qt; then
        # Fusion is only the default for a file that doesn't exist yet.
        [ -e "$cfgdir/qt5ct/qt5ct.conf" ] || ini_set "$cfgdir/qt5ct/qt5ct.conf" Appearance style Fusion
        [ -e "$cfgdir/qt6ct/qt6ct.conf" ] || ini_set "$cfgdir/qt6ct/qt6ct.conf" Appearance style Fusion
        ini_set "$cfgdir/qt5ct/qt5ct.conf" Appearance color_scheme_path "$qt5_conf"
        ini_set "$cfgdir/qt5ct/qt5ct.conf" Appearance custom_palette true
        ini_set "$cfgdir/qt6ct/qt6ct.conf" Appearance color_scheme_path "$qt6_conf"
        ini_set "$cfgdir/qt6ct/qt6ct.conf" Appearance custom_palette true
    fi
    kde_scheme=""; kde_done=0
    want kde && kde_publish

    # ===== GNOME settings =====
    cs_changed=0; theme_changed=0
    if [ "$scheme" = on ]; then
        if [ "$mode" = dark ]; then want_cs=prefer-dark; else want_cs=prefer-light; fi
        if [ "$(iface_get color-scheme)" != "$want_cs" ]; then
            iface_set color-scheme "$want_cs" && cs_changed=1
        fi
    fi
    if want gtk && [ "$gtktheme" = on ] && have_iface_tool; then
        if [ "$mode" = dark ]; then base=adw-gtk3-dark; else base=adw-gtk3; fi
        if find_theme "$base" >/dev/null; then
            gt="$(build_gtk3_theme "$mode")" || gt="$base"
            if [ "$(iface_get gtk-theme)" != "$gt" ]; then
                iface_set gtk-theme "$gt" && theme_changed=1
            fi
        fi
    fi

    # ===== live =====
    case "$reload" in
        on|1|yes|true) reload="gtk3,gtk4,qt,kde" ;;
        off|0|no|false|"") reload="" ;;
    esac
    rt=""
    for k in $(printf '%s' "$reload" | tr ',' ' '); do
        case "$k" in
            gtk3|gtk4) want gtk && rt="$rt $k" ;;
            qt)        want qt  && rt="$rt $k" ;;
            kde)       want kde && rt="$rt $k" ;;
            *)         say "reload: unknown kind $k (gtk3 gtk4 qt kde)" ;;
        esac
    done
    [ -n "$rt" ] && do_reload $rt

    # live update off (or the KDE reload did not run): nothing has saved the KDE colours yet
    if want kde && [ "$kde_done" != 1 ]; then kde_commit_manual; fi

    printf '%s\n' "$now" > "$stamp"
}

case "$mode_cmd" in
    apply)  do_apply "$@" ;;
    check)  do_check ;;
    hints)  do_hints ;;
    reload) [ $# -gt 0 ] || set -- gtk3 gtk4 qt kde; do_reload "$@" ;;
    revert) do_revert ;;
    *)
        echo "usage: $0 apply source=image|color value=<path|#hex> mode=dark|light [type=..] [targets=gtk,qt,kde] [gtktheme=on|off] [scheme=on|off] [reload=on|off|gtk3,gtk4,qt,kde] [bouncedark=on|off] [force=1] | reload [gtk3 gtk4 qt kde] | check | hints | revert" >&2
        exit 2
        ;;
esac
