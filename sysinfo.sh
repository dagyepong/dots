#!/usr/bin/env bash

# This script is just a slightly modified version taken from Barbaross' Muspelheim rice : https://github.com/Barbaross93/Muspelheim
# sysinfo: A sort of custom script
# Thanks to u/x_ero for his sysinfo script
# Also thanks to mysterious person for their fetch script; allowing for center padding

# color escapes
BLK="\e[30m"
RED="\e[31m"
GRN="\e[32m"
YLW="\e[33m"
BLU="\e[34m"
PUR="\e[35m"
CYN="\e[36m"
WHT="\e[37m"
GRY="\e[90;1m"
RST="\e[0m"
BLD="\033[1m"

PBLK=$(printf "%b" "\x1b[38;2;58;58;58m")
PRED=$(printf "%b" "\e[31m")
PGRN=$(printf "%b" "\e[32m")
PYLW=$(printf "%b" "\e[33m")
PBLU=$(printf "%b" "\e[34m")
PPUR=$(printf "%b" "\e[35m")
PCYN=$(printf "%b" "\e[36m")
PWHT=$(printf "%b" "\e[37m")
PGRY=$(printf "%b" "\e[90;1m")
PRST=$(printf "%b" "\e[0m")
PBLD=$(printf "%b" "\033[1m")

# vars
#FULL=▓
#EMPTY=░
#FULL=━
#EMPTY=━
FULL=─
#FULL=┅
EMPTY=┄

name=$USER
host=$(uname -n)
battery=/sys/class/power_supply/BAT1
distro="⛩ rch Linux"
kernel=$(uname -r)
pkgs=$(pacman -Q | wc -l)
colors='alduin'
font='Terminus'
wm="herbsltuftwm"
shell=$(basename $(printenv SHELL))
term=$(echo "$TERM")
term="${term%-256color}"
#uptm=$(uptime -p | sed -e 's/hour/hr/' -e 's/hours/hrs/' -e 's/minutes/mins/' -e 's/minute/min/' -e 's/up //')
uptm=$(uptime -p)

#Cleanup first
clear

#find the center of the screen
COL=$(tput cols)
ROW=$(tput lines)
((PADY = ROW / 2 - 10 - 22 / 2))
((PADX = COL / 2 - 34 / 2))

for ((i = 0; i < PADX; ++i)); do
	PADC="$PADC "
done

for ((i = 0; i < PADY; ++i)); do
	PADR="$PADR\n"
done

# vertical padding
printf "%b" "$PADR"
printf "\n"

PADXX=$((PADX - 3))
for ((i = 0; i < PADXX; ++i)); do
	PADCC="$PADCC "
done

# # Ascii art arms

# cat <<EOF
# $PADCC$PRST	⣠⣤⣀⣀⣀⣀⣀⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣀⣀⣀⣀⣀⣤⣄
# $PADCC$PBLK	⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟
# $PADCC$PRED	⠀⠈⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠁⠀
# $PADCC$PRED	⠀⠀⠀⠀⢸⣿⡇⠀⠀⠀⢸⣿⣿⣿⣿⡇⠀⠀⠀⢸⣿⡇⠀⠀⠀⠀
# $PADCC$PRED	⠀⠀⠀⠀⣸⣿⣇⠀⠀⠀⢸⣿⣿⣿⣿⡇⠀⠀⠀⣸⣿⣇⠀⠀⠀⠀
# $PADCC$PRED	⠀⠀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⠀⠀
# $PADCC$PRED	⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀
# $PADCC$PRED	⠀⠀⠀⠉⢹⣿⣿⣿⡏⠉⠉⠉⠉⠉⠉⠉⠉⢹⣿⣿⣿⡏⠉⠀⠀⠀
# $PADCC$PRED	⠀⠀⠀⠀⢸⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⡇⠀⠀⠀⠀
# $PADCC$PRED	⠀⠀⠀⠀⢸⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⡇⠀⠀⠀⠀
# $PADCC$PRED	⠀⠀⠀⠀⢸⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⡇⠀⠀⠀⠀
# $PADCC$PGRY	⠀⠀⠀⢸⢸⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⡇⡇⠀⠀⠀
# $PADCC$PBLK 	⠀⠀⠀⠀⠘⠛⠛⠛⠁⠀⠀⠀⠀⠀⠀⠀⠀⠈⠛⠛⠛⠃⠀⠀⠀⠀
# EOF



#BAR="█▓▒░"
#OUTT="$BLK$BAR$RED$BAR$GRN$BAR$YLW$BAR$BLU$BAR$PUR$BAR$CYN$BAR$WHT$BAR$RST"
#printf "%s%b" "$PADC" "$OUTT"
printf "\n\n"

# greetings
printf "%s%b" "$PADC" "          hello $RED$BLD$name$RST\n"
printf "%s%b" "$PADC" "       welcome to $GRN$BLD$host$RST\n"
printf "%s%b" "$PADC" "    uptime: $CYN$BLD$uptm$RST\n\n"

printf "%s" "$PADC"
i=0
while [ $i -le 6 ]; do
	printf "\e[$((i + 41))m\e[$((i + 30))m█▓▒░"
	i=$(($i + 1))
done
printf "\e[37m█\e[0m▒░\n\n"


# environment
printf "%s%b" "$PADC" "$YLW        distro $GRY╪ $RST$distro\n"
printf "%s%b" "$PADC" "$YLW        kernel $GRY╪ $RST$kernel\n"
printf "%s%b" "$PADC" "$YLW      packages $GRY╪ $RST$pkgs\n"
printf "%s%b" "$PADC" "$YLW         shell $GRY╪ $RST$shell\n"
printf "%s%b" "$PADC" "$YLW          term $GRY╪ $RST$term\n"
printf "%s%b" "$PADC" "$YLW            wm $GRY╪ $RST$wm\n"
printf "%s%b" "$PADC" "$YLW          font $GRY╪ $RST$font\n"
printf "%s%b" "$PADC" "$YLW        colors $GRY╪ $RST$colors\n"
printf " $RST\n"

# progress bar
draw() {
	perc=$1
	size=$2
	inc=$((perc * size / 100))
	out=
	color="$3"
	for v in $(seq 0 $((size - 1))); do
		test "$v" -le "$inc" &&
			out="${out}\e[1;${color}m${FULL}" ||
			out="${out}\e[0;37m${GRY}${EMPTY}"
	done
	printf $out
}

# cpu
cpu=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage}')
c_lvl=$(printf "%.0f" $cpu)
printf "%b" "$PADC"
printf "   $PUR%-4s $WHT%-5s %-25s \n" " cpu" "$c_lvl%" $(draw $c_lvl 15 35)

# ram
ram=$(free | awk '/Mem:/ {print int($3/$2 * 100.0)}')
printf "%b" "$RST$PADC"
printf "   $PUR%-4s $WHT%-5s %-25s \n" " ram" "$ram%" $(draw $ram 15 35)

# temperature
#temp=$(sensors | awk '/Core 0/ {gsub(/\+/,"",$3); gsub(/\..+/,"",$3)    ; print $3}')
# temp=$(cat /proc/acpi/ibm/thermal | awk '{print $2}')
# printf "%b" "$RST$PADC"
# printf "   $PUR%-4s $WHT%-5s %-25s \n\n" " tmp" "$temp°c " $(draw $temp 15 35)

# hide the cursor and wait for user input
tput civis
read -n 1

# give the cursor back
tput cnorm
