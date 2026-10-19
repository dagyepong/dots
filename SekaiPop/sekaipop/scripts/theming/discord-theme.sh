#!/bin/sh

# Helper for ThemeService.qml: writes the sekaipop Vencord/Vesktop theme with
# the shell's CURRENT palette baked in, so Discord follows whichever group
# theme (or the matugen wallpaper theme) is active.
#
#   discord-theme.sh write [role=#hex ...]   generate + install (what the shell calls)
#   discord-theme.sh print [role=#hex ...]   print the CSS to stdout, install nothing
#   discord-theme.sh where                   list the folders it would install into
#
# mode=light|dark|auto picks the Discord look (default auto; SEKAIPOP_DISCORD_MODE also works).
# Roles: border A B deep hoverTint divider boardBg boardDot rimHi
#
# Layout options (same key=value form; validated, bad values are ignored):
#   look=material|simple|scrapbook
#                             (default material: CapnKitten's Material Discord + its Material
#                              You addon, coloured by matugen. It ignores the layout options
#                              below and follows Discord's own light/dark setting.
#                              simple = outline + rounded only; scrapbook = washi
#                              labels, ring, hard shadows. Those two change the defaults of
#                              labels (off/on) and gap (8px/12px) unless you set them.)
#   layout=floating|classic   labels=on|off   chatbar=separated|joined
#   userpanel=small|full      topbar=merge|default   anim=on|off   (default off: the hover
#                              slide animates margin, which forces a layout on every hover)
#   loader=sekai|off          spotify=on|off         gap=0px..99px
#   (loader defaults to off: its :has() selectors cost time on every DOM change)
# layout=floating @imports system24 (github.com/refact0r/system24) for the geometry
# and dresses it in the sekaipop look; layout=classic imports nothing.
# Set them once in ${XDG_CONFIG_HOME:-~/.config}/sekaipop/discord-options (one key=value
# per line, # comments ok), or in SEKAIPOP_DISCORD_OPTS="labels=off gap=16px", or as
# arguments. Later wins: file < env < arguments.
# (same names as ThemeService.qml's palette). Missing/invalid roles fall back to
# Virtual Singer, so `write` with no arguments produces the default look.
#
# The material look has two colour sources (option source=theme|matugen):
#   theme    the shell's active theme (Virtual Singer, Leo/need, ...): the Discord
#            surfaces are built from the theme's `deep` colour and the accent from `A`
#   matugen  matugen's output, ${XDG_CACHE_HOME:-~/.cache}/sekaipop/matugen/colors.json
#            (or SEKAIPOP_MATUGEN_COLORS), written by matugen-state.sh from
#            matugen-template.json. Without that file: a warm brown palette.
# If you don't say, it is `theme` when colour roles are passed (what the shell does
# for the group themes) and `matugen` otherwise (so your own matugen post-hook can
# just run `sh discord-theme.sh write`).
#
# Installs sekaipop.theme.css into every themes folder that exists:
#   ~/.config/Vencord/themes   ~/.config/vesktop/themes   ~/.config/Equicord/themes
# or exactly the folders in SEKAIPOP_DISCORD_DIRS (colon-separated). A copy is
# always kept at ${XDG_CACHE_HOME:-~/.cache}/sekaipop/discord/sekaipop.theme.css.
# The file is only rewritten when its content changed, and replaced atomically,
# so Vencord never reads a half-written theme.

mode="$1"; [ $# -gt 0 ] && shift
here="$(cd "$(dirname "$0")" && pwd)"
body="$here/discord-theme.body.css"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/sekaipop/discord"
mcolors="${SEKAIPOP_MATUGEN_COLORS:-${XDG_CACHE_HOME:-$HOME/.cache}/sekaipop/matugen/colors.json}"

# auto (default: follow Discord's own light/dark setting) | dark | light
mode_sel="${SEKAIPOP_DISCORD_MODE:-auto}"
case "$mode_sel" in light|dark|auto) ;; *) mode_sel=light ;; esac

