#!/bin/sh

# Helper for LyricsService.qml: the lyrics it has already found, and the .lrc files
# that sit next to your music.
#
#   lyrics-cache.sh get <key>          print the cached JSON for a track (nothing if none)
#   lyrics-cache.sh put <key> <json>   keep <json> for a track
#   lyrics-cache.sh local <file-url>   print the .lrc beside a local file (the same name
#                                      with .lrc), if there is one
#
# <key> is the 32 hex digits of an md5 (the service makes it from the artist, the title
# and the length), so nothing from outside can name a path. The cache is a cache:
# ${XDG_CACHE_HOME:-~/.cache}/sekaipop/lyrics/<key>.json, safe to delete any time.

mode="$1"
dir="${XDG_CACHE_HOME:-$HOME/.cache}/sekaipop/lyrics"
MAX=262144

valid_key() {
    case "$1" in
        *[!0-9a-f]*|"") return 1 ;;
    esac
    [ "${#1}" -eq 32 ]
}

case "$mode" in
    get)
        valid_key "$2" || exit 2
        [ -f "$dir/$2.json" ] && cat "$dir/$2.json"
        exit 0
        ;;
    put)
        valid_key "$2" || exit 2
        mkdir -p "$dir" || exit 1
        printf '%s\n' "$3" > "$dir/$2.json.tmp" || exit 1
        mv "$dir/$2.json.tmp" "$dir/$2.json"
        ;;
    local)
        case "$2" in
            file://*) ;;
            *) exit 0 ;;
        esac
        path="${2#file://}"
        # %20 and friends back to bytes (awk, because `printf '\x..'` is not in every sh;
        # LC_ALL=C so a byte above 127 stays one byte)
        path=$(printf '%s' "$path" | LC_ALL=C awk 'BEGIN { h = "0123456789abcdef" }
            {
                s = $0; out = ""
                while ((i = index(s, "%")) > 0) {
                    out = out substr(s, 1, i - 1)
                    a = tolower(substr(s, i + 1, 2))
                    if (a ~ /^[0-9a-f][0-9a-f]$/) {
                        out = out sprintf("%c", (index(h, substr(a, 1, 1)) - 1) * 16 + index(h, substr(a, 2, 1)) - 1)
                        s = substr(s, i + 3)
                    } else {
                        out = out "%"
                        s = substr(s, i + 1)
                    }
                }
                print out s
            }')
        lrc="${path%.*}.lrc"
        if [ -f "$lrc" ] && [ "$(wc -c < "$lrc")" -le "$MAX" ]; then
            cat "$lrc"
        fi
        exit 0
        ;;
    *)
        echo "usage: $0 get <key>|put <key> <json>|local <file-url>" >&2
        exit 2
        ;;
esac
