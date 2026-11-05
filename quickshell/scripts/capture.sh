#!/bin/sh
# usage: capture.sh shot-area | shot-window | shot-screen
#      capture.sh rec-area | rec-screen [screen] [audio: off|mic|system|both] [microphone]
#      capture.sh pause | resume | stop      (recording in progress)
#      capture.sh status                     (read by Capture.qml: rec/paused/idle + file to rename)
#      capture.sh latest                     (latest recording with default name, last 2 minutes)
#      capture.sh rename <file> [name]       (empty name = keep the date and time one)
# Requires: grim slurp wl-clipboard jq wf-recorder (libnotify for notifications, pactl for audio,
#           ffmpeg to merge the parts when you use pause)

shots="$HOME/Screenshots"
vids="$HOME/Videos/Recordings"
rt="${XDG_RUNTIME_DIR:-/tmp}"
pending="$rt/quickshell-capture-pending"
ctl="$rt/quickshell-capture"          # control file for the recording in progress

notify() {
    command -v notify-send >/dev/null 2>&1 && notify-send "$1" "$2"
}

case "$1" in
    status)
        pid=$(cat "$ctl/active" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            if [ -e "$ctl/pause" ]; then echo paused; else echo rec; fi
        elif pgrep -x wf-recorder >/dev/null 2>&1; then
            echo rec
        else
            echo idle
        fi
        [ -s "$pending" ] && cat "$pending"
        exit 0
        ;;
    pause)
        [ -e "$ctl/active" ] || exit 0
        [ -e "$ctl/pause" ] && exit 0
        touch "$ctl/pause"
        pkill -INT -x wf-recorder
        exit 0
        ;;
    resume)
        [ -e "$ctl/pause" ] && touch "$ctl/resume"
        exit 0
        ;;
    stop)
        # while paused no wf-recorder is running: the script waits for this file
        if [ -e "$ctl/pause" ]; then touch "$ctl/stop"; else pkill -INT -x wf-recorder; fi
        exit 0
        ;;
    latest)
        find "$vids" -maxdepth 1 -name '20[0-9][0-9]-*.mp4' -mmin -2 -printf '%T@ %p\n' 2>/dev/null \
            | sort -nr | head -n1 | cut -d' ' -f2-
        exit 0
        ;;
    rename)
        src="$2"
        name="$3"
        [ -f "$src" ] || { rm -f "$pending"; exit 0; }
        dir=$(dirname "$src")
        # no slashes or newlines, no leading spaces/dots, no double ".mp4"
        name=$(printf '%s' "$name" | tr '/\n' '__' | sed 's/^[ .]*//; s/[ ]*$//')
        case "$name" in *.mp4|*.MP4) name="${name%.*}" ;; esac
        [ -n "$name" ] || name=$(basename "$src" .mp4)
        dest="$dir/$name.mp4"
        n=1
        while [ -e "$dest" ] && [ "$dest" != "$src" ]; do
            dest="$dir/$name-$n.mp4"
            n=$((n + 1))
        done
        [ "$dest" = "$src" ] || mv -- "$src" "$dest"
        rm -f "$pending"
        notify "Recording saved" "$dest"
        exit 0
        ;;
esac

mkdir -p "$shots" "$vids"
ts=$(date +%Y-%m-%d_%H-%M-%S)

# On niri NIRI_SOCKET is set, on Hyprland it is not
is_niri() { [ -n "$NIRI_SOCKET" ]; }

focused_output() {
    if is_niri; then
        niri msg --json workspaces | jq -r '.[] | select(.is_focused) | .output'
    else
        hyprctl -j monitors | jq -r '.[] | select(.focused) | .name'
    fi
}

# temporary audio modules (only for "both" mode)
mods=""
cleanup() {
    for m in $mods; do pactl unload-module "$m" >/dev/null 2>&1; done
    mods=""
}
trap 'cleanup; rm -f "$ctl/active"' EXIT