# Virtual Singer defaults
border="#555473"; A="#04feee"; B="#00ffcb"; deep="#232235"; hoverTint="#d9fff6"
divider="#e4e4ec"; boardBg="#f3fbf9"; boardDot="#cfe6e1"; rimHi="#9796b8"

# layout options (see the header); defaults reproduce the floating-card look
o_look=material; o_layout=floating; o_labels=""; o_chatbar=separated; o_userpanel=small
o_topbar=merge; o_anim=off; o_loader=off; o_spotify=on; o_gap=""
o_source=""; have_roles=0

# setopt KEY VALUE: returns 0 if KEY is a layout option (applying VALUE only when
# valid), 1 if KEY isn't one, so callers can fall through to the colour roles.
setopt() {
    case "$1" in
        look)      case "$2" in material|simple|scrapbook)  o_look="$2" ;; esac ;;
        layout)    case "$2" in floating|classic)  o_layout="$2" ;; esac ;;
        labels)    case "$2" in on|off)            o_labels="$2" ;; esac ;;
        chatbar)   case "$2" in separated|joined)  o_chatbar="$2" ;; esac ;;
        userpanel) case "$2" in small|full)        o_userpanel="$2" ;; esac ;;
        topbar)    case "$2" in merge|default)     o_topbar="$2" ;; esac ;;
        anim)      case "$2" in on|off)            o_anim="$2" ;; esac ;;
        loader)    case "$2" in sekai|off)         o_loader="$2" ;; esac ;;
        spotify)   case "$2" in on|off)            o_spotify="$2" ;; esac ;;
        gap)       case "$2" in [0-9]px|[0-9][0-9]px) o_gap="$2" ;; esac ;;
        *) return 1 ;;
    esac
    return 0
}

# 1) options file, 2) SEKAIPOP_DISCORD_OPTS, 3) arguments (below)
optfile="${SEKAIPOP_DISCORD_OPTIONS:-$cfg/sekaipop/discord-options}"
if [ -r "$optfile" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        case "$line" in *=*) ;; *) continue ;; esac
        k="$(printf '%s' "${line%%=*}" | tr -d ' \t')"; v="$(printf '%s' "${line#*=}" | tr -d ' \t\r')"
        setopt "$k" "$v"
    done < "$optfile"
fi
for kv in $SEKAIPOP_DISCORD_OPTS; do setopt "${kv%%=*}" "${kv#*=}"; done

for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    if [ "$k" = "mode" ]; then
        case "$v" in light|dark|auto) mode_sel="$v" ;; esac
        continue
    fi
    if [ "$k" = "source" ]; then
        case "$v" in theme|matugen) o_source="$v" ;; esac
        continue
    fi
    setopt "$k" "$v" && continue
    printf '%s' "$v" | grep -Eq '^#[0-9a-fA-F]{6}$' || continue
    case "$k" in
        border|A|B|deep|hoverTint|divider|boardBg|boardDot|rimHi) eval "$k=\"\$v\""; have_roles=1 ;;
    esac
done

# look-dependent defaults (only where the person didn't choose)
if [ "$o_look" = scrapbook ]; then
    body="$here/discord-theme.body.scrapbook.css"; border_w=3px
    [ -n "$o_labels" ] || o_labels=on
    [ -n "$o_gap" ] || o_gap=12px
else
    border_w=2px
    [ -n "$o_labels" ] || o_labels=off
    [ -n "$o_gap" ] || o_gap=8px
fi

# the merged top bar only exists in the floating layout
[ "$o_layout" = floating ] || o_topbar=default
if [ "$o_topbar" = merge ]; then topbar_pos=titlebar; topbar_h="$o_gap"; else topbar_pos=off; topbar_h=32px; fi
[ "$o_userpanel" = small ] && s24_small=on || s24_small=off
[ "$o_chatbar" = separated ] && s24_chat=separated || s24_chat=off
import_line=""
[ "$o_layout" = floating ] && import_line="@import url('https://refact0r.github.io/system24/build/system24.css');"

