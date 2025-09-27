#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: $0 --title | --artist | --album | --source | --source-symbol"
    exit 1
fi

# Variables
LAST_ACTIVE_SOURCE_FILE="/tmp/last_active_source"
YOUTUBE_API_KEY="AIzaSyBPqnoiybk4hsArBNujG2NWsCa8G_AMlUM" # Replace with your actual YouTube API key
MAX_LENGTH=50                                             # Maximum length of the text before truncation

# Function to get metadata using playerctl
get_metadata() {
    key=$1
    playerctl metadata --format "{{ $key }}" 2>/dev/null
}

# Function to get MPD metadata
get_mpd_metadata() {
    case $1 in
    title)
        mpc current | awk -F " - " '{print $2}' | sed 's/\[.*\]//'
        ;;
    artist)
        mpc current | awk -F " - " '{print $1}' | sed 's/\[.*\]//'
        ;;
    album)
        mpc -f %album% | head -n 1
        ;;
    esac
}

# Function to check if MPD is stopped
is_mpd_stopped() {
    if [[ -z "$(mpc current 2>/dev/null)" ]]; then
        return 0 # MPD is stopped
    else
        return 1 # MPD is playing or paused
    fi
}

# Function to get the current MPD status
get_mpd_status() {
    if is_mpd_stopped; then
        echo "stopped"
    else
        mpc status | grep -Eo '^\[playing\]|\[paused\]' | tr -d '[]'
    fi
}

# Function to track the most recently active source
track_active_source() {
    local source=$1
    echo "$source" >"$LAST_ACTIVE_SOURCE_FILE"
}

# Retrieve the last tracked source
get_last_active_source() {
    if [[ -f "$LAST_ACTIVE_SOURCE_FILE" ]]; then
        cat "$LAST_ACTIVE_SOURCE_FILE"
    else
        echo ""
    fi
}

# Function to get the current active source
get_active_source() {
    local mpd_status=""
    local playerctl_status=""

    # Check MPD status
    if pgrep -x "mpd" >/dev/null; then
        mpd_status=$(get_mpd_status)
        if [[ "$mpd_status" == "playing" ]]; then
            track_active_source "mpd:playing"
            echo "mpd:playing"
            return
        elif [[ "$mpd_status" == "paused" ]]; then
            track_active_source "mpd:paused"
        elif [[ "$mpd_status" == "stopped" ]]; then
            # If MPD is stopped, clear its last tracked state
            sed -i '/^mpd:/d' "$LAST_ACTIVE_SOURCE_FILE" 2>/dev/null
        fi
    else
        # If MPD is not running, clear its last tracked state
        sed -i '/^mpd:/d' "$LAST_ACTIVE_SOURCE_FILE" 2>/dev/null
    fi

    # Check playerctl status
    playerctl_status=$(playerctl status 2>/dev/null)
    if [[ "$playerctl_status" == "Playing" ]]; then
        track_active_source "playerctl:playing"
        echo "playerctl:playing"
        return
    elif [[ "$playerctl_status" == "Paused" ]]; then
        track_active_source "playerctl:paused"
    fi

    # Fallback: Only use the last tracked source if it is paused and the process is still running
    local last_active_source=$(get_last_active_source)
    if [[ "$last_active_source" == "mpd:paused" && $(pgrep -x "mpd") && "$(get_mpd_status)" != "stopped" ]]; then
        echo "$last_active_source"
    elif [[ "$last_active_source" == "playerctl:paused" && $(playerctl status 2>/dev/null) ]]; then
        echo "$last_active_source"
    else
        echo "" # No active source
    fi
}

# Function to check if the current player is a YouTube video
is_youtube_video() {
    local url
    url=$(get_metadata "xesam:url")
    if [[ "$url" =~ "youtube.com" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to fetch video title from YouTube
get_youtube_video_title() {
    local url
    url=$(get_metadata "xesam:url")
    # Extract the video title from YouTube URL if it's a video
    if [[ "$url" =~ "youtube.com/watch" ]]; then
        title=$(get_metadata "xesam:title")
        echo "$title"
    else
        echo ""
    fi
}

# Function to fetch playlist title from YouTube using the same approach
get_youtube_playlist_title() {
    local url
    url=$(get_metadata "xesam:url")
    # Extract the playlist ID from the YouTube URL
    if [[ "$url" =~ "youtube.com/playlist" ]]; then
        playlist_id=$(echo "$url" | grep -oP 'list=\K[^&]*')

        # Use curl to fetch playlist data from YouTube API
        response=$(curl -s "https://www.googleapis.com/youtube/v3/playlists?part=snippet&id=$playlist_id&key=$YOUTUBE_API_KEY")

        # Extract the playlist title using jq
        playlist_title=$(echo "$response" | jq -r '.items[0].snippet.title')

        # If playlist title is found, return it, otherwise return an error message
        if [[ "$playlist_title" == "null" || -z "$playlist_title" ]]; then
            echo "Playlist title not found"
        else
            echo "$playlist_title"
        fi
    else
        echo "" # Not a playlist
    fi
}

# Function to return a symbol for the current source
get_source_info_symbol() {
    local source
    source=$(get_active_source)

    case $source in
    "mpd:playing" | "mpd:paused")
        echo "" # MPD symbol
        ;;
    "playerctl:playing" | "playerctl:paused")
        local trackid
        trackid=$(get_metadata "mpris:trackid")
        if [[ "$trackid" == *"firefox"* ]]; then
            echo "󰈹"
        elif [[ "$trackid" == *"spotify"* ]]; then
            echo ""
        elif [[ "$trackid" == *"chromium"* ]]; then
            echo ""
        else
            echo "󰎆"
        fi
        ;;
    *)
        echo ""
        ;;
    esac
}

# Function to get source information
get_source_info() {
    local source
    source=$(get_active_source)

    case $source in
    "mpd:playing" | "mpd:paused")
        echo "Music Player Daemon"
        ;;
    "playerctl:playing" | "playerctl:paused")
        local trackid
        trackid=$(get_metadata "mpris:trackid")
        if [[ "$trackid" == *"firefox"* ]]; then
            echo "Firefox"
        elif [[ "$trackid" == *"spotify"* ]]; then
            echo "Spotify"
        elif [[ "$trackid" == *"chromium"* ]]; then
            echo "Chrome"
        else
            echo "Other"
        fi
        ;;
    *)
        echo ""
        ;;
    esac
}

# Function to truncate text with ellipsis (improved to remove trailing spaces)
truncate_with_ellipsis() {
    text=$1
    max_length=$2
    if [ ${#text} -gt $max_length ]; then
        # Truncate to max_length and remove any trailing spaces
        truncated_text="${text:0:$max_length}"
        truncated_text=$(echo "$truncated_text" | sed 's/ *$//') # Remove trailing spaces
        echo "${truncated_text:0:$((max_length - 3))}..."        # Append ellipsis directly
    else
        echo "$text"
    fi
}

case "$1" in
--title)
    source=$(get_active_source)
    case $source in
    "mpd:playing" | "mpd:paused")
        if ! is_mpd_stopped; then
            title=$(get_mpd_metadata "title")
        else
            title=""
        fi
        ;;
    "playerctl:playing" | "playerctl:paused")
        title=$(get_metadata "xesam:title")
        if is_youtube_video; then
            title=$(get_youtube_video_title) # Correct title fetching for YouTube
        fi
        ;;
    esac
    truncated_title=$(truncate_with_ellipsis "${title:-}" $MAX_LENGTH)
    echo "$truncated_title"
    ;;
--artist)
    source=$(get_active_source)
    case $source in
    "mpd:playing" | "mpd:paused")
        if ! is_mpd_stopped; then
            artist=$(get_mpd_metadata "artist")
        else
            artist=""
        fi
        ;;
    "playerctl:playing" | "playerctl:paused")
        artist=$(get_metadata "xesam:artist")
        ;;
    esac
    truncated_artist=$(truncate_with_ellipsis "${artist:-}" $MAX_LENGTH)
    echo "$truncated_artist"
    ;;
--status-symbol)
    # Get the current active source
    source=$(get_active_source)

    # Check the status of the source
    case $source in
    "mpd:playing")
        echo "󰎆" # MPD playing symbol
        ;;
    "playerctl:playing")
        echo "󰎆" # Playerctl playing symbol
        ;;
    "mpd:paused")
        echo "󰏥" # MPD paused symbol
        ;;
    "playerctl:paused")
        echo "󰏥" # Playerctl paused symbol
        ;;
    *)
        echo "" # No active source
        ;;
    esac
    ;;
--status)
    source=$(get_active_source)
    case $source in
    "mpd:playing")
        echo "Playing Now"
        ;;
    "playerctl:playing")
        echo "Playing Now"
        ;;
    "mpd:paused" | "playerctl:paused")
        echo "Paused"
        ;;
    *)
        echo "" # No active source
        ;;
    esac
    ;;
--album)
    source=$(get_active_source)
    case $source in
    "mpd:playing" | "mpd:paused")
        if ! is_mpd_stopped; then
            album=$(get_mpd_metadata "album")
        else
            album=""
        fi
        ;;
    "playerctl:playing" | "playerctl:paused")
        album=$(get_metadata "xesam:album")
        if is_youtube_video; then
            album=$(get_youtube_playlist_title) # Fetch playlist title for YouTube
        fi
        ;;
    esac
    truncated_album=$(truncate_with_ellipsis "${album:-}" $MAX_LENGTH)
    echo "$truncated_album"
    ;;
--source-symbol)
    get_source_info_symbol
    ;;
--source)
    get_source_info
    ;;
*)
    echo "Invalid option: $1"
    echo "Usage: $0 --title | --artist | --album | --source | --source-symbol"
    exit 1
    ;;
esac
