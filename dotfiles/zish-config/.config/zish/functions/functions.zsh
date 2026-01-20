
# Set settings for https://github.com/franciscolourenco/done
export __done_min_cmd_duration=10000
export __done_notification_urgency_level=low

# Apply .profile: use this to put zsh compatible .profile stuff in
if [[ -f ~/.zprofile ]]; then
  source ~/.zprofile
fi

# Add ~/.local/bin to PATH
if [[ -d ~/.local/bin ]] && [[ ! $path[(r)~/.local/bin] ]]; then
    export PATH=~/.local/bin:$PATH
fi

# Add depot_tools to PATH
if [[ -d ~/Applications/depot_tools ]] && [[ ! $path[(r)~/Applications/depot_tools] ]]; then
    export PATH=~/Applications/depot_tools:$PATH
fi

# Starship prompt
eval "$(starship init zsh)"

# Functions needed for !! and !$ https://github.com/oh-my-fish/plugin-bang-bang
__history_previous_command() {
  case $BUFFER[1] in
    \!)
      BUFFER=${BUFFER:2}
      history -s "!${history[1]}"
      ;;
    \*)
      BUFFER="!$"
      ;;
  esac
  zle reset-prompt
}

__history_previous_command_arguments() {
  case $BUFFER[1] in
    \!)
      BUFFER=${BUFFER:2}
      zle history-incremental-search-backward
      ;;
    \*)
      BUFFER='$'
      ;;
  esac
  zle end-of-line
}

if [[ $KEYMAP = vicmd ]]; then
  bindkey -M vicmd '!' __history_previous_command
  bindkey -M vicmd '$' __history_previous_command_arguments
else
  bindkey '!' __history_previous_command
  bindkey '$' __history_previous_command_arguments
fi

# Copy DIR1 DIR2
copy() {
    local count=${#argv}
    if [[ "$count" -eq 2 ]] && [[ -d "$argv[1]" ]]; then
        local from=${argv[1]%/}
        local to=$argv[2]
        cp -r $from $to
    else
        cp $argv
    fi
}

# Reboot function
reboot() {
    read -s -k '?Are you sure you would like to reboot? (y or n): ' __reboot_key
    echo

    if [[ -n "$__reboot_key" && "$__reboot_key" = "y" ]]; then
    	sudo reboot
    else
        echo "Reboot canceled."
    fi
}

# Alias for history command with timestamps
alias history="fc -lt"

# Alias for creating a backup of a file
alias backup="cp --backup=t"
