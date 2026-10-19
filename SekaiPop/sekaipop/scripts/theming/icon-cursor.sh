#!/bin/sh

# Helper for IconCursorService.qml: changes the icon theme and the cursor theme of the whole
# session while apps are running, on Wayland and on XWayland.
#
#   icon-cursor.sh list icons|cursors       installed themes, one name per line
#   icon-cursor.sh get                      icons=<name>  cursor=<name>  size=<n>
#   icon-cursor.sh icons <theme>            switch the icon theme
#   icon-cursor.sh cursor <theme> <size>    switch the cursor theme and size
#   icon-cursor.sh restore <theme> <size>   only the live part of `cursor` (used at login,
#                                           because Hyprland forgets its cursor on restart)
#   icon-cursor.sh resolve <theme> <size> <icon name>...
#                                           print  name<TAB>file  for each icon found in that
#                                           theme (and the themes it inherits, then hicolor
#                                           and /usr/share/pixmaps), the way the icon theme
#                                           spec says. The shell uses this for its own icons:
#                                           a running Qt program reads its icon theme once, so
#                                           it can not be told to look again.
#   icon-cursor.sh import <pack> [name]     turn a Windows cursor pack (.zip, a folder, an
#                                           install.inf, or one .cur / .ani) into a cursor
#                                           theme in ~/.local/share/icons, so it shows up in
#                                           `list cursors` and in Settings. Animated cursors
#                                           keep their frames and timing. Prints the theme
#                                           name. The work is win-cursor.py (next to this
#                                           file; its header says how roles are found).
#   icon-cursor.sh check                    what is installed / set up, for debugging
#
# WHAT IT WRITES (only the keys named here; nothing else of yours is replaced)
#   gtk    GNOME's icon-theme / cursor-theme / cursor-size (dconf when installed, else
#          gsettings: that is what GTK 3 and 4 read, and open GTK apps follow a change
#          at once), plus gtk-icon-theme-name / gtk-cursor-theme-name / gtk-cursor-theme-size
#          in ~/.config/gtk-3.0/settings.ini and gtk-4.0/settings.ini for apps that read
#          the file instead.
#   qt     icon_theme in [Appearance] of ~/.config/qt5ct/qt5ct.conf and qt6ct/qt6ct.conf
#          (only when that file exists or the matching qt5ct / qt6ct is installed).
#   kde    [Icons] Theme in ~/.config/kdeglobals and [Mouse] cursorTheme / cursorSize in
#          ~/.config/kcminputrc (only when KDE is set up here), then the same D-Bus signals
#          KDE's own settings send, which Dolphin and friends repaint on.
#   x11    Inherits= in ~/.local/share/icons/default/index.theme (what X11 and XWayland
#          clients fall back to for their cursor; ~/.icons/default/index.theme too if it
#          exists), and Xcursor.theme / Xcursor.size in the X resources (xrdb -merge).
#
# LIVE (cursor)
#   hyprctl setcursor <theme> <size>   Hyprland's own cursor, and XWayland's. Hyprland says
#                                      it sets everything except GTK, which is why the GTK
#                                      settings above are written as well.
#   dbus-update-activation-environment XCURSOR_THEME / XCURSOR_SIZE / HYPRCURSOR_THEME /
#                                      HYPRCURSOR_SIZE for apps started from now on.
# Apps that read XCURSOR_THEME once at start-up and never again (some Qt and X11 programs)
# keep their old cursor until they are restarted; there is no signal that reaches them.
#
# LIVE (icons)
#   GTK apps follow GNOME's icon-theme setting. Qt apps follow qt5ct / qt6ct (they watch
#   their config folder) or KDE's signal, depending on QT_QPA_PLATFORMTHEME (`check` shows it).
#
# Exit codes: 0 done, 2 bad arguments or no such theme.

mode_cmd="$1"
[ $# -gt 0 ] && shift

cfgdir="${XDG_CONFIG_HOME:-$HOME/.config}"
datadir="${XDG_DATA_HOME:-$HOME/.local/share}"
kdeglobals="$cfgdir/kdeglobals"
kcminputrc="$cfgdir/kcminputrc"

say() { printf 'icon-cursor: %s\n' "$*" >&2; }

is_link() { [ -L "$1" ]; }

# ini_set FILE SECTION KEY VALUE: sets KEY=VALUE inside [SECTION], adding the key or the
# whole section (or the file) if it isn't there. Everything else is copied as it was.
# (Same helper as in system-theme.sh.)
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

# ===== GNOME interface settings (dconf first, like system-theme.sh) =====
iface_get() {
    v=""
    if command -v dconf >/dev/null 2>&1; then
        v="$(dconf read "/org/gnome/desktop/interface/$1" 2>/dev/null | tr -d "'")"
    fi
    if [ -z "$v" ] && command -v gsettings >/dev/null 2>&1; then
        v="$(gsettings get org.gnome.desktop.interface "$1" 2>/dev/null | tr -d "'")"
    fi
    # No dconf / gsettings, or nothing set there: what gtk-3.0/settings.ini says.
    if [ -z "$v" ] && [ -f "$cfgdir/gtk-3.0/settings.ini" ]; then
        case "$1" in
            icon-theme)   k=gtk-icon-theme-name ;;
            cursor-theme) k=gtk-cursor-theme-name ;;
            cursor-size)  k=gtk-cursor-theme-size ;;
            *)            k="" ;;
        esac
        [ -n "$k" ] && v="$(sed -n "s/^$k=//p" "$cfgdir/gtk-3.0/settings.ini" | head -n 1)"
    fi
    printf '%s' "$v"
}
# iface_set KEY TEXT: a string value.  iface_set_num KEY NUMBER: an integer value.
iface_set() {
    if command -v dconf >/dev/null 2>&1; then
        dconf write "/org/gnome/desktop/interface/$1" "'$2'" 2>/dev/null && return 0
    fi
    command -v gsettings >/dev/null 2>&1 && gsettings set org.gnome.desktop.interface "$1" "$2" 2>/dev/null
}
iface_set_num() {
    if command -v dconf >/dev/null 2>&1; then
        dconf write "/org/gnome/desktop/interface/$1" "$2" 2>/dev/null && return 0
    fi
    command -v gsettings >/dev/null 2>&1 && gsettings set org.gnome.desktop.interface "$1" "$2" 2>/dev/null
}

# ===== which themes exist =====
roots() {
    printf '%s\n' "$datadir/icons" "$HOME/.icons"
    set -f
    old_ifs="$IFS"; IFS=:
    for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
        [ -n "$d" ] && printf '%s/icons\n' "$d"
    done
    IFS="$old_ifs"
    set +f
}

# list_themes icons|cursors: an icon theme has an index.theme with Directories= (a cursor-only
# theme usually has none); a cursor theme has an Xcursor folder or is a hyprcursor theme.
list_themes() {
    roots | while IFS= read -r r; do
        [ -d "$r" ] || continue
        for t in "$r"/*/; do
            [ -d "$t" ] || continue
            n="${t%/}"; n="${n##*/}"
            case "$n" in hicolor|locolor|default) continue ;; esac
            case "$1" in
                icons)
                    if [ -f "$t/index.theme" ] && grep -q '^Directories=' "$t/index.theme" \
                       && ! grep -qi '^Hidden=true' "$t/index.theme"; then
                        printf '%s\n' "$n"
                    fi ;;
                cursors)
                    if [ -d "$t/cursors" ] || [ -d "$t/cursors_scalable" ] || [ -f "$t/manifest.hl" ]; then
                        printf '%s\n' "$n"
                    fi ;;
            esac
        done
    done | sort -u
}

