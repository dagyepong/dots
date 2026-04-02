#!/bin/sh

TOGGLE=$HOME/.toggle

if [ ! -e $TOGGLE ]; then
	touch $TOGGLE
	hyprctl keyword general:gaps_in 0
	hyprctl keyword general:gaps_out 0
	hyprctl keyword decoration:rounding 0
else
	rm $TOGGLE
	hyprctl keyword general:gaps_in 3
	hyprctl keyword general:gaps_out 5
	hyprctl keyword decoration:rounding 5
fi
