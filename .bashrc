#!/bin/bash
# demogorgon_prompt.sh - A Stranger Things demogorgon-themed bash prompt



alias b='bash'
alias v='vim'

alias ls='ls --file-type --color=auto'
alias la='ls -A'
alias ll='ls -l'
alias cat="bat -p"
alias pfetch="curl -s https://raw.githubusercontent.com/dylanaraps/pfetch/master/pfetch | sh"
alias update="sudo emaint -a sync && sudo emerge -avuDN @world"
alias rm='rm -fr'

# adding flags
alias df='df -h'               # human-readable sizes
alias free='free -m'           # show sizes in MB
alias grep='grep --color=auto' # colorize output (good for log files)

# ps
alias psa="ps auxf"
alias psgrep="ps aux | grep -v grep | grep -i -e VSZ -e"
alias psmem='ps auxf | sort -nr -k 4'
alias pscpu='ps auxf | sort -nr -k 3'

# Color definitions
RESET='\[\e[0m\]'
BLACK='\[\e[30m\]'
RED='\[\e[31m\]'
GREEN='\[\e[32m\]'
YELLOW='\[\e[33m\]'
BLUE='\[\e[34m\]'
MAGENTA='\[\e[35m\]'
CYAN='\[\e[36m\]'
WHITE='\[\e[37m\]'
BRIGHT_RED='\[\e[91m\]'
BRIGHT_GREEN='\[\e[92m\]'
BRIGHT_YELLOW='\[\e[93m\]'
BRIGHT_BLUE='\[\e[94m\]'
BRIGHT_MAGENTA='\[\e[95m\]'
BRIGHT_CYAN='\[\e[96m\]'
BRIGHT_WHITE='\[\e[97m\]'

# Background colors
BG_RED='\[\e[41m\]'
BG_GREEN='\[\e[42m\]'
BG_YELLOW='\[\e[43m\]'
BG_BLUE='\[\e[44m\]'
BG_MAGENTA='\[\e[45m\]'
BG_CYAN='\[\e[46m\]'
BG_BRIGHT_RED='\[\e[101m\]'

# Demogorgon colors
DEMO_RED='\[\e[38;5;124m\]'    # Dark red
DEMO_PURPLE='\[\e[38;5;90m\]'  # Purple
DEMO_GREEN='\[\e[38;5;106m\]'  # Sickly green
DEMO_GRAY='\[\e[38;5;245m\]'   # Gray
UPSIDE_DOWN='\[\e[38;5;202m\]' # Upside down orange

# Symbols
DEMOGORGON="👹"
DEMOGORGON_FACE="🗿"
VINES="🌿"
FLOWER="🌸"
UPSIDE_DOWN_EMOJI="🙃"
PORTAL="🌀"
BLOOD="🩸"
SKULL="💀"
WARNING="⚠️"
ALIEN="👽"

# Git status symbols
GIT_BRANCH=""
GIT_STAGED="●"
GIT_UNSTAGED="✚"
GIT_UNTRACKED="…"
GIT_STASH="⚑"
GIT_AHEAD="↑"
GIT_BEHIND="↓"
GIT_CONFLICT="✖"
GIT_CLEAN="✔"

# Powerline symbols
SEPARATOR_RIGHT=""
SEPARATOR_LEFT=""
SEPARATOR_ROUND_RIGHT=""
SEPARATOR_ROUND_LEFT=""

# Function to get git branch info
function demogorgon_git_info() {
    local git_branch=$(git branch 2>/dev/null | grep '\*' | sed 's/* //')
    
    if [ -n "$git_branch" ]; then
        local git_status=""
        local staged=$(git diff --cached --quiet 2>/dev/null; echo $?)
        local unstaged=$(git diff --quiet 2>/dev/null; echo $?)
        local untracked=$(git ls-files --others --exclude-standard 2>/dev/null | head -1)
        local stash=$(git stash list 2>/dev/null | head -1)
        
        # Build status string
        [ $staged -ne 0 ] && git_status+="$GIT_STAGED"
        [ $unstaged -ne 0 ] && git_status+="$GIT_UNSTAGED"
        [ -n "$untracked" ] && git_status+="$GIT_UNTRACKED"
        [ -n "$stash" ] && git_status+="$GIT_STASH"
        
        # Check if we have any status
        if [ -n "$git_status" ]; then
            echo " $GIT_BRANCH $git_branch $git_status"
        else
            echo " $GIT_BRANCH $git_branch $GIT_CLEAN"
        fi
    fi
}

