
# Screenshots scripts

sDIR="$HOME/.config/mango/"
notify_cmd_shot="notify-send -h string:x-canonical-private-synchronous:shot-notify -u low -i ${iDIR}/picture.png"

time=$(date +"%d-%m-%Y_%H-%M-%S")
dir="$(xdg-user-dir)/Pictures/Screenshots"
file="Screenshot_${time}.png"

active_window_class=$(hyprctl -j activewindow | jq -r '(.class)')
active_window_file="Screenshot_${time}_${active_window_class}.png"
active_window_path="${dir}/${active_window_file}"

# notify and view screenshot
notify_view() {
    if [[ "$1" == "active" ]]; then
        if [[ -e "${active_window_path}" ]]; then
            ${notify_cmd_shot} "Screenshot of '${active_window_class}' Saved."
            "${sDIR}/Sounds.sh" --screenshot
        else
            ${notify_cmd_shot} "Screenshot of '${active_window_class}' not Saved"
            "${sDIR}/Sounds.sh" --error
        fi
    elif [[ "$1" == "swappy" ]]; then
		${notify_cmd_shot} "Screenshot Captured."
    else
        local check_file="$dir/$file"
        if [[ -e "$check_file" ]]; then
            ${notify_cmd_shot} "Screenshot Saved."
            "${sDIR}/Sounds.sh" --screenshot
        else
            ${notify_cmd_shot} "Screenshot NOT Saved."
            "${sDIR}/Sounds.sh" --error
        fi
    fi
}



# countdown
countdown() {
	for sec in $(seq $1 -1 1); do
		notify-send -h string:x-canonical-private-synchronous:shot-notify -t 1000 -i "$iDIR"/timer.png "Taking shot in : $sec"
		sleep 1
	done
}

# take shots
shotnow() {
	cd ${dir} && grim - | tee "$file" | wl-copy
	sleep 2
	notify_view
}

shot5() {
	countdown '5'
	sleep 1 && cd ${dir} && grim - | tee "$file" | wl-copy
	sleep 1
	notify_view
	
}

shot10() {
	countdown '10'
	sleep 1 && cd ${dir} && grim - | tee "$file" | wl-copy
	notify_view
}

shotarea() {
	tmpfile=$(mktemp)
	grim -g "$(slurp)" - >"$tmpfile"
	if [[ -s "$tmpfile" ]]; then
		wl-copy <"$tmpfile"
		mv "$tmpfile" "$dir/$file"
	fi
	notify_view
}

shotswappy() {
	tmpfile=$(mktemp)
	grim -g "$(slurp)" - >"$tmpfile" && "$HOME/.config/mango/Sounds.sh" --screenshot && notify_view "swappy"
	swappy -f - <"$tmpfile"
	rm "$tmpfile"
}


if [[ ! -d "$dir" ]]; then
	mkdir -p "$dir"
fi

if [[ "$1" == "--now" ]]; then
	shotnow
elif [[ "$1" == "--in5" ]]; then
	shot5
elif [[ "$1" == "--in10" ]]; then
	shot10
elif [[ "$1" == "--win" ]]; then
	shotwin
elif [[ "$1" == "--area" ]]; then
	shotarea
elif [[ "$1" == "--active" ]]; then
	shotactive
elif [[ "$1" == "--swappy" ]]; then
	shotswappy
else
	echo -e "Available Options : --now --in5 --in10 --win --area --active --swappy"
fi

exit 0
