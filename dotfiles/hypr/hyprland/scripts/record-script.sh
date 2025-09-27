#!/usr/bin/env bash

getdate() {
  date '+%Y-%m-%d_%H.%M.%S'
}
getaudiooutput() {
  pactl list sources | grep 'Name' | grep 'monitor' | cut -d ' ' -f2
}
getactivemonitor() {
  hyprctl monitors -j | gojq -r '.[] | select(.focused == true) | .name'
}
getrefreshrate() {
  hyprctl monitors -j | gojq -r '.[] | select(.focused == true) | .refreshRate | floor'
}

mkdir -p "$HOME/Videos/Recorded/"
cd "$HOME/Videos/Recorded/" || exit
if pgrep wf-recorder >/dev/null; then
  notify-send "Recording Stopped" "Stopped" -a 'record-script.sh' &
  pkill wf-recorder &
else
  notify-send "Starting recording" 'recording_'"$(getdate)"'.mp4' -a 'record-script.sh'
  if [[ "$1" == "--sound" ]]; then
    wf-recorder -c h264_vaapi -d /dev/dri/renderD128 --framerate "$(getrefreshrate)" -f "recording_$(getdate).mp4" --geometry "$(slurp)" --audio=alsa_output.pci-0000_30_00.6.analog-stereo.monitor &
    disown
  elif [[ "$1" == "--fullscreen-sound" ]]; then
    wf-recorder -c h264_vaapi -d /dev/dri/renderD128 --framerate "$(getrefreshrate)" -o $(getactivemonitor) -f "recording_$(getdate).mp4" --audio=alsa_output.pci-0000_30_00.6.analog-stereo.monitor &
    disown
  elif [[ "$1" == "--fullscreen" ]]; then
    wf-recorder -c h264_vaapi -d /dev/dri/renderD128 --framerate "$(getrefreshrate)" -o $(getactivemonitor) -f "recording_$(getdate).mp4" &
    disown
  else
    wf-recorder -c h264_vaapi -d /dev/dri/renderD128 --framerate "$(getrefreshrate)" -f "recording_$(getdate).mp4" --geometry "$(slurp)" &
    disown
  fi
fi
