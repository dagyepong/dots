#!/bin/bash
# ==============================================================================
# 🌀 DE-FRAMED & POLISHED BASHRC CONFIGURATION
# Theme: Modern Aesthetic Demogorgon (Stranger Things / Pastel Dark)
# Optimized for: Gentoo Linux, Hyprland, and Noto-Emoji / Nerd Fonts
# ==============================================================================

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

# Easter-Egg Demogorgon Themes
alias demo-status='echo "The Demogorgon is watching..."'
alias upside-down='echo "Welcome to the Upside Down"'
alias vecna-cursed='echo "You have been cursed by Vecna!"'
alias eleven='echo "ᕦ( ͡° ͜ʖ ͡°)ᕤ"'

# ------------------------------------------------------------------------------
# 🎨 MODERN PALETTE & NOTO-EMOJI LAYOUT DEFINITIONS
# ------------------------------------------------------------------------------
RESET='\[\e[0m\]'
BOLD='\[\e[1m\]'

# 256-Color Muted Pastel Spectrum
COLOR_TEXT='\[\e[38;5;253m\]'       # Soft white typography
COLOR_MONO_DARK='\[\e[38;5;239m\]'   # Clean slate gray separator elements
DEMO_RED='\[\e[38;5;167m\]'         # Balanced Crimson
DEMO_PURPLE='\[\e[38;5;141m\]'      # Pastel Lavender
DEMO_CYAN='\[\e[38;5;116m\]'        # Soft Mint for working path directories
DEMO_GREEN='\[\e[38;5;150m\]'       # Sage Green for tracking states
UPSIDE_DOWN='\[\e[38;5;209m\]'      # Terracotta Orange for secondary items

# Noto-Emoji Asset Links
DEMOGORGON="👹"
PORTAL="🌀"
SKULL="💀"

# Git Info Glyphs
GIT_BRANCH=""
GIT_STAGED="●"
GIT_UNSTAGED="✚"
GIT_UNTRACKED="…"
GIT_STASH="⚑"
GIT_CLEAN="✔"

# Powerline Connectors
SEPARATOR_RIGHT=""

# ------------------------------------------------------------------------------
# 🔍 PROMPT SUBSYSTEM ENGINE FUNCTIONS
# ------------------------------------------------------------------------------

# Parse active git environment status indicators
function demogorgon_git_info() {
    local git_branch=$(git branch 2>/dev/null | grep '\*' | sed 's/* //')
    
    if [ -n "$git_branch" ]; then
        local git_status=""
        local staged=$(git diff --cached --quiet 2>/dev/null; echo $?)
        local unstaged=$(git diff --quiet 2>/dev/null; echo $?)
        local untracked=$(git ls-files --others --exclude-standard 2>/dev/null | head -1)
        local stash=$(git stash list 2>/dev/null | head -1)
        
        [ $staged -ne 0 ] && git_status+="$GIT_STAGED"
        [ $unstaged -ne 0 ] && git_status+="$GIT_UNSTAGED"
        [ -n "$untracked" ] && git_status+="$GIT_UNTRACKED"
        [ -n "$stash" ] && git_status+="$GIT_STASH"
        
        if [ -n "$git_status" ]; then
            echo " $GIT_BRANCH $git_branch $git_status"
        else
            echo " $GIT_BRANCH $git_branch $GIT_CLEAN"
        fi
    fi
}

# Parse sandbox execution spaces (Python virtualenvs / Conda environments)
function demogorgon_env_info() {
    if [ -n "$CONDA_DEFAULT_ENV" ]; then
        echo "  $CONDA_DEFAULT_ENV"
    elif [ -n "$VIRTUAL_ENV" ]; then
        echo "  $(basename $VIRTUAL_ENV)"
    fi
}

# Monitor system faults and report exit issues cleanly
function demogorgon_exit_code() {
    if [ $1 -ne 0 ]; then
        echo " $1 $SKULL"
    fi
}

# Capture asynchronous background processing counters
function demogorgon_jobs() {
    local job_count=$(jobs | wc -l | tr -d ' ')
    if [ $job_count -gt 0 ]; then
        echo " ⚙ $job_count"
    fi
}