dirs() {
    if [ -n "$SEKAIPOP_DISCORD_DIRS" ]; then
        printf '%s\n' "$SEKAIPOP_DISCORD_DIRS" | tr ':' '\n'
        return
    fi
    for app in Vencord vesktop Equicord; do
        [ -d "$cfg/$app" ] && printf '%s\n' "$cfg/$app/themes"
    done
}

# ===== material look =====
mget() {
    [ -r "$mcolors" ] || return 1
    tr '{},' '\n\n\n' < "$mcolors" | awk -v m="$1" -v k="$2" '
        /"dark"[ \t]*:/  { sec = "dark" }
        /"light"[ \t]*:/ { sec = "light" }
        sec == m && index($0, "\"" k "\"") {
            if (match($0, /#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]/)) {
                print substr($0, RSTART, RLENGTH); exit
            }
        }'
}

# pick MODE KEY FALLBACK: the matugen colour, or FALLBACK if there isn't one
pick() {
    v="$(mget "$1" "$2")"
    if [ -n "$v" ]; then printf '%s' "$v"; else printf '%s' "$3"; fi
}

# hex_hsl #rrggbb -> "H S L" (degrees, percent, percent)
hex_hsl() {
    printf '%s\n' "$1" | awk '
        function hx(s,   i, v) { v = 0; s = tolower(s); for (i = 1; i <= length(s); i++) v = v * 16 + index("0123456789abcdef", substr(s, i, 1)) - 1; return v }
        function abs(x) { return x < 0 ? -x : x }
        {
            r = hx(substr($0, 2, 2)) / 255; g = hx(substr($0, 4, 2)) / 255; b = hx(substr($0, 6, 2)) / 255
            mx = r; if (g > mx) mx = g; if (b > mx) mx = b
            mn = r; if (g < mn) mn = g; if (b < mn) mn = b
            l = (mx + mn) / 2; d = mx - mn
            if (d == 0) { h = 0; s = 0 }
            else {
                s = d / (1 - abs(2 * l - 1))
                if (mx == r) h = (g - b) / d + (g < b ? 6 : 0)
                else if (mx == g) h = (b - r) / d + 2
                else h = (r - g) / d + 4
                h *= 60
            }
            h = int(h + 0.5); if (h >= 360) h -= 360
            printf "%d %d %d\n", h, int(s * 100 + 0.5), int(l * 100 + 0.5)
        }'
}

# hsl_hex H S L -> "#rrggbb" (H degrees, S and L percent)
hsl_hex() {
    awk -v h="$1" -v s="$2" -v l="$3" 'BEGIN {
        s /= 100; l /= 100
        a = s * (l < 1 - l ? l : 1 - l)
        out = "#"
        for (i = 0; i < 3; i++) {
            n = (i == 0 ? 0 : (i == 1 ? 8 : 4))
            k = (n + h / 30) % 12
            t = k - 3; u = 9 - k
            m = (t < u ? t : u); if (m > 1) m = 1; if (m < -1) m = -1
            v = int((l - a * m) * 255 + 0.5)
            out = out sprintf("%02x", v)
        }
        print out
    }'
}

# clamp VALUE MIN MAX
clamp() { awk -v v="$1" -v a="$2" -v b="$3" 'BEGIN { v += 0; if (v < a) v = a; if (v > b) v = b; printf "%d\n", v + 0.5 }'; }

generate_material() {
    src="$o_source"
    [ -n "$src" ] || { [ "$have_roles" = 1 ] && src=theme || src=matugen; }
    if [ "$src" = theme ]; then
        # Build the Material surfaces from the shell theme: the surface hue and a
        # gentle amount of colour come from `deep`, the accent hue from `A`.
        # Lightness steps follow Material 3's tones (dark: 5/7/12/16/26, light: 98/100/94/91/80).
        m_used="the active shell theme"
        set -- $(hex_hsl "$deep"); dh="$1"; ds="$2"
        ds_dark="$(clamp "$(awk -v v="$ds" 'BEGIN { print v * 0.35 }')" 6 18)"
        dh_dark="$(clamp "$(awk -v v="$ds" 'BEGIN { print v * 0.6 }')" 12 35)"
        ds_light="$(clamp "$ds" 30 70)"
        # A grey palette (Monochrome) has no hue: don't add the minimum tint the clamps give.
        if [ "$ds" -eq 0 ]; then ds_dark=0; dh_dark=0; ds_light=0; fi
        d_bg="$(hsl_hex "$dh" "$ds_dark" 7)"
        d_low="$(hsl_hex "$dh" "$ds_dark" 5)"
        d_high="$(hsl_hex "$dh" "$ds_dark" 16)"
        d_fg="$(hsl_hex "$dh" "$ds_dark" 12)"
        d_hover="$(hsl_hex "$dh" "$dh_dark" 26)"
        l_bg="$(hsl_hex "$dh" "$([ "$ds" -eq 0 ] && echo 0 || echo 100)" 98)"
        l_low="$(hsl_hex "$dh" "$([ "$ds" -eq 0 ] && echo 0 || echo 100)" 100)"
        l_high="$(hsl_hex "$dh" "$ds_light" 91)"
        l_fg="$(hsl_hex "$dh" "$ds_light" 94)"
        l_hover="$(hsl_hex "$dh" "$ds_light" 80)"
        prim="$A"
    else
        # (pick runs in a subshell, so note here whether matugen gave us anything)
        if [ -n "$(mget dark surface)" ]; then m_used="matugen"; else m_used="default palette (no matugen colors.json yet)"; fi
        # dark: surface -> background, surface_container_lowest -> background-low,
        # surface_container_high -> background-high, surface_container -> foreground,
        # outline_variant -> hover.   (fallbacks: a warm brown palette)
        d_bg="$(pick dark surface '#161311')"
        d_low="$(pick dark surface_container_lowest '#100e0c')"
        d_high="$(pick dark surface_container_high '#2d2927')"
        d_fg="$(pick dark surface_container '#221f1d')"
        d_hover="$(pick dark outline_variant '#564334')"
        l_bg="$(pick light surface '#fff8f5')"
        l_low="$(pick light surface_container_lowest '#ffffff')"
        l_high="$(pick light surface_container_high '#f2e5dc')"
        l_fg="$(pick light surface_container '#f8ebe2')"
        l_hover="$(pick light outline_variant '#ddc1ae')"
        prim="$(mget dark primary)"
    fi
    if [ -n "$prim" ]; then
        set -- $(hex_hsl "$prim")
        a_hue="$1"; a_sat="$2"
        [ "$a_sat" -gt 71 ] && a_sat=71
    else
        a_hue=24; a_sat=71
    fi
    a_light=61

    cat << MAT
/**
 * @name sekaipop (Material Discord)
 * @version 3.0.5-sekaipop
 * @description Material Discord by CapnKitten (github.com/CapnKitten/BetterDiscord) with its Material You addon, coloured by matugen from your wallpaper through the sekaipop Quickshell theme. All credit for the theme goes to CapnKitten.
 * @author CapnKitten (original theme), sekaipop (matugen colours)
 *
 * @website http://github.com/CapnKitten
 * @source https://github.com/CapnKitten/BetterDiscord/blob/master/Themes/Material-Discord/css/source.css
 * @donate https://paypal.me/capnkitten
 * @invite jzJkA6Z
 */

@import url(https://capnkitten.github.io/BetterDiscord/Themes/Material-Discord/css/source.css);

/* Material You addon */
@import url(https://capnkitten.github.io/BetterDiscord/Themes/Material-Discord/css/addons/material-you/source.css);

/* ---- generated by sekaipop/scripts/theming/discord-theme.sh colours: $m_used. Do not edit,
        it is rewritten whenever the wallpaper / palette changes ---- */

/* MATERIAL YOU DARK THEME SETTINGS */
.theme-dark {
	--saturation-modifier: 0.31;
	--lightness-modifier: 0.225;
	--text-lightness-modifier: 1.0;
	--ui-darkness-modifier: 1.0;
	--matugen-background: $d_bg;
	--matugen-background-low: $d_low;
	--matugen-background-high: $d_high;
	--matugen-foreground: $d_fg;
	--matugen-hover: $d_hover;
	--app-bg: var(--matugen-background);
	--main-color: var(--matugen-background);
	--main-alt: var(--matugen-background-low);
	--status-picker-color: var(--matugen-background-high);
	--message-color: var(--matugen-foreground);
	--message-color-hover: var(--matugen-hover);
	--message-color-alt: var(--matugen-background);
	--attachment-color: var(--matugen-background-high);
	--main-textarea-color: var(--matugen-background-high);
	--separator-color: var(--matugen-hover);
	--card-color-filled: var(--matugen-foreground);
	--card-color-hover: var(--matugen-hover);
	--card-color-active: var(--matugen-hover);
	--card-color-alt: var(--matugen-foreground);
	--card-border-color: var(--matugen-hover);
	--input-color: var(--matugen-foreground);
	--input-color-alt: var(--matugen-foreground);

	._740174f3d6a2c8fe-textArea {
		background-color: var(--matugen-foreground) !important;
	}
}

/* MATERIAL YOU LIGHT THEME SETTINGS */
.theme-light {
	--saturation-modifier: 0.74;
	--lightness-modifier: 2.225;
	--text-lightness-modifier: 1.0;
	--matugen-background: $l_bg;
	--matugen-background-low: $l_low;
	--matugen-background-high: $l_high;
	--matugen-foreground: $l_fg;
	--matugen-hover: $l_hover;
	--app-bg: var(--matugen-background);
	--main-color: var(--matugen-background);
	--main-alt: var(--matugen-background-low);
	--status-picker-color: var(--matugen-background-high);
	--message-color: var(--matugen-foreground);
	--message-color-hover: var(--matugen-hover);
	--message-color-alt: var(--matugen-background);
	--attachment-color: var(--matugen-background-high);
	--main-textarea-color: var(--matugen-background-high);
	--separator-color: var(--matugen-hover);
	--card-color-filled: var(--matugen-foreground);
	--card-color-hover: var(--matugen-hover);
	--card-color-active: var(--matugen-hover);
	--card-color-alt: var(--matugen-foreground);
	--card-border-color: var(--matugen-hover);
	--input-color: var(--matugen-foreground);
	--input-color-alt: var(--matugen-foreground);

	._740174f3d6a2c8fe-textArea {
		background-color: var(--matugen-foreground) !important;
	}
}

:root {
	/* ACCENT HSL AND TEXT COLOR SETTINGS (hue/saturation follow the theme's accent / matugen's primary) */
	--accent-hue: $a_hue;
	--accent-saturation: ${a_sat}%;
	--accent-lightness: ${a_light}%;
	--accent-text-color: hsl(0,0%,100%); /* DOES NOTHING WITH MATERIAL YOU ENABLED */
	--accent-button-action: hsl(0,0%,100%);

	/* ALERT HSL AND TEXT COLOR SETTINGS */
	--alert-hue: 0;
	--alert-saturation: 85%;
	--alert-lightness: 61%;
	--alert-text-color: hsl(0,0%,100%); /* DOES NOTHING WITH MATERIAL YOU ENABLED */

	/* WARNING HSL AND TEXT COLOR SETTINGS*/
	--warning-hue: 40;
	--warning-saturation: 86.4%;
	--warning-lightness: 56.9%;
	--warning-text-color: hsl(0,0%,100%); /* DOES NOTHING WITH MATERIAL YOU ENABLED */

	/* MESSAGE SETTINGS */
	--message-radius: 18px;
	--message-padding-top: 8px;
	--message-padding-side: 12px;

	/* MESSAGE MEDIA SETTINGS */
	--media-radius: 10px;

	/* CARD SETTINGS */
	--card-radius: 8px;
	--card-radius-big: 18px;

	/* BUTTON SETTINGS */
	--button-height: 36px;
	--button-padding: 0 24px;
	--button-action-color: hsl(0,0%,100%);

	/* INPUT SETTINGS */
	--input-height: 36px;
	--input-padding: 0 12px;

	/* POPOUT AND MODAL SETTINGS */
	--popout-radius: 8px;
	--popout-radius-big: 18px;

	/* TOOLTIP SETTINGS */
	--tooltip-color: hsl(0,0%,38%,0.9);
	--tooltip-text-color: hsl(0,0%,87%);
	--tooltip-font-size: 12px;
	--tooltip-padding: 8px;
	--tooltip-radius: 8px;

	/* SCROLLBAR SETTINGS */
	--scrollbar-width: 10px;
	--scrollbar-thin-width: 6px;
}
MAT
}

generate() {
    [ "$o_look" = material ] && { generate_material; return; }
    [ -f "$body" ] || { echo "discord-theme: missing $body" >&2; return 1; }
    cat << HEAD
/**
 * @name sekaipop
 * @description Project Sekai look for Discord: floating rounded cards with one clean outline and accent-gradient highlights (look=scrapbook adds washi labels and hard shadows). Colours follow the sekaipop Quickshell theme. Layout by system24 (imported), look by sekaipop.
 * @author generated by sekaipop/scripts/theming/discord-theme.sh
 * @version 2.0.0
 */

$import_line

/* ---- generated from the shell's active palette: do not edit, it is rewritten on every theme change ---- */
:root {
    --pj-border: $border;
    --pj-a: $A;
    --pj-b: $B;
    --pj-deep: $deep;
    --pj-hover-tint: $hoverTint;
    --pj-divider: $divider;
    --pj-board-bg: $boardBg;
    --pj-board-dot: $boardDot;
    --pj-rim-hi: $rimHi;
}
body {
    /* sekaipop options */
    --pj-look: $o_look;
    --pj-layout: $o_layout;
    --pj-chatbar: $o_chatbar;
    --pj-loader: $o_loader;
    --pj-spotify: $o_spotify;
    /* system24's own options (only read when the layout is imported) */
    --gap: $o_gap;
    --border-thickness: $border_w;
    --unrounding: off;
    --animations: $o_anim;
    --top-bar-height: $topbar_h;
    --top-bar-button-position: $topbar_pos;
    --top-bar-title-position: off;
    --custom-window-controls: off;
    --small-user-panel: $s24_small;
    --panel-labels: $o_labels;
    --custom-spotify-bar: off;
    --ascii-titles: off;
    --ascii-loader: off;
    --custom-chatbar: $s24_chat !important;
    --chatbar-height: 56px !important;
}
/* ---- end generated ---- */

HEAD
    # keep only the /*@mode X*/ ... /*@end*/ block for the chosen mode
    awk -v m="$mode_sel" '
        /^\/\*@mode / { skip = ($2 != m "*/" && $2 != m); inblk = 1; next }
        /^\/\*@end\*\// { inblk = 0; skip = 0; next }
        !(inblk && skip) { print }
    ' "$body"
    [ "$o_loader" = sekai ] && [ -f "$here/discord-theme.loader.css" ] && { echo; cat "$here/discord-theme.loader.css"; }
    [ -f "$here/discord-theme.perf.css" ] && { echo; cat "$here/discord-theme.perf.css"; }
}

case "$mode" in
    print)
        generate
        ;;
    where)
        dirs
        echo "$cache"
        ;;
    write)
        css="$(generate)" || exit 1
        mkdir -p "$cache" || exit 1
        installed=0
        for d in "$cache" $(dirs); do
            mkdir -p "$d" 2>/dev/null || continue
            f="$d/sekaipop.theme.css"
            if [ -f "$f" ] && [ "$(cat "$f")" = "$css" ]; then
                [ "$d" != "$cache" ] && installed=$((installed + 1))
                continue
            fi
            tmp="$d/.sekaipop.theme.tmp"
            printf '%s\n' "$css" > "$tmp" && mv -f "$tmp" "$f" || continue
            [ "$d" != "$cache" ] && installed=$((installed + 1))
        done
        [ "$installed" -gt 0 ] || echo "no Vencord/Vesktop themes folder found; copy $cache/sekaipop.theme.css into yours (or set SEKAIPOP_DISCORD_DIRS)" >&2
        ;;
    *)
        echo "usage: $0 write|print [role=#hex ...] | where" >&2
        exit 2
        ;;
esac
