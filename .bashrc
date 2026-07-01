#!/bin/bash
# Copyright (c) 2026 NIX tricks
# Released under the MIT License
# SPDX-License-Identifier: MIT


### Setup


# ------------------------------------------------------------------------------
# 💻 TTY COLOR PALETTE OVERRIDE (Only for raw Linux Console)
# ------------------------------------------------------------------------------
if [ "$TERM" = "linux" ]; then
  /bin/echo -e "
  \e]P0121110
  \e]P1ef2f27
  \e]P2519f50
  \e]P3fbb829
  \e]P42c78bf
  \e]P5e02c6d
  \e]P60aaeb3
  \e]P7c5b088
  \e]P8917e6b
  \e]P9f75341
  \e]PA98bc37
  \e]PBfed06e
  \e]PC68a8e4
  \e]PDff5c8f
  \e]PE2be4d0
  \e]PFfce8c3
  "
  clear
fi


# ------------------------------------------------------------------------------
# 🛠️ SYSTEM ALIASES & TOOLS
# ------------------------------------------------------------------------------
alias htop='ktop'
alias l='ls -CF'
alias b='bash'
alias vim='nvim'
alias ls='eza -lah --icons --git --group-directories-first --color=always'
alias la='ls -A'
alias ll='ls -l'
alias cat="bat -p"
alias pfetch="curl -s https://raw.githubusercontent.com/dylanaraps/pfetch/master/pfetch | sh"
alias rm='rm -fr'

# Grep enhancements
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Human-readable system stats
alias df='df -h'
alias du='du -h'
alias free='free -h'

# Process tracking
alias psa='ps auxf'
alias psgrep='ps aux | grep -v grep | grep -i -e VSZ -e'
alias psmem='ps auxf | sort -nr -k 4'
alias pscpu='ps auxf | sort -nr -k 3'

# Gentoo Package Management (Using doas)
alias sync='doas emaint -a sync'
alias update='doas emerge -avuDN @world'
alias upgrade='doas emerge -avuDN @world'
alias newuse='doas emerge -avuDN @world'
alias clean='doas emerge --depclean'
alias distclean='doas emerge -aC'
alias eclean-dist='doas eclean-dist'
alias revdep='doas revdep-rebuild'
alias etc-update='doas etc-update'
alias conf-update='doas dispatch-conf'

# Package search utilities
alias qlist='qlist -IC'
alias qfile='qfile'
alias equery='equery'

# Logs and Diagnostics
alias syslog='doas tail -f /var/log/messages'
alias journal='doas journalctl -xe'
alias kern-log='doas dmesg -T -w'

# Security & Hardening checks
alias checksec='scanelf -pvf'
alias hardened-check='hardened-check'

# Networking utilities
alias ip='ip -color'
alias myip='curl -s ifconfig.me'

# Fast Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

###
config() {
    # Define prompt segments
    declare -ag segments=(identity timestamp path git prompt)
    declare -ag dynamics=(identity git)

    # Define active features
    declare -g use_colors=true
    declare -g use_glyphs=true
    declare -g use_badges=true

    # Define custom colors
    declare -g color_primary="#f5992e"
    declare -g color_secondary="#785cea"
    declare -g color_neutral="#5f5f87"
    declare -g color_global

    declare -g glyph_badge_left=""
    declare -g glyph_badge_right=""

    # Define main color
    if is_root; then
        color_global=$color_secondary
    else
        color_global=$color_primary
    fi

    # Prevent NF glyphs on console sessions
    if is_console; then use_glyphs=false; fi

    # Define prompt variables
    PS1=""
    PS2="→ "
    PROMPT_DIRTRIM=2
    export GIT_PS1_SHOWUNTRACKEDFILES=1
    export GIT_PS1_SHOWDIRTYSTATE=1

    # Preserve prompt command (i.e. not to break VTE)
    if [[ $PROMPT_COMMAND != *__print_blank* ]]; then
        PROMPT_COMMAND="${PROMPT_COMMAND%;}"
        PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }__print_blank"
    fi
}

init() {
    for segment in "${segments[@]}"; do
        local renderer="render_$segment"

        # Skip segments without renderers
        if ! declare -F "$renderer" > /dev/null; then continue; fi

        if [[ "${dynamics[*]}" =~ $segment ]]; then
            # Evaluate every time
            PS1+="\$($renderer) "
        else
            # Evaluate only once
            PS1+="$($renderer) "
        fi
    done
}


### Renderers

render_identity() {
    local cmd_status=$?
    local glyph
    local label

    # Define glyph
    if is_error "$cmd_status"; then
        if $use_glyphs; then glyph=""; else glyph="!"; fi
        # Add blinking effect to error state glyph
        glyph="\001\033[5m\002$glyph\001\033[25m\002"
    elif is_ssh; then
        if $use_glyphs; then glyph="󰌘"; else glyph="*"; fi
    elif is_root; then
        if $use_glyphs; then glyph=""; else glyph="#"; fi
    else
        if $use_glyphs; then glyph=""; else glyph="$"; fi
    fi

    # Define label
    if is_ssh || is_su; then
        label="$USER@$HOSTNAME"
    elif is_git; then
        label=$(get_git_project)
    else
        label="${HOSTNAME%%.*}"
    fi

    # Rendering logic
    if $use_badges; then
        make_badge "$glyph $label"
    else
        make_label "$glyph $label"
    fi
}

