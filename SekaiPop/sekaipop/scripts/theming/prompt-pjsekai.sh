#!/bin/sh

# The fish prompt of the shell's "Terminal prompt" colour switch (Settings -> Desktop ->
# App colours): outlined sticker plates with a hard shadow under each one, like the
# shell's own plates (thick outline, flat fill, hard offset shadow).
# app-theme.sh copies this to ~/.local/state/pjsekai/terminal/prompt.sh and the fish
# function it installs runs it before every prompt:
#
#   prompt.sh <last status> <command time in ms> <directory> <terminal columns>
#
# It prints four rows (no newline after the last one):
#
#    ▂▂▂▂▂▂▂▂▂▂ ▂▂▂▂▂▂▂▂ ▂▂▂▂▂▂▂     <- the plates' top outline
#    ▌ 󰉋 ~/x ▐ ▌  main ▐ ▌ 󰪢 3s ▐     <- the plates (folder, git branch, command time)
#    ▆▆▆▆▆▆▆▆▆▆ ▆▆▆▆▆▆▆▆ ▆▆▆▆▆▆▆     <- bottom outline, and under it the hard shadow
#     ▶                                <- where you type (red after a failure)
#
# Everything is drawn with block characters, which the terminal paints itself, so the
# outline and the shadow line up exactly in any font. Only the icons need a Nerd Font.
# The outline is the same thickness on every side (a quarter of a cell high on top, half
# a cell wide at the sides, because a cell is about twice as tall as it is wide), and the
# shadow is what is left of the bottom row.
#
# Why a script and not Starship: every plate's outline and shadow must be exactly as wide
# as the plate, and Starship cannot know the width of its own modules. Here every width
# is measured. (The command time only shows from one second up, and a failed command
# adds a red plate with its exit code first.)
#
# Colours are 256-colour INDICES, not hex. The target redefines these eight in the
# terminal (OSC 4) to the shell's theme, so nothing here is a fixed colour:
#   255 folder plate     252 git-branch plate    254 command-time plate
#   235 ink on the plates    240 outline    241 hard shadow
#   244 failed-command plate and arrow      243 the arrow
# Set PJSEKAI_PROMPT_COMPACT=1 for three rows (no top outline).

LC_ALL=C
export LC_ALL

st="${1:-0}"
ms="${2:-}"
dir="${3:-$PWD}"
cols="${4:-80}"
case "$cols" in ''|*[!0-9]*) cols=80 ;; esac

ESC=$(printf '\033')
R="${ESC}[0m"
TOP=$(printf '\342\226\202')    # U+2582 lower one quarter block    (top outline)
BOT=$(printf '\342\226\206')    # U+2586 lower three quarters block (bottom outline + shadow)
LHB=$(printf '\342\226\214')    # U+258C left half block   (left outline)
RHB=$(printf '\342\226\220')    # U+2590 right half block  (right outline)
I_TIME=$(printf '\363\260\252\242')  # U+F0AA2
I_DIR=$(printf '\363\260\211\213')   # U+F024B
I_GIT=$(printf '\363\260\230\254')   # U+F062C
I_HOME=$(printf '\357\200\225')      # U+F015
I_FAIL=$(printf '\357\200\215')      # U+F00D
I_ARROW=$(printf '\357\201\213')     # U+F04B

# width in cells: plain ASCII is counted by the shell, anything else by wc -m (UTF-8)
wlen() {
    case "$1" in
        *[!\ -~]*) n=$(printf '%s' "$1" | LC_ALL=C.UTF-8 wc -m); echo $((n + 0)) ;;
        *) echo ${#1} ;;
    esac
}

# ===== the texts =====
case "$st" in ''|*[!0-9]*) st=0 ;; esac

case "$ms" in ''|*[!0-9]*) ms=0 ;; esac
if [ "$ms" -lt 1000 ]; then
    if [ "$ms" -eq 0 ]; then t_time="0s"; else t_time="${ms}ms"; fi
elif [ "$ms" -lt 60000 ]; then
    t_time="$((ms / 1000))s"
elif [ "$ms" -lt 3600000 ]; then
    t_time="$((ms / 60000))m $((ms / 1000 % 60))s"
else
    t_time="$((ms / 3600000))h $((ms / 60000 % 60))m"
fi

