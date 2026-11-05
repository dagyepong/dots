#!/bin/sh
# usage: clip-thumbs.sh <folder> <id> [<id> ...]
# Creates thumbnails of copied images (in a temporary folder of the user)
dir="$1"
shift
mkdir -p "$dir"
for id in "$@"; do
    f="$dir/$id"
    [ -s "$f" ] || cliphist decode "$id" > "$f" 2>/dev/null
done
