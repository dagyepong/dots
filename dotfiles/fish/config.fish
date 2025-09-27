function fish_prompt -d "Write out the prompt"
    # This shows up as USER@HOST /home/user/ >, with the directory colored
    # $USER and $hostname are set by fish, so you can just use them
    # instead of using `whoami` and `hostname`
    printf '%s@%s %s%s%s > ' $USER $hostname \
        (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
end

# WAYLAND
# Hyprland
#if uwsm check may-start
#    exec uwsm start hyprland.desktop
#end

#if [ -z $DISPLAY ] && [ "$(tty)" = /dev/tty1 ]
#    exec Hyprland
#end

# PLASMA
#if [ -z $DISPLAY ] && [ "$(tty)" = /dev/tty1 ]
#    exec startplasma-wayland
#end

#function sxhkd
#      set -Ux SXHKD_SHELL '/bin/sh'
#end 

# Start X at login
#if status is-interactive
#    if test -z "$DISPLAY" -a "$XDG_VTNR" = 1
#        xinit --keeptty
#    end
#end

alias cp="rsync -rahv --mkpath --info=progress2"
alias d='yt-dlp --extract-audio --audio-format mp3 --audio-quality 0 -o "%(title)s.%(ext)s"'
alias dv='yt-dlp --audio-format mp3 --audio-quality 0 -o "%(title)s.%(ext)s"'
alias get="doas pacman -S "
alias rem="doas pacman -R "
alias remall="doas pacman -Rdns "
alias up="doas pacman -Syu"
alias upa="yay"
alias v="nvim"

alias i3conf="nvim ~/.config/i3/config"

#function mv
#    rsync -rahv --mkpath --remove-source-files --info=progress2
#end

if status is-interactive
    # Commands to run in interactive sessions can go here
    set fish_greeting

end

starship init fish | source

# function fish_prompt
#   set_color cyan; echo (pwd)
#   set_color green; echo '> '
# end

# Added by LM Studio CLI tool (lms)
set -gx PATH $PATH /home/ein/.cache/lm-studio/bin

# Added by LM Studio CLI tool (lms)
set -gx PATH $PATH /home/ein/.lmstudio/bin

# make pass use primary selection
set -x PASSWORD_STORE_CLIPBOARD_COMMAND "wl-copy --primary"
set -x PASSWORD_STORE_CLIP_TIME 25