# directory: the home folder is the house icon; a long path keeps its last 2 parts
dir="${dir%/}"
[ -n "$dir" ] || dir="/"
home="${HOME%/}"
if [ -n "$home" ] && [ "$dir" = "$home" ]; then
    t_dir="$I_HOME"
else
    if [ -n "$home" ] && [ "${dir#"$home"/}" != "$dir" ]; then
        rel="${dir#"$home"/}"; lead="$I_HOME/"
    else
        rel="${dir#/}"; lead="/"
    fi
    if [ -z "$rel" ]; then
        t_dir="/"
    else
        oldifs="$IFS"; IFS=/; set -f
        set -- $rel
        set +f; IFS="$oldifs"
        if [ $# -gt 2 ]; then
            shift $(($# - 2))
            t_dir="${lead}.../$1/$2"
        else
            t_dir="$lead$rel"
        fi
    fi
fi

# git branch (or the short commit when detached), only inside a repository
t_git=""
if command -v git >/dev/null 2>&1; then
    t_git=$(git symbolic-ref --short -q HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    case "$t_git" in
        *[!\ -~]*) ;;
        *) [ ${#t_git} -gt 18 ] && t_git="$(printf '%.17s' "$t_git")..." ;;
    esac
fi

# ===== the rows =====
row1=""; row2=""; row3=""; used=0

# bar <char> <count>
bar() {
    b=""; i=0
    while [ "$i" -lt "$2" ]; do b="${b}$1"; i=$((i + 1)); done
}

# plate <fill index> <text>: adds the plate to all three rows
plate() {
    w=$(wlen "$2")
    gap=""
    if [ "$used" -gt 0 ]; then gap=" "; used=$((used + 1)); fi
    n=$((w + 2))
    bar "$TOP" "$n"; topbar="$b"
    bar "$BOT" "$n"; botbar="$b"
    row1="${row1}${gap}${ESC}[0;38;5;240m${TOP}${topbar}${TOP}${R}"
    row2="${row2}${gap}${ESC}[0;38;5;240;48;5;$1m${LHB}${ESC}[38;5;235m $2 ${ESC}[38;5;240m${RHB}${R}"
    row3="${row3}${gap}${ESC}[0;38;5;241;48;5;240m${BOT}${botbar}${BOT}${R}"
    used=$((used + w + 4))
}

# which plates there is room for: a narrow terminal drops the time, then the branch,
# instead of wrapping the prompt
f_fail=0; [ "$st" -ne 0 ] && f_fail=1
f_dir=1
f_time=0; [ "$ms" -ge 1000 ] && f_time=1
f_git=0; [ -n "$t_git" ] && f_git=1
w_fail=$(wlen "$I_FAIL $st"); w_time=$(wlen "$I_TIME $t_time")
w_dir=$(wlen "$I_DIR $t_dir"); w_git=$(wlen "$I_GIT $t_git")

# total=cells the shown plates take (each is its text + 2 padding + 2 side outlines, 1 apart)
measure() {
    total=0; cnt=0
    for part in fail dir git time; do
        eval "on=\$f_$part; w=\$w_$part"
        [ "$on" = 1 ] || continue
        total=$((total + w + 4))
        [ "$cnt" -gt 0 ] && total=$((total + 1))
        cnt=$((cnt + 1))
    done
}
measure
if [ "$total" -gt "$((cols - 2))" ]; then f_time=0; measure; fi
if [ "$total" -gt "$((cols - 2))" ]; then f_git=0; measure; fi

[ "$f_fail" -eq 1 ] && plate 244 "$I_FAIL $st"
[ "$f_dir" -eq 1 ] && plate 255 "$I_DIR $t_dir"
[ "$f_git" -eq 1 ] && plate 252 "$I_GIT $t_git"
[ "$f_time" -eq 1 ] && plate 254 "$I_TIME $t_time"

if [ "$st" -ne 0 ]; then ac=244; else ac=243; fi
row4="${ESC}[1;38;5;${ac}m ${I_ARROW}${R} "

if [ "$PJSEKAI_PROMPT_COMPACT" = "1" ]; then
    printf '%s\n%s\n%s' " $row2" " $row3" "$row4"
else
    printf '%s\n%s\n%s\n%s' " $row1" " $row2" " $row3" "$row4"
fi
