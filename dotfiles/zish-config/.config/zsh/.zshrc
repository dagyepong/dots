
## This is zish - a fish-inspired zsh configuration

#motd, sorta

clear

source ~/.config/zish/functions/zish-specific-settings.zsh

#echo "Welcome to zish, the zoomer fish-inspired zsh shell"

if [ "$TMUX" = "" ]; then tmux; fi

# Source personal functions and variables

source ~/.config/zish/functions/functions.zsh
source ~/.config/zish/variables.zsh
source ~/.config/zish/functions/emacs.zsh
eval "$(zoxide init zsh)"
torsocks on && clear


# PROMPT SETTINGS

echo ""
fastfetch --color blue
fortune -s
cd


# [Permissions]

alias pls="doas"
alias do="doas"

# Favorite Editors // I LOVE EMACS EVIL MODE AHHH!!!

alias doom="~/.config/emacs/bin/doom"
alias doomemacs="emacs --with-profile default"
alias spacemacs="emacs --with-profile spacemacs"
alias gmacs="emacs --with-profile legacy"

export EDITOR="doomemacs"

# Common Use

alias cl="clear"
alias zish="zsh"
alias zi="zish"

# Configuration Editing

alias zishedit="emacs ~/.config/zsh/.zshrc"
alias functionedit="emacs ~/.config/zish/functions/functions.zsh"
alias varedit="emacs ~/.config/zish/variables.zsh"
alias bashedit="emacs ~/.bashrc"

alias buildedit="doas /usr/bin/vi /etc/portage/package.env"
alias provideedit="doas /usr/bin/vi /etc/portage/profile/package.provided"

## For Hyprland

alias hypredit="emacs ~/.config/hypr/hyprland.conf"

# Common Editor Replacement(s)

alias nano="pls rnano"
alias vim="emacs"
alias vi="emacs"
alias .vim="doas vim"
alias .vi="doas vi"

# Gentoo GNU/Linux [PORTAGE]

alias emerge="doas emerge"
alias emerge-a="doas emerge --ask"
alias esync="emerge --sync"

alias eupgrade-a="cl && emerge -auvDN @world @system"
alias eupdate-a="esync && eupgrade-a"
alias eupgrade-p="eupgrade-a -p"
alias eupdate-p="eupgrade-a -p"

alias eworldupdate="esync && emerge -e @world @system"
alias eworldupdate-a="eworldupdate -a"
alias eupgrade="cl && emerge -uvDN @world @system"
alias eupdate="esync && eupgrade"

alias eremove="emerge --deselect"
alias edepclean="emerge --depclean"
alias eselect="doas eselect"

alias equery="doas equery"
alias esearch="doas esearch"
alias eupdatedb="doas eupdatedb"
alias euse="doas euse"
alias eix="doas eix"
alias eix-update="doas eix-update"
alias dispatch-config="doas dispatch-conf"

alias useedit=".vi /etc/portage/package.useflags"
alias makeedit=".vi /etc/portage/make.conf"

# END OF [PORTAGE]

# [UTILITIES]

# Replace some more things with better alternatives

alias eza-ls='eza --color=always --group-directories-first --icons' # preffered listing
alias eza-la='eza -a --color=always --group-directories-first --icons'  # all files and dirs
alias eza-ll='eza -l --color=always --group-directories-first --icons'  # long format
alias eza-lt='eza -aT --color=always --group-directories-first --icons' # tree listing
alias eza-l.="eza -a | egrep '^\.'"                                     # show only dotfiles

alias ls='eza-ls'
alias la='eza-la'
alias ll='eza-ll'
alias lt='eza-lt'
alias l.='eza-l.'
alias l="ls"

alias cd='z'
alias cd..='z ..'
alias cd...='z ../..'
alias cd....='z ../../..'
alias cd.....='z ../../../..'
alias cd......='z ../../../../..'
alias z..='z ..'
alias z...='z ../..'
alias z....='z ../../..'
alias z.....='z ../../../..'
alias z......='z ../../../../..'
alias ..='z..'
alias ...='z...'
alias ....='z....'
alias .....='z.....'
alias ......='z......'

alias lsgrep="ls | grep"
alias rm="~/.cargo/bin/safe-rm"
alias cpr="cp -r"
alias dcp="doas cp"
alias scpr="dcp -r"
alias srm="doas rm"
alias srmrf="srm -rf"
alias srmdir="doas rmdir"
alias cat='bat --style header --style snip --style changes --style header'
alias top="doas btop --utf-force"
alias htop="top"
alias btop="top"
alias ip="ip -color"
alias xx="exit"

# Commonly used

alias genkernel="doas genkernel kernel && doas dracut"

alias update-grub="doas grub-mkconfig -o /boot/grub/grub.cfg"
alias grubup="update-grub"

alias tarnow='tar -acf '
alias untar='tar -xvf '
alias wget='wget -c '
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias hw='hwinfo --short'                          # Hardware Info
alias big="expac -H M '%m\t%n' | sort -h | nl"     # Sort installed packages according to size in MB

# Misc. Scripts

alias qtb="qutebrowser"
alias qtb-edit="emacs ~/.config/qutebrowser/config.py"
alias daddy="/usr/bin/shell-daddy"
alias doomupgrade="doom upgrade"

alias ytfzf="ytfzf -l -s -t --ytdl-path=/usr/bin/yt-dlp --scrape=youtube,odysee,peertube --nsfw --formats --pages=2 --pages-start=1 --sort-by=relevance --notify-playing --thumb-viewer=ueberzug --thumbnail-quality=maxres"
alias yt="ytfzf"

# Development

# For Codeberg.org - stats

alias berg="~/.cargo/bin/berg"

# Git [Development] Shorthand

alias git.="git add ."
alias commita=" git commit -a"
alias commit="git commit"
alias push="git push"
alias pull="git pull"

alias commitpush="commita & push"
alias gitcommitpush="git. && commitpush"

alias rustc="doas rustc"
alias rustfmt="doas rustfmt"

## Z-SHELL [Command Interface] Shorthands

alias zshcopy="dcp ~/.config/zsh/.zshrc ~/.g/dotfiles/zish-config/.config/zsh/.zshrc"
alias zishcopy="zshcopy && scpr ~/.config/zish/* ~/.g/dotfiles/zish-config/.config/zish/"
alias zishupdate="zishcopy && cd ~/.g/dotfiles/ && gitcommitpush"

# System

alias zfs="doas zfs"
alias zsnapshots="zfs list -t snapshot"
alias rollback="zfs -r rollback"
alias zfs-undelete="~/.cargo/bin/zfs-undelete"
alias zrollback="zfs rollback"
alias zdelete="zfs destroy"
alias zdel-rootsnapshot="zdelete tank/ROOT/system@hyprland_complete"
alias zdel-homesnapshot="zdelete tank/home@hyprland_complete"
alias zdel-clean="zdel-rootsnapshot && zdel-homesnapshot"
alias zsnapshot="zfs snapshot"
alias zsavepoint="zsnapshot tank/ROOT/system@hyprland_complete && zsnapshot tank/home@hyprland_complete"
alias zpool="doas zpool"

# Network

alias protonvpn="doas protonvpn"
alias protonconnect="protonvpn c"
alias protonc="protonconnect"

# System(d)

alias .systemctl="doas systemctl"
alias usystemctl="systemctl --user"
alias journalctl="doas journalctl"

# If Pipewire needs restart

alias rewire="usystemctl restart pipewire"
