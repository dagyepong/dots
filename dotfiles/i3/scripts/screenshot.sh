#!/bin/bash
rect=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused) | .rect | "\(.x),\(.y),\(.width),\(.height)"')
scrot -a $rect -e "mv \$f ~/Pictures/Screenshots && xclip -selection clipboard -t image/png -i ~/Pictures/Screenshots/\$n"
sleep 1
notify-send "screenshot has been saved to ~/Pictures"
