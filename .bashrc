# ~/.bashrc

[[ $- != *i* ]]&& return

shopt -s autocd cdspell dirspell cdable_vars

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

# Merge Xresources
alias merge='xrdb -merge ~/.Xresources'

# git
alias addup='git add -u'
alias addall='git add .'
alias branch='git branch'
alias checkout='git checkout'
alias clone='git clone'
alias commit='git commit -m'
alias fetch='git fetch'
alias pull='git pull origin'
alias push='git push origin'
alias stat='git status'  # 'status' is protected name so using 'stat' instead
alias tag='git tag'
alias newtag='git tag -a'

# get error messages from journalctl
alias jctl="journalctl -p 3 -xb"


# bigger font in tty and regular font in tty
alias bigfont="setfont ter-132b"
alias regfont="setfont default8x16"

# the terminal rickroll
alias rr='curl -s -L https://raw.githubusercontent.com/keroserene/rickrollrc/master/roll.sh | bash'



sucColor='\e[38;2;102;255;102m'
errColor='\e[38;2;255;110;106m'
if (( EUID )); then
  userColor="$sucColor" userSymbol='$'
else
  userColor="$errColor" userSymbol='#'
fi

prompt_command(){
  unset branch tag

  [[ $PWD =~ ^$HOME ]]&& { PWD="${PWD#$HOME}" PWD="~$PWD"; }

  local branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  local tag="$(git describe --tags --abbrev=0 2>/dev/null)"

  printf '\e[2;38;2;255;176;0m%s\e[m' "$PWD"
  [[ $branch ]]&& printf ' \e[2m%s\e[m \e[38;2;243;79;41m\e[m \e[2m%s\e[m' \
    "$branch" "$tag"
  echo
}

PROMPT_COMMAND=prompt_command

PS1="\[$userColor\]\$USER\[\e[m\]@\[\e[38;2;255;176;0m\]\$HOSTNAME\[\e[m\] \
\$((( \$? ))\
  && printf '\[$errColor\]$userSymbol\[\e[m\]> '\
  || printf '\[$sucColor\]$userSymbol\[\e[m\]> ')"

PS4="-[\e[33m${BASH_SOURCE[0]%.sh}\e[m: \e[32m$LINENO\e[m]\
  ${FUNCNAME:+${FUNCNAME[0]}(): }"