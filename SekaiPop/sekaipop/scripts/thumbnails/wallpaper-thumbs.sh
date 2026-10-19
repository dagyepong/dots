#!/bin/sh

# Helper for WallpaperService.qml: small cached thumbnails for the wallpaper
# picker, and a still frame for video wallpapers.
#
#   wallpaper-thumbs.sh scan <dir>     for every picture / video in <dir>, print
#                                      <file><TAB><thumbnail><TAB><1 if it exists, else 0>
#   wallpaper-thumbs.sh make <dir>     make the missing thumbnails; prints
#                                      ok<TAB><file><TAB><thumbnail> as each one is done
#   wallpaper-thumbs.sh still <video>  print the path of the video's first frame at
#                                      full size (made if missing); empty + exit 1 on failure
#   wallpaper-thumbs.sh clear          delete the whole cache
#
# The cache is ${XDG_CACHE_HOME:-~/.cache}/sekaipop/wallpaper/{thumbs,stills}. A
# file's key is the md5 of its path, size and modification time, so editing or
# replacing a picture makes a new thumbnail and the old one is simply left behind
# (`clear` removes them all).
#
# Pictures are scaled with ImageMagick (magick / convert), else ffmpeg. Videos
# need ffmpeg (or ffmpegthumbnailer for thumbnails). Without any of them nothing
# is made and the picker just loads the originals, as it always did.

base="${XDG_CACHE_HOME:-$HOME/.cache}/sekaipop/wallpaper"
thumbs="$base/thumbs"
stills="$base/stills"
width=720

have() { command -v "$1" >/dev/null 2>&1; }

is_video() {
    case "$(printf '%s' "$1" | tr 'A-Z' 'a-z')" in
        *.mp4|*.webm|*.mkv|*.mov|*.avi) return 0 ;;
    esac
    return 1
}

key() {
    st=$(stat -c '%s-%Y' "$1" 2>/dev/null) || st=0
    printf '%s|%s' "$1" "$st" | md5sum | cut -d' ' -f1
}

media_files() {
    find "$1" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
        -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.mp4' -o -iname '*.webm' \
        -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.avi' \) 2>/dev/null | sort
}

make_thumb() {
    f="$1"; out="$2"
    mkdir -p "$thumbs" || return 1
    tmp="$out.tmp.jpg"
    if is_video "$f"; then
        if have ffmpeg; then
            ffmpeg -v error -y -ss 1 -i "$f" -frames:v 1 -vf "scale=$width:-2" "$tmp" 2>/dev/null \
                || ffmpeg -v error -y -i "$f" -frames:v 1 -vf "scale=$width:-2" "$tmp" 2>/dev/null
        elif have ffmpegthumbnailer; then
            ffmpegthumbnailer -i "$f" -o "$tmp" -s "$width" 2>/dev/null
        else
            return 1
        fi
    elif have magick; then
        magick "$f[0]" -thumbnail "${width}x" -quality 82 "$tmp" 2>/dev/null
    elif have convert; then
        convert "$f[0]" -thumbnail "${width}x" -quality 82 "$tmp" 2>/dev/null
    elif have ffmpeg; then
        ffmpeg -v error -y -i "$f" -frames:v 1 -vf "scale=$width:-2" "$tmp" 2>/dev/null
    else
        return 1
    fi
    [ -s "$tmp" ] && mv "$tmp" "$out" || { rm -f "$tmp"; return 1; }
}

case "$1" in
    scan)
        dir="$2"; [ -d "$dir" ] || exit 0
        media_files "$dir" | while IFS= read -r f; do
            t="$thumbs/$(key "$f").jpg"
            if [ -s "$t" ]; then e=1; else e=0; fi
            printf '%s\t%s\t%s\n' "$f" "$t" "$e"
        done
        ;;
    make)
        dir="$2"; [ -d "$dir" ] || exit 0
        media_files "$dir" | while IFS= read -r f; do
            t="$thumbs/$(key "$f").jpg"
            [ -s "$t" ] && continue
            make_thumb "$f" "$t" && printf 'ok\t%s\t%s\n' "$f" "$t"
        done
        ;;
    still)
        f="$2"
        [ -f "$f" ] || exit 1
        out="$stills/$(key "$f").jpg"
        if [ ! -s "$out" ]; then
            have ffmpeg || exit 1
            mkdir -p "$stills" || exit 1
            tmp="$out.tmp.jpg"
            ffmpeg -v error -y -ss 1 -i "$f" -frames:v 1 -q:v 2 "$tmp" 2>/dev/null \
                || ffmpeg -v error -y -i "$f" -frames:v 1 -q:v 2 "$tmp" 2>/dev/null
            [ -s "$tmp" ] && mv "$tmp" "$out" || { rm -f "$tmp"; exit 1; }
        fi
        printf '%s\n' "$out"
        ;;
    clear)
        rm -rf "$thumbs" "$stills"
        ;;
    *)
        echo "usage: $0 scan <dir>|make <dir>|still <video>|clear" >&2
        exit 2
        ;;
esac
exit 0