render_timestamp() {
    local label="\T"

    # Rendering logic
    if $use_badges; then
        make_label "$label"
    else
        make_label "[$label]" "$color_neutral"
    fi
}

render_path() {
    local glyph=""
    local label="\w"

    # Rendering logic
    if $use_glyphs; then
        printf "%s %s" "$(make_label "$glyph")" "$label"
    else
        printf "%s" "$label"
    fi
}

render_git() {
    local glyph=""
    local label="%s"
    local format

    # Prevent if not a repository
    if ! is_git; then return 1; fi

    # Use brackets instead of badges
    if ! $use_badges; then
        label="($label)"
    fi

    # Prepend glyph to label
    if $use_glyphs; then
        label="$glyph $label"
    fi

    # Build format string
    if $use_badges; then
        format="$(make_badge "$label" "$color_neutral")"
    elif $use_colors; then
        format="$(make_label "$label" "$color_secondary")"
    else
        format="$label"
    fi

    # Safe git prompt
    if command -v __git_ps1 > /dev/null 2>&1; then
        __git_ps1 "$format"
    fi
}

render_prompt() {
    local glyph

    # Define glyph
    if $use_glyphs && $use_badges; then glyph="󱞩"; else glyph="→"; fi

    # Prepend space character to match badge
    if $use_badges; then glyph=" $glyph"; fi

    # Use bold glyph
    if $use_glyphs && $use_badges; then
        glyph="\001\033[1m\002$glyph\001\033[0m\002"
    fi

    # Prepend newline character
    printf "\n%s" "$(make_label "$glyph")"
}


### Helpers

hex_to_ansi() {
    local hex=${1#\#}
    local include_bg=${2:-false}

    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))

    if $include_bg; then
        printf "30;48;2;%s;%s;%s" "$r" "$g" "$b"
    else
        printf "2;%s;%s;%s" "$r" "$g" "$b"
    fi
}

make_label() {
    local content=$1
    local color=${2:-$color_global}

    # Prevent empty content
    if [[ -z $content ]]; then return 1; fi

    if $use_colors; then
        printf "\001\033[38;%sm\002" "$(hex_to_ansi "$color")"
    fi

    printf "%b" "$content"

    if $use_colors; then
        printf "\001\033[0m\002"
    fi
}

make_badge() {
    local content=$1
    local color=${2:-$color_global}
    local glyph_left
    local glyph_right
    local ansi_sequence

    # Prevent empty content
    if [[ -z $content ]]; then return 1; fi

    if $use_glyphs; then
        # Use NF rounded corners
        glyph_left=$glyph_badge_left
        glyph_right=$glyph_badge_right
    else
        # Use plain padding
        content=" $content "
    fi

    if $use_colors; then
        ansi_sequence=$(hex_to_ansi "$color" true)
    else
        # Reverse video
        ansi_sequence=7
    fi

    printf "%s" "$(make_label "$glyph_left" "$color")"
    printf "\001\033[%sm\002" "$ansi_sequence"
    printf "%b" "$content"
    printf "\001\033[0m\002"
    printf "%s" "$(make_label "$glyph_right" "$color")"
}


### Predicates

is_root() { [[ $EUID -eq 0 ]]; }

is_su() { [[ -n $LOGNAME && $USER != "$LOGNAME" ]]; }

is_ssh() { [[ -n "$SSH_CLIENT" ]]; }

is_console() { [[ -t 1 && $TERM == linux ]]; }

is_error() { [[ $1 -ne 0 && $1 -ne 130 ]]; }

is_git() { [[ -n $(get_git_project) ]]; }

# Get top-level repository name
get_git_project() {
    # Skip execution if `git` is not available
    if ! command -v git > /dev/null 2>&1; then return 1; fi

    local git_root
    if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
        # Return the directory basename
        printf "%s" "${git_root##*/}"
    fi
}


### Hooks

# Prepend blank line except after startup or clear
__print_blank() { [[ -n $__was_printed ]] && echo; __was_printed=1; }

# The clear command should also reset the flag
alias clear="command clear; unset __was_printed"


### Initialize

config && init

# ------------------------------------------------------------------------------
# 🌐 HARDWARE ENVIRONMENT INTEGRATION HOOKS
# ------------------------------------------------------------------------------
export PATH="/home/nana/.local/bin:$PATH"
export GPG_TTY=$(tty)

# eval "$(starship init bash)" # Commented out to prevent conflict with custom prompt

# Custom greeting function
greet() {
    bash ~/.config/torii-greeting.sh
}

# Run it automatically on login
greet
