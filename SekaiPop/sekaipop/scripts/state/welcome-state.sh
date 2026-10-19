#!/bin/sh

# Helper for WelcomeService.qml: remembers whether the welcome screen has been
# seen, so it only comes up by itself on the first start.
#
#   welcome-state.sh check    print SHOW (and count this try) or SKIP
#   welcome-state.sh done     remember that it was seen (finished or skipped)
#   welcome-state.sh reset    forget it, so the next start shows it again
#   welcome-state.sh status   print what is remembered: "done", a try count, or "none"
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/welcome - state, not data,
# same convention settings-state.sh / clock-state.sh use. The file holds the word
# "done" or a number of tries.
#
# Why a try count and not just a flag written before showing (what Serpantinum's
# first_launch.sh does): the flag is only set once the screen was really seen (or
# skipped), so a shell restart in the middle of it shows it again. The count is
# the safety net for that: after 3 tries without finishing, "check" says SKIP, so
# a screen that crashes the shell can never trap you in a start-up loop. Replay
# it any time with `qs -c sekaipop ipc call welcome show`.

mode="$1"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/welcome"
max_tries=3

write() {
    mkdir -p "$dir" || exit 1
    printf '%s\n' "$1" > "$file.tmp" || exit 1
    mv "$file.tmp" "$file"
}

read_state() {
    [ -f "$file" ] && head -n 1 "$file" | tr -d '[:space:]'
}

case "$mode" in
    check)
        state="$(read_state)"
        if [ "$state" = "done" ]; then
            echo SKIP
            exit 0
        fi
        case "$state" in
            ''|*[!0-9]*) tries=0 ;;
            *) tries="$state" ;;
        esac
        if [ "$tries" -ge "$max_tries" ]; then
            echo SKIP
            exit 0
        fi
        write "$((tries + 1))"
        echo SHOW
        ;;
    done)
        write done
        ;;
    reset)
        rm -f "$file" "$file.tmp"
        ;;
    status)
        state="$(read_state)"
        echo "${state:-none}"
        ;;
    *)
        echo "usage: $0 check|done|reset|status" >&2
        exit 2
        ;;
esac