# Keep paths aesthetic inside structural limitations
function demogorgon_pwd() {
    local dir=$(pwd | sed "s|^$HOME|~|")
    local max_len=30
    
    if [ ${#dir} -gt $max_len ]; then
        echo "...${dir: -$max_len}"
    else
        echo "$dir"
    fi
}

# ------------------------------------------------------------------------------
# 🚀 CORE PROMPT BUILDERS
# ------------------------------------------------------------------------------
function set_demogorgon_prompt() {
    local exit_code=$?
    
    # structural breakout newline
    PS1="\n"
    
    # Primary identity anchor
    PS1+="${DEMO_RED}${DEMOGORGON} ${RESET}"
    
    # Conditional environment tagging (SSH/Alternative profiles)
    if [ "$USER" != "nana" ] || [ -n "$SSH_CONNECTION" ]; then
        PS1+="${BOLD}${DEMO_RED}\u${RESET}${COLOR_MONO_DARK}@${RESET}${DEMO_RED}\h ${RESET}"
    fi
    
    # Workspace Tracking Frame
    PS1+="${COLOR_MONO_DARK}${SEPARATOR_RIGHT}${RESET}"
    PS1+=" ${DEMO_CYAN}$(demogorgon_pwd)${RESET}"
    
    # Code Repository Overlay
    local git_info=$(demogorgon_git_info)
    if [ -n "$git_info" ]; then
        PS1+=" ${COLOR_MONO_DARK}${SEPARATOR_RIGHT}${RESET}"
        PS1+="${DEMO_GREEN}${git_info}${RESET}"
    fi
    
    # Execution Layer Overlay
    local env_info=$(demogorgon_env_info)
    if [ -n "$env_info" ]; then
        PS1+=" ${COLOR_MONO_DARK}${SEPARATOR_RIGHT}${RESET}"
        PS1+="${UPSIDE_DOWN}${env_info}${RESET}"
    fi
    
    # Break to interactive terminal standard baseline input rows
    PS1+="\n"
    
    # Context Action Node (The Portal Entrypoint)
    PS1+="${DEMO_PURPLE}${PORTAL}${RESET} "
    
    # Append fault telemetry notifications if required
    local exit_display=$(demogorgon_exit_code $exit_code)
    if [ -n "$exit_display" ]; then
        PS1+="${DEMO_RED}${exit_display} ${RESET}"
    fi
    
    # Append multi-thread layout tracking states
    local jobs_display=$(demogorgon_jobs)
    if [ -n "$jobs_display" ]; then
        PS1+="${UPSIDE_DOWN}${jobs_display} ${RESET}"
    fi
    
    # Finalize indicator permissions profile assignment
    if [ $EUID -eq 0 ]; then
        PS1+="${DEMO_RED}#${RESET} "
    else
        PS1+="${COLOR_TEXT}❯${RESET} "
    fi
}

# Interactive configuration toggle layout modes
function demogorgon_prompt_menu() {
    echo "Select Demogorgon Prompt Style:"
    echo "1. Full Aesthetic Demogorgon (Pastel / Transparent Blocks)"
    echo "2. Disable Demogorgon prompt completely"
    read -p "Choice [1-2]: " choice
    
    case $choice in
        1)
            PROMPT_COMMAND=set_demogorgon_prompt
            echo "Aesthetic Demogorgon prompt tracking engine loaded!"
            ;;
        2)
            unset PROMPT_COMMAND
            PS1='\u@\h:\w\$ '
            echo "Demogorgon prompt hooks disconnected."
            ;;
        *)
            echo "Aborted: System choice unknown."
            ;;
    esac
}

# Attach execution variables directly to active bash hooks
PROMPT_COMMAND=set_demogorgon_prompt

# ------------------------------------------------------------------------------
# 🌐 HARDWARE ENVIRONMENT INTEGRATION HOOKS
# ------------------------------------------------------------------------------

# Global Bin Path Structuring
export PATH="/home/nana/.local/bin:$PATH"

# TTY Binding for VS Code & Keyring GPG Handshakes
export GPG_TTY=$(tty)

# Auto-Launch Hyprland on Local Hardware Login Shell (TTY1)
if [ -z "${WAYLAND_DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ]; then
    dbus-run-session start-hyprland
fi