# Shared helpers (sourced by install.sh)

step() { printf '\n\033[1m[%s]\033[0m %s\n' "$1" "$2"; }
say()  { printf '    %s\n' "$*"; }

# yes/no question; default yes. With --yes it always answers yes.
confirm() { # confirm "question"
    [ -n "$yes" ] && return 0
    printf '    %s [Y/n] ' "$1"
    read -r r </dev/tty || r=y
    case "$r" in n|N) return 1 ;; esac
    return 0
}

# copy a program name -> true if it is installed (awww can be swww, magick can be convert)
have() {
    case "$1" in
        awww) command -v awww >/dev/null 2>&1 || command -v swww >/dev/null 2>&1 ;;
        magick) command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1 ;;
        *) command -v "$1" >/dev/null 2>&1 ;;
    esac
}

backup() { [ -e "$1" ] || return 0; mkdir -p "$bk/$(dirname "${1#$cfg/}")"; cp -a "$1" "$bk/${1#$cfg/}"; }

ask() { # ask before replacing a file that exists
    [ -n "$yes" ] && return 0
    [ -e "$1" ] || return 0
    printf '%s exists and will be replaced (backup saved). Continue? [Y/n] ' "$1"
    read -r r </dev/tty || return 0
    case "$r" in n|N) return 1 ;; esac
}

put() { # put SRC DST  (backup, then copy)
    if ask "$2"; then backup "$2"; cp "$1" "$2"; else echo "skipped $2"; fi
}

# ── block of lines owned by the installer inside a file of the user ──
# The block is delimited by two marker lines; running the installer again replaces it,
# --uninstall removes it.
mark_begin="quickshell-dots >>>"
mark_end="quickshell-dots <<<"

remove_block() { # remove_block FILE
    [ -f "$1" ] || return 0
    grep -q "$mark_begin" "$1" 2>/dev/null || return 0
    awk -v b="$mark_begin" -v e="$mark_end" '
        index($0, b) { skip = 1; next }
        index($0, e) { skip = 0; next }
        !skip { print }
    ' "$1" > "$1.qsd.tmp" && mv "$1.qsd.tmp" "$1"
}

add_block() { # add_block FILE COMMENT_PREFIX CONTENT_FILE
    backup "$1"
    remove_block "$1"
    {
        printf '\n%s %s (added by quickshell-dots; delete the lines down to the closing marker to uninstall)\n' "$2" "$mark_begin"
        cat "$3"
        printf '%s %s\n' "$2" "$mark_end"
    } >> "$1"
}
