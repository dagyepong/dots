#!/bin/sh

D=$(wofi --conf /home/ein/.config/wofi/config/config --style /home/ein/.config/wofi/src/mocha/style.css --allow-images --show drun)

if [ -z "$D" ]; then
  exit 0
fi

case "$D" in
*'.desktop '*) echo "${D%.desktop *}.desktop:${D#*.desktop }" ;;
*) echo "$D" ;;
esac | xargs uwsm app --