# Function to get conda/env info
function demogorgon_env_info() {
    if [ -n "$CONDA_DEFAULT_ENV" ]; then
        echo "  $CONDA_DEFAULT_ENV"
    elif [ -n "$VIRTUAL_ENV" ]; then
        echo "  $(basename $VIRTUAL_ENV)"
    fi
}

# Function to get exit code if not 0
function demogorgon_exit_code() {
    if [ $1 -ne 0 ]; then
        echo " $1 $SKULL"
    fi
}

# Function to get background jobs
function demogorgon_jobs() {
    local job_count=$(jobs | wc -l | tr -d ' ')
    if [ $job_count -gt 0 ]; then
        echo " ⚙ $job_count"
    fi
}

# Function to truncate current directory
function demogorgon_pwd() {
    local dir=$(pwd | sed "s|^$HOME|~|")
    local max_len=30
    
    if [ ${#dir} -gt $max_len ]; then
        echo "...${dir: -$max_len}"
    else
        echo "$dir"
    fi
}

# Main prompt function
function set_demogorgon_prompt() {
    local exit_code=$?
    
    # First line: User info and path
    PS1="\n"
    
    # Demogorgon symbol with red background
    PS1+="${BG_BRIGHT_RED}${BRIGHT_WHITE} ${DEMOGORGON} ${RESET}"
    PS1+="${DEMO_RED}${SEPARATOR_RIGHT}${RESET}"
    
    # User info (only show if not default or SSH)
    if [ "$USER" != "nana" ] || [ -n "$SSH_CONNECTION" ]; then
        PS1+="${BG_RED}${WHITE} \u@\h ${RESET}"
        PS1+="${DEMO_RED}${SEPARATOR_RIGHT}${RESET}"
    fi
    
    # Current directory
    PS1+="${DEMO_PURPLE}${BG_BLUE}${WHITE} 📁 $(demogorgon_pwd) ${RESET}"
    PS1+="${BLUE}${SEPARATOR_RIGHT}${RESET}"
    
    # Git info
    local git_info=$(demogorgon_git_info)
    if [ -n "$git_info" ]; then
        PS1+="${DEMO_GREEN}${BG_GREEN}${BLACK}$git_info ${RESET}"
        PS1+="${GREEN}${SEPARATOR_RIGHT}${RESET}"
    fi
    
    # Python env info
    local env_info=$(demogorgon_env_info)
    if [ -n "$env_info" ]; then
        PS1+="${UPSIDE_DOWN}${BG_YELLOW}${BLACK}$env_info ${RESET}"
        PS1+="${YELLOW}${SEPARATOR_RIGHT}${RESET}"
    fi
    
    # End of first line
    PS1+="\n"
    
    # Second line: Prompt with demogorgon face
    PS1+="${DEMO_RED}${PORTAL}${RESET} "
    
    # Show exit code if not 0
    local exit_display=$(demogorgon_exit_code $exit_code)
    if [ -n "$exit_display" ]; then
        PS1+="${BRIGHT_RED}${exit_display} ${RESET}"
    fi
    
    # Show background jobs
    local jobs_display=$(demogorgon_jobs)
    if [ -n "$jobs_display" ]; then
        PS1+="${BRIGHT_YELLOW}${jobs_display} ${RESET}"
    fi
    
    # Final prompt character (changes based on user)
    if [ $EUID -eq 0 ]; then
        PS1+="${BRIGHT_RED}#${RESET} "
    else
        PS1+="${DEMO_GREEN}❯${RESET} "
    fi
}

# Alternative minimalist version
function set_minimal_demogorgon_prompt() {
    local exit_code=$?
    
    # Simple one-line prompt
    PS1="${DEMO_RED}${DEMOGORGON}${RESET} "
    PS1+="${DEMO_PURPLE}\w${RESET}"
    
    # Git info
    local git_info=$(demogorgon_git_info)
    if [ -n "$git_info" ]; then
        PS1+="${DEMO_GREEN}$git_info${RESET}"
    fi
    
    # Exit code if not 0
    if [ $exit_code -ne 0 ]; then
        PS1+=" ${BRIGHT_RED}[$exit_code]${RESET}"
    fi
    
    # Prompt character
    PS1+="\n"
    if [ $EUID -eq 0 ]; then
        PS1+="${BRIGHT_RED}#${RESET} "
    else
        PS1+="${DEMO_GREEN}❯${RESET} "
    fi
}

# ASCII art version (no emoji support)
function set_ascii_demogorgon_prompt() {
    local exit_code=$?
    
    PS1="\n"
    PS1+="${BG_BRIGHT_RED}${BRIGHT_WHITE} D ${RESET}"
    PS1+="${DEMO_RED}${RESET}"
    PS1+="${DEMO_PURPLE}${BG_BLUE}${WHITE} \w ${RESET}"
    PS1+="${BLUE}${RESET}"
    
    local git_info=$(demogorgon_git_info 2>/dev/null)
    if [ -n "$git_info" ]; then
        PS1+="${DEMO_GREEN}${BG_GREEN}${BLACK}$git_info ${RESET}"
        PS1+="${GREEN}${RESET}"
    fi
    
    PS1+="\n"
    
    if [ $exit_code -ne 0 ]; then
        PS1+="${BRIGHT_RED}[$exit_code]${RESET} "
    fi
    
    if [ $EUID -eq 0 ]; then
        PS1+="${BRIGHT_RED}#${RESET} "
    else
        PS1+="${DEMO_GREEN}>${RESET} "
    fi
}

# Interactive version with different styles
function demogorgon_prompt_menu() {
    echo "Select Demogorgon Prompt Style:"
    echo "1. Full Demogorgon (with emoji)"
    echo "2. Minimal Demogorgon"
    echo "3. ASCII Demogorgon (no emoji)"
    echo "4. Disable Demogorgon prompt"
    read -p "Choice [1-4]: " choice
    
    case $choice in
        1)
            PROMPT_COMMAND=set_demogorgon_prompt
            echo "Full Demogorgon prompt enabled!"
            ;;
        2)
            PROMPT_COMMAND=set_minimal_demogorgon_prompt
            echo "Minimal Demogorgon prompt enabled!"
            ;;
        3)
            PROMPT_COMMAND=set_ascii_demogorgon_prompt
            echo "ASCII Demogorgon prompt enabled!"
            ;;
        4)
            unset PROMPT_COMMAND
            PS1='\u@\h:\w\$ '
            echo "Demogorgon prompt disabled!"
            ;;
        *)
            echo "Invalid choice!"
            ;;
    esac
}

# Set the default prompt
PROMPT_COMMAND=set_demogorgon_prompt

# Enable color support
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Add some demogorgon-themed aliases
alias demo-status='echo "The Demogorgon is watching..."'
alias upside-down='echo "Welcome to the Upside Down"'
alias vecna-cursed='echo "You have been cursed by Vecna!"'
alias eleven='echo "ᕦ( ͡° ͜ʖ ͡°)ᕤ"'

# Welcome message
echo -e "${DEMO_RED}"
echo "   ___  ___  __  __  ___  ____   ___  ____  "
echo "  / _ \/ _ \/ / / / / _ \/ __ \ / _ \/ __ \ "
echo " / // / , _/ /_/ / / // / /_/ / // / /_/ / "
echo "/____/_/|_|\____/ /____/\____/____/\____/  "
echo -e "${RESET}"
echo "Demogorgon prompt activated! Type 'demogorgon_prompt_menu' to change styles."


  if [ -z "${WAYLAND_DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ]; then
    dbus-run-session hyprland
fi