# usage: start_rec <audio> <microphone> <wf-recorder options...>
start_rec() {
    f="$vids/$ts.mp4"
    parts="$vids/.rec-$ts"
    audio="$1"
    mic="$2"
    shift 2
    aopt=""

    case "$audio" in
        mic)
            [ -n "$mic" ] || mic=$(pactl get-default-source 2>/dev/null)
            if [ -n "$mic" ]; then aopt="--audio=$mic"; else aopt="--audio"; fi
            ;;
        system)
            sink=$(pactl get-default-sink 2>/dev/null)
            if [ -n "$sink" ]; then aopt="--audio=$sink.monitor"; else aopt="--audio"; fi
            ;;
        both)
            # wf-recorder records a single source: mix microphone and system audio
            # into a temporary virtual sink and record that
            [ -n "$mic" ] || mic=$(pactl get-default-source 2>/dev/null)
            sink=$(pactl get-default-sink 2>/dev/null)
            mix=qs_rec_mix
            m1=$(pactl load-module module-null-sink sink_name=$mix sink_properties=device.description=QsRecMix 2>/dev/null)
            m2=$(pactl load-module module-loopback source="$mic" sink=$mix latency_msec=30 2>/dev/null)
            m3=$(pactl load-module module-loopback source="$sink.monitor" sink=$mix latency_msec=30 2>/dev/null)
            mods="$m3 $m2 $m1"
            if [ -n "$m1" ]; then aopt="--audio=$mix.monitor"; else aopt="--audio"; fi
            ;;
    esac

    mkdir -p "$ctl" "$parts"
    rm -f "$ctl/pause" "$ctl/resume" "$ctl/stop"
    echo $$ > "$ctl/active"
    : > "$parts/list"

    notify "Recording started" "Right-click the pill for options"

    # Pause = close the current part; resume = start a new one. At the end I merge them.
    n=0
    cnt=0
    last=""
    while :; do
        n=$((n + 1))
        if [ "$n" -eq 1 ]; then part="$f"; else part="$parts/part$n.mp4"; fi

        # $aopt unquoted: it is either empty or a single option
        wf-recorder $aopt "$@" -f "$part"

        if [ -s "$part" ]; then
            cnt=$((cnt + 1))
            last="$part"
            printf "file '%s'\n" "$part" >> "$parts/list"
        fi

        [ -e "$ctl/pause" ] || break
        while [ ! -e "$ctl/resume" ] && [ ! -e "$ctl/stop" ]; do sleep 0.3; done
        [ -e "$ctl/stop" ] && break
        rm -f "$ctl/pause" "$ctl/resume"
    done
    cleanup

    if [ "$cnt" -gt 1 ]; then
        if command -v ffmpeg >/dev/null 2>&1 \
           && ffmpeg -loglevel error -y -f concat -safe 0 -i "$parts/list" -c copy "$parts/merged.mp4" \
           && [ -s "$parts/merged.mp4" ]; then
            mv -f -- "$parts/merged.mp4" "$f"
        else
            # without ffmpeg the parts stay separate
            i=1
            for p in "$f" "$parts"/part*.mp4; do
                [ -s "$p" ] || continue
                [ "$p" = "$f" ] && continue
                i=$((i + 1))
                mv -- "$p" "$vids/$ts-part$i.mp4"
            done
            mv -- "$f" "$vids/$ts-part1.mp4"
            notify "Recording" "ffmpeg not found: saved as separate parts in $vids"
            rm -rf "$parts"
            return
        fi
    elif [ "$cnt" -eq 1 ] && [ "$last" != "$f" ]; then
        mv -f -- "$last" "$f"
    fi
    rm -rf "$parts"

    # the file is named with date and time; the shell asks if you want to change it
    [ -s "$f" ] && printf '%s\n' "$f" > "$pending"
}

# let the Quickshell card disappear before capturing
sleep 0.35

case "$1" in
    shot-area)
        geo=$(slurp) || exit 0
        f="$shots/$ts.png"
        grim -g "$geo" "$f" && wl-copy < "$f" && notify "Screenshot saved" "$f"
        ;;
    shot-window)
        if is_niri; then
            # niri already knows how to capture the active window (folder and clipboard as per its configuration)
            niri msg action screenshot-window
            notify "Screenshot" "Active window captured"
            exit 0
        fi
        geo=$(hyprctl -j activewindow | jq -r 'select(.at != null) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        if [ -z "$geo" ]; then
            notify "Screenshot" "No active window"
            exit 0
        fi
        f="$shots/$ts.png"
        grim -g "$geo" "$f" && wl-copy < "$f" && notify "Screenshot saved" "$f"
        ;;
    shot-screen)
        out=$(focused_output)
        f="$shots/$ts.png"
        grim -o "$out" "$f" && wl-copy < "$f" && notify "Screenshot saved" "$f"
        ;;
    rec-area)
        geo=$(slurp) || exit 0
        start_rec "${3:-off}" "$4" -g "$geo"
        ;;
    rec-screen)
        out="$2"
        [ -n "$out" ] || out=$(focused_output)
        start_rec "${3:-off}" "$4" -o "$out"
        ;;
esac
