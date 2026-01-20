
# Important Variables

export EDITOR='emacsclient -c -a emacs'
export VISUAL='emacsclient -c -a emacs'
# /etc/skel/.bashrc
#
# This file is sourced by all *interactive* bash shells on startup,
# including some apparently interactive shells such as scp and rcp
# that can't tolerate any output.  So make sure this doesn't display
# anything or bad things will happen !


# Test for an interactive shell.  There is no need to set anything
# past this point for scp and rcp, and it's important to refrain from
# outputting anything in those cases.
if [[ $- != *i* ]] ; then
	# Shell is non-interactive.  Be done now!
	return
fi

# Important Variables


export EDITOR="/usr/bin/vim"
export LLVM=1
export RUSTC_WRAPPER="/usr/bin/sccache"
export SCCACHE_DIR="/var/cache/sccache"
export SCCACHE_MAX_FRAME_LENGTH="104857600"


export ALTERNATE_EDITOR='vim'
alias e='emacsclient -c -a emacs'

# I prefer password in the terminal

export GIT_ASKPASS=""

# Put your fun stuff here

# Aliases

alias daddy="/usr/bin/shell-daddy.sh"