# The name ends up inside a dconf value and an ini file: letters, digits, space . _ + - only.
valid_name() { printf '%s' "$1" | grep -Eq '^[A-Za-z0-9._+ -]+$'; }

need_theme() {
    if ! valid_name "$2"; then say "not a usable theme name: $2"; exit 2; fi
    if ! list_themes "$1" | grep -Fxq -- "$2"; then say "no $1 theme called $2 is installed"; exit 2; fi
}

need_size() {
    case "$1" in
        ''|*[!0-9]*) say "not a size: $1"; exit 2 ;;
    esac
    if [ "$1" -lt 8 ] || [ "$1" -gt 256 ]; then say "size out of range (8-256): $1"; exit 2; fi
}

# ===== KDE =====
kde_present() {
    [ -f "$kdeglobals" ] || [ -f "$kcminputrc" ] \
        || command -v dolphin >/dev/null 2>&1 \
        || command -v kwriteconfig6 >/dev/null 2>&1 \
        || command -v kwriteconfig5 >/dev/null 2>&1 \
        || command -v plasma-apply-colorscheme >/dev/null 2>&1
}

# kde_emit PATH IFACE.SIGNAL INT...: a signal on the session bus.
kde_emit() {
    p="$1"; sig="$2"; shift 2
    if command -v dbus-send >/dev/null 2>&1; then
        args=""
        for a in "$@"; do args="$args int32:$a"; done
        # shellcheck disable=SC2086
        dbus-send --session --type=signal "$p" "$sig" $args >/dev/null 2>&1
    elif command -v gdbus >/dev/null 2>&1; then
        gdbus emit --session --object-path "$p" --signal "$sig" "$@" >/dev/null 2>&1
    fi
}

# ===== GTK settings.ini =====
gtk_ini() {
    for v in 3.0 4.0; do
        ini_set "$cfgdir/gtk-$v/settings.ini" Settings "$1" "$2"
    done
}

# ===== icons =====
apply_icons() {
    name="$1"

    gtk_ini gtk-icon-theme-name "$name"

    for q in 5 6; do
        f="$cfgdir/qt${q}ct/qt${q}ct.conf"
        if [ -f "$f" ] || command -v "qt${q}ct" >/dev/null 2>&1; then
            ini_set "$f" Appearance icon_theme "$name"
        fi
    done

    if kde_present; then
        ini_set "$kdeglobals" Icons Theme "$name"
    fi

    # Last, so everything GTK might read is already in place when it hears about it.
    iface_set icon-theme "$name" || say "could not set GNOME's icon-theme (neither dconf nor gsettings worked)"

    if kde_present; then
        g=0
        while [ "$g" -le 5 ]; do
            kde_emit /KIconLoader org.kde.KIconLoader.iconChanged "$g"
            g=$((g + 1))
        done
        kde_emit /KGlobalSettings org.kde.KGlobalSettings.notifyChange 4 0
    fi
}

# ===== cursor =====
live_cursor() {
    name="$1"; size="$2"

    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl setcursor "$name" "$size" >/dev/null 2>&1 \
            || say "hyprctl setcursor did not work (is Hyprland running?)"
    fi

    # Apps started from now on (by D-Bus activation or by systemd) get the new theme too.
    if command -v dbus-update-activation-environment >/dev/null 2>&1; then
        dbus-update-activation-environment --systemd \
            XCURSOR_THEME="$name" XCURSOR_SIZE="$size" \
            HYPRCURSOR_THEME="$name" HYPRCURSOR_SIZE="$size" >/dev/null 2>&1
    elif command -v systemctl >/dev/null 2>&1; then
        systemctl --user set-environment \
            XCURSOR_THEME="$name" XCURSOR_SIZE="$size" \
            HYPRCURSOR_THEME="$name" HYPRCURSOR_SIZE="$size" >/dev/null 2>&1
    fi

    # X11 programs under XWayland read the X resources when they start.
    if command -v xrdb >/dev/null 2>&1; then
        printf 'Xcursor.theme: %s\nXcursor.size: %s\n' "$name" "$size" \
            | DISPLAY="${DISPLAY:-:0}" xrdb -merge >/dev/null 2>&1
    fi
}

