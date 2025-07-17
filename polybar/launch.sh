$ cat ~/.config/polybar/launch
#!/bin/bash
 
# Terminate already running bar instances
killall -q polybar
# If all your bars have ipc enabled, you can also use 
# polybar-msg cmd quit
 
###########
# COLOURS #
###########
 
# Import colors from xrdb
#color6=$(xrdb -query | grep "color6" | cut -f2 | head -n 1)
 
# Export custom colours
export selection="#45475a"
 
# Export vars to use in parts of Polybar statements
#export BAR_FS_LABEL_MOUNTED="%{F$color6}%mountpoint%%{F-}: %percentage_used%%"
 
########
# VARS #
########
 
TERMINAL_EXEC="alacritty -e"
export BAR_FS_LABEL_MOUNTED="%{A1:${TERMINAL_EXEC} ncdu /:}%mountpoint%: %percentage_used%%%{A}"
export BAR_CPU_FORMAT_PREFIX="%{A1:${TERMINAL_EXEC} btm:} %{A}"
export BAR_CPU_LABEL="%{A1:${TERMINAL_EXEC} btm:}%percentage:2%%%{A}" # Twice, because format-prefix uses larger font size
 
# Launch Polybar, using default config location ~/.config/polybar/config
polybar main 2>&1 | tee -a /tmp/polybar.log &
polybar tray 2>&1 | tee -a /tmp/polybar.log & disown
 
echo "Polybar launched..."