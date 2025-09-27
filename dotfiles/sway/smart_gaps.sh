#!/bin/bash


if [[ $(grep "# smart_gaps on" ~/.config/i3/config) ]]
then
	sed -i 's/# smart_gaps on/smart_gaps on/g' ~/.config/i3/config
else
	sed -i 's/smart_gaps on/# smart_gaps on/g' ~/.config/i3/config
fi

i3-msg restart