apply_cursor() {
    name="$1"; size="$2"

    gtk_ini gtk-cursor-theme-name "$name"
    gtk_ini gtk-cursor-theme-size "$size"

    # The fallback X11 / XWayland clients read when XCURSOR_THEME is not set.
    ini_set "$datadir/icons/default/index.theme" "Icon Theme" Inherits "$name"
    [ -f "$HOME/.icons/default/index.theme" ] \
        && ini_set "$HOME/.icons/default/index.theme" "Icon Theme" Inherits "$name"

    if kde_present; then
        ini_set "$kcminputrc" Mouse cursorTheme "$name"
        ini_set "$kcminputrc" Mouse cursorSize "$size"
    fi

    iface_set cursor-theme "$name" || say "could not set GNOME's cursor-theme (neither dconf nor gsettings worked)"
    iface_set_num cursor-size "$size"

    if kde_present; then
        kde_emit /KGlobalSettings org.kde.KGlobalSettings.notifyChange 5 0
    fi

    live_cursor "$name" "$size"
}

# ===== check =====
do_check() {
    for t in hyprctl dconf gsettings dbus-send gdbus dbus-update-activation-environment xrdb qt5ct qt6ct; do
        echo "$t: $(command -v "$t" || echo 'not found')"
    done
    echo "QT_QPA_PLATFORMTHEME in this shell: '${QT_QPA_PLATFORMTHEME:-}'"
    case "${QT_QPA_PLATFORMTHEME:-}" in
        qt5ct|qt6ct|kde|gtk3) ;;
        *) echo "  not qt5ct / qt6ct / kde / gtk3: Qt apps (and the shell's own icons) do not follow an icon theme change. Set it before the apps start, e.g. in hyprland.conf: env = QT_QPA_PLATFORMTHEME,qt6ct" ;;
    esac
    echo "icon theme now:   '$(iface_get icon-theme)'"
    echo "cursor theme now: '$(iface_get cursor-theme)' size '$(iface_get cursor-size)'"
    echo "icon themes found:   $(list_themes icons | wc -l)"
    echo "cursor themes found: $(list_themes cursors | wc -l)"
}


# ===== looking icons up ourselves (resolve) =====
TAB="$(printf '\t')"

# theme_dirs THEME: the folder of THEME in every icon root that has it.
theme_dirs() {
    roots | while IFS= read -r r; do
        [ -f "$r/$1/index.theme" ] && printf '%s/%s\n' "$r" "$1"
    done
}

# theme_chain THEME: THEME, the themes it inherits from (depth first, as the spec says), hicolor last.
theme_chain() {
    queue="$1"; seen=""; out=""; n=0
    while [ -n "$queue" ] && [ "$n" -lt 24 ]; do
        cur="${queue%%,*}"
        if [ "$queue" = "$cur" ]; then queue=""; else queue="${queue#*,}"; fi
        cur="$(printf '%s' "$cur" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -n "$cur" ] || continue
        case ",$seen," in *",$cur,"*) continue ;; esac
        seen="$seen,$cur"
        out="$out
$cur"
        n=$((n + 1))
        base="$(theme_dirs "$cur" | head -n 1)"
        if [ -n "$base" ]; then
            inh="$(sed -n 's/^Inherits=//p' "$base/index.theme" | head -n 1 | tr -d '\r')"
            [ -n "$inh" ] && queue="$inh${queue:+,}$queue"
        fi
    done
    case ",$seen," in *",hicolor,"*) ;; *) out="$out
hicolor" ;; esac
    printf '%s\n' "$out" | sed '/^$/d'
}

