#!/usr/bin/env bash
# ┐─┐┐ ┬┐─┐┌─┐┬─┐┌┐┐
# └─┐└┌┘└─┐│  │─┤ │ 
# ──┘ ┆ ──┘└─┘┘ ┆ ┆ 
# syscat by pyratebeard (https://git.pyratebeard.net/dotfiles/file/bin/bin/syscat.html)
#  └─ forked from info.sh by z3bra (https://pub.z3bra.org/monochromatic/misc/info.sh)

gitdir="https://git.pyratebeard.net"
myblog="https://log.pyratebeard.net"
homepage="https://pyratebeard.net"

# Color definitions
# The script can use ANSI escape codes for coloring.
c00=$'\e[0;30m'
c01=$'\e[0;31m'
c02=$'\e[0;32m'
c03=$'\e[0;33m'
c04=$'\e[0;34m'
c05=$'\e[0;35m'
c06=$'\e[0;36m'
c07=$'\e[0;37m'
c08=$'\e[1;30m'
c09=$'\e[1;31m'
c10=$'\e[1;32m'
c11=$'\e[1;33m'
c12=$'\e[1;34m'
c13=$'\e[1;35m'
c14=$'\e[1;36m'
c15=$'\e[1;37m'

f0=$'\e[1;30m'
f1=$'\e[1;37m'
f2=$'\e[0;37m'

# System information gathering
host=$(hostname -s)
up=$(uptime -p | cut -b4- | tr -d ',eeksayourinute')
kernel=$(uname -r | tr '[:upper:]' '[:lower:]')
cpuspe=$(sed -n '/model\ name/s/^.*:\ //p' /proc/cpuinfo | uniq | rev | cut -d' ' -f 3- | rev | tr '[:upper:]' '[:lower:]')
cpu_usage=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage}')
load=$(printf "%.0f" "$cpu_usage")%

# System information specific to Gentoo
system="Gentoo OpenRC"
pkgnum=$(ls -d /var/db/pkg/*/* | wc -l)
birthd=$(head -n 1 /var/log/emerge.log | awk '{print $1}' | tr - . | sed 's/-$//')

# Terminal environment info
if [ -n "$DISPLAY" ]; then
    wmname=$(xprop -root _NET_WM_NAME | cut -d\" -f2)
    # This is an assumption based on common terminal configurations. Adjust as needed.
    termfn=$(grep -Ei "^urxvt\*font" ~/.Xdefaults | awk -F: '{print $3}' | sed 's/-//g')
    fnsize=$(grep -Ei "^urxvt\*font" ~/.Xdefaults | grep -Eo '[0-9]{1,2}' | head -n1)
    termco=$(awk -F/ '/colors/{print $NF}' ~/.Xdefaults | tr -d '"')
else
    wmname="none"
    termfn="none"
    termco="none"
fi

# Main function for the detailed output
main() {
cat << EOF
${c00}▓▒  ${f0}│ ${f1}host ${f0}......... $f2$host
${c08}  ▒░${f0}│ ${f1}up ${f0}........... $f2$up
${c01}▓▒  ${f0}│ 
${c09}  ▒░${f0}│ ${f1}os ${f0}........... $f2$system
${c02}▓▒  ${f0}│ ${f1}birth ${f0}........ $f2$birthd
${c10}  ▒░${f0}│ 
${c03}▓▒  ${f0}│ ${f1}wm ${f0}........... $f2$wmname
${c11}  ▒░${f0}│ ${f1}shell ${f0}........ $f2$SHELL
${c04}▓▒  ${f0}│ ${f1}term ${f0}......... $f2$TERM
${c12}  ▒░${f0}│ ${f1}font ${f0}......... $f2$termfn $fnsize
${c05}▓▒  ${f0}│ ${f1}colors ${f0}....... $f2$termco
${c13}  ▒░${f0}│ 
${c06}▓▒  ${f0}│ ${f1}kernel ${f0}....... $f2$kernel
${c14}  ▒░${f0}│ ${f1}processor ${f0}.... $f2$cpuspe
${c07}▓▒  ${f0}│ ${f1}memory ${f0}....... $f2$ram
${c15}  ▒░${f0}│ ${f1}pkg ${f0}.......... $f2$pkgnum
${c15}  ▒░${f0}│ ${f1}homepage ${f0}..... $f2$homepage
EOF
}

# Mini function for a condensed output
mini() {
cat << EOF
${f1}host ${f0}...... $f2$host
${f1}sys ${f0}....... $f2$system
${f1}wm ${f0}........ $f2$wmname
${f1}shell ${f0}..... $f2$SHELL
${f1}term ${f0}...... $f2$TERM
${f1}font ${f0}...... $f2$termfn $fnsize
${f1}colours ${f0}... $f2$termco
${f1}kernel ${f0}.... $f2$kernel
${f1}load ${f0}...... $f2$load
${f1}pkg ${f0}....... $f2$pkgnum
EOF
}

# Command-line argument handling
if [ $# -eq 0 ] ; then
    mini
else
    opt="$1"
    case ${opt} in
        mini) mini ;;
        main) main ;;
        *) mini ;;
    esac
fi

