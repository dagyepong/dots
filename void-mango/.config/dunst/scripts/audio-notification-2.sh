#!/usr/bin/env bash

sleep 0.05

VOLUME=$(pulsemixer --get-volume | awk '{print $1}')
IS_MUTE=$(pulsemixer --get-mute)
SOUND_FILE="$HOME/.config/dunst/sounds/audio-volume-change.oga"

paplay "$SOUND_FILE" &

NOTIFICATION_MESSAGE=""

if [[ $IS_MUTE == '1' ]]; then
    NOTIFICATION_MESSAGE="Muted"
else
    NOTIFICATION_MESSAGE="Volume: $VOLUME%"
fi

if [ "${VOLUME}" == "0" ]; then
    ICON=~/.config/dunst/icons/Papirus/volume-mute.png
elif [ "${VOLUME}" -lt "33" ] && [ $VOLUME -gt "0" ]; then
    ICON=~/.config/dunst/icons/Papirus/volume-low.png
elif [ "${VOLUME}" -lt "90" ] && [ $VOLUME -ge "33" ]; then
    ICON=~/.config/dunst/icons/Papirus/volume-mid.png
else
    ICON=~/.config/dunst/icons/Papirus/volume-high.png
fi

~/.config/dunst/notify-send.sh/notify-send.sh "$NOTIFICATION_MESSAGE" \
    --replace-file=/tmp/audio-notification \
    -t 2000 \
    -i ${ICON} \
    -h int:value:${VOLUME} \
    -h string:synchronous:volume-change