# theme_table ORD BASE: one line per icon folder of the theme at BASE:
#   ord  base  dir  size  min  max  type  threshold  scale
theme_table() {
    awk -v ord="$1" -v base="$2" '
        { sub(/\r$/, "") }
        /^\[/ { sec = substr($0, 2); sub(/\].*$/, "", sec); next }
        /^[ \t]*(#|;|$)/ { next }
        {
            k = $0; v = $0
            sub(/=.*/, "", k); sub(/^[^=]*=/, "", v)
            if (sec == "Icon Theme") {
                if (k == "Directories" || k == "ScaledDirectories")
                    list = list (list == "" ? "" : ",") v
            } else P[sec, k] = v
        }
        END {
            n = split(list, D, ",")
            for (i = 1; i <= n; i++) {
                d = D[i]
                if (d == "" || P[d, "Size"] == "") continue
                size = P[d, "Size"] + 0
                scale = (P[d, "Scale"] == "") ? 1 : P[d, "Scale"] + 0
                min = (P[d, "MinSize"] == "") ? size : P[d, "MinSize"] + 0
                max = (P[d, "MaxSize"] == "") ? size : P[d, "MaxSize"] + 0
                thr = (P[d, "Threshold"] == "") ? 2 : P[d, "Threshold"] + 0
                type = (P[d, "Type"] == "") ? "Threshold" : P[d, "Type"]
                printf "%s\t%s\t%s\t%d\t%d\t%d\t%s\t%d\t%d\n", ord, base, d, size, min, max, type, thr, scale
            }
        }' "$2/index.theme"
}

# do_resolve THEME SIZE NAME...: one `find` over the theme folders and one `awk` pass, so the time
# does not grow with the number of names. The first theme in the chain that has an icon wins; inside
# it the folder whose size is closest to SIZE (the spec's distance rules), svg before png before
# xpm; /usr/share/pixmaps comes last.
do_resolve() {
    theme="$1"; target="$2"; shift 2
    if ! valid_name "$theme"; then say "not a usable theme name: $theme"; exit 2; fi
    case "$target" in ''|*[!0-9]*) say "not a size: $target"; exit 2 ;; esac

    nameset=""
    for n in "$@"; do
        case "$n" in
            /*) [ -f "$n" ] && printf '%s\t%s\n' "$n" "$n"; continue ;;
            ''|*[!A-Za-z0-9._+@-]*) continue ;;
        esac
        nameset="$nameset $n"
    done
    [ -n "$nameset" ] || return 0

    table="$(mktemp)" || exit 1
    trap 'rm -f "$table"' EXIT
    i=0
    theme_chain "$theme" | while IFS= read -r t; do
        i=$((i + 1))
        theme_dirs "$t" | while IFS= read -r b; do theme_table "$i" "$b"; done
    done > "$table"
    if [ ! -s "$table" ]; then say "no icon theme called $theme found"; return 0; fi
    # Last resort: loose icons in /usr/share/pixmaps (ord 999 = after every theme).
    printf '999\t/usr/share/pixmaps\t.\t48\t48\t48\tFixed\t0\t1\n' >> "$table"

    {
        awk -F'\t' '$1 != 999 { print $2 }' "$table" | sort -u | while IFS= read -r b; do
            find -L "$b" -type f \( -name '*.svg' -o -name '*.png' -o -name '*.xpm' \) 2>/dev/null
        done
        find /usr/share/pixmaps -maxdepth 1 -type f 2>/dev/null
    } | awk -v target="$target" -v names="$nameset" -v table="$table" '
        BEGIN {
            n = split(names, NL, " ")
            for (i = 1; i <= n; i++) want[NL[i]] = 1
            nb = 0; cnt = 0
            while ((getline line < table) > 0) {
                split(line, f, "\t")
                b = f[2]; key = b SUBSEP f[3]
                if (!(b in seen)) { nb++; bases[nb] = b; seen[b] = 1 }
                if (!(key in M)) { M[key] = line; di[key] = ++cnt }
            }
        }
        {
            p = $0
            base = ""
            for (i = 1; i <= nb; i++)
                if (index(p, bases[i] "/") == 1) { base = bases[i]; break }
            if (base == "") next
            rel = substr(p, length(base) + 2)
            k = match(rel, /\/[^\/]*$/)
            if (k > 0) { d = substr(rel, 1, k - 1); fl = substr(rel, k + 1) } else { d = "."; fl = rel }
            e = match(fl, /\.[^.]*$/)
            if (e == 0) next
            nm = substr(fl, 1, e - 1); ext = substr(fl, e + 1)
            if (!(nm in want)) next
            er = (ext == "svg") ? 0 : (ext == "png") ? 1 : (ext == "xpm") ? 2 : 3
            if (er == 3) next
            key = base SUBSEP d
            if (!(key in M)) next
            split(M[key], f, "\t")
            ord = f[1] + 0; size = f[4] + 0; mn = f[5] + 0; mx = f[6] + 0
            type = f[7]; thr = f[8] + 0; scale = f[9] + 0
            if (type == "Fixed") {
                dist = size * scale - target
            } else if (type == "Scalable") {
                lo = mn * scale; hi = mx * scale
                dist = (target < lo) ? lo - target : (target > hi) ? target - hi : 0
            } else {
                lo = (size - thr) * scale; hi = (size + thr) * scale
                dist = (target < lo) ? lo - target : (target > hi) ? target - hi : 0
            }
            if (dist < 0) dist = -dist
            better = 0
            if (!(nm in bo)) better = 1
            else if (ord < bo[nm]) better = 1
            else if (ord == bo[nm]) {
                if (dist < bd[nm]) better = 1
                else if (dist == bd[nm]) {
                    if (er < be[nm]) better = 1
                    else if (er == be[nm] && di[key] < bi[nm]) better = 1
                }
            }
            if (better) { bo[nm] = ord; bd[nm] = dist; be[nm] = er; bi[nm] = di[key]; bp[nm] = p }
        }
        END { for (nm in bp) printf "%s\t%s\n", nm, bp[nm] }
    '
    return 0
}

case "$mode_cmd" in
    list)
        case "$1" in
            icons|cursors) list_themes "$1" ;;
            *) say "usage: list icons|cursors"; exit 2 ;;
        esac ;;
    get)
        echo "icons=$(iface_get icon-theme)"
        echo "cursor=$(iface_get cursor-theme)"
        echo "size=$(iface_get cursor-size)" ;;
    icons)
        need_theme icons "$1"
        apply_icons "$1" ;;
    cursor)
        need_theme cursors "$1"
        need_size "$2"
        apply_cursor "$1" "$2" ;;
    restore)
        need_theme cursors "$1"
        need_size "$2"
        live_cursor "$1" "$2" ;;
    resolve)
        [ $# -ge 2 ] || { say "usage: resolve <theme> <size> <icon name>..."; exit 2; }
        do_resolve "$@" ;;
    import)
        [ -n "$1" ] || { say "usage: import <pack> [name]"; exit 2; }
        py="$(command -v python3 || command -v python)"
        [ -n "$py" ] || { say "python3 is needed to convert Windows cursors"; exit 127; }
        here="$(cd "$(dirname "$0")" && pwd)"
        if [ -n "$2" ]; then
            exec "$py" "$here/win-cursor.py" "$1" -n "$2"
        else
            exec "$py" "$here/win-cursor.py" "$1"
        fi ;;
    check)
        do_check ;;
    *)
        say "usage: icon-cursor.sh list icons|cursors | get | icons <theme> | cursor <theme> <size> | restore <theme> <size> | resolve <theme> <size> <name>... | import <pack> [name] | check"
        exit 2 ;;
esac
exit 0
