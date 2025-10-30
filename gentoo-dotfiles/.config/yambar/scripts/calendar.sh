#!/bin/bash

# Calendar script

function ShowCalendar() {
	notify-send -i "calendar"  "    📅 Calendar" "$(cal | sed "s/\<$(date +%-d)\>/<span color='#fabd2f'><b>$(date +%-d)<\/b><\/span>/")"  --hint=string:x-canonical-private-synchronous:calendar
}

function EditCalendar() {
  echo 
}

case "$1" in
        show)
            ShowCalendar
            ;;
         
        edit)
            EditCalendar
            ;;
         
        *)
            echo $"Usage: ${0##*/} {show|edit}"
            exit 1
 
esac
