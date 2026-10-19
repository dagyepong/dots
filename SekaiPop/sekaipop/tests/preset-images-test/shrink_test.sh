#!/bin/sh
# Runs ../../shrink-image.sh on made-up pictures: what gets scaled, what is
# copied untouched, and what happens with other tools or none.
# Needs ImageMagick to make the pictures (magick or convert); skips otherwise.
#   sh tests/preset-images-test/shrink_test.sh
here=$(cd "$(dirname "$0")" && pwd)
SH="$here/../../scripts/images/shrink-image.sh"
have() { command -v "$1" >/dev/null 2>&1; }
if have magick; then IM="magick"; ID="magick identify"; elif have convert; then IM="convert"; ID="identify"
else echo "skipped: no ImageMagick to make test pictures"; exit 0; fi
t=$(mktemp -d) && cd "$t" || exit 1
trap 'rm -rf "$t"' EXIT
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; fail=1; fi; }
dim() { $ID -ping -format '%wx%h' "$1[0]" 2>/dev/null; }
same() { cmp -s "$1" "$2" && echo same || echo different; }

$IM -size 3000x2000 plasma:fractal big.png
$IM -size 6000x1000 plasma:fractal pano.jpg
$IM -size 600x500 plasma:fractal small.png
$IM -size 3000x300 plasma:fractal short.png
printf '<svg xmlns="http://www.w3.org/2000/svg" width="5000" height="5000"/>' > big.svg
$IM -size 3000x3000 xc:red big.gif

sh "$SH" avatar big.png a.png;     check "avatar covers 800x800"            "$(dim a.png)" 1200x800
sh "$SH" banner big.png b.png;     check "banner covers 2000x800"           "$(dim b.png)" 2000x1333
sh "$SH" banner pano.jpg p.jpg;    check "panorama keeps the crop's detail" "$(dim p.jpg)" 4800x800
sh "$SH" avatar small.png s.png;   check "small copied byte for byte"       "$(same small.png s.png)" same
sh "$SH" banner short.png sh.png;  check "wide but short left alone"        "$(same short.png sh.png)" same
sh "$SH" avatar big.svg o.svg;     check "svg left alone"                   "$(same big.svg o.svg)" same
sh "$SH" avatar big.gif o.gif;     check "gif left alone"                   "$(same big.gif o.gif)" same
sh "$SH" avatar nope.png x.png 2>/dev/null; check "missing source fails"    $? 2
sh "$SH" hat big.png x.png 2>/dev/null;     check "bad kind fails"          $? 2
check "no temp files left behind" "$(ls | grep -c '\.tmp')" 0

# No ImageMagick: ffmpeg + ffprobe do it; with neither it is a plain copy.
mkpath() { d=$1; shift; mkdir "$d"; for x in sh cp mv rm nice tr head cat sed printf test dirname ionice "$@"; do p=$(command -v "$x") && ln -s "$p" "$d/$x"; done; }
if have ffmpeg && have ffprobe; then
    mkpath ff ffmpeg ffprobe
    PATH="$t/ff" sh "$SH" avatar big.png f.png; check "ffmpeg path scales"  "$(dim f.png)" 1200x800
fi
mkpath none
PATH="$t/none" sh "$SH" avatar big.png n.png; check "no tools: plain copy" "$(same big.png n.png)" same

[ $fail = 0 ] && echo "shrink_test: all checks passed" || { echo "shrink_test: FAILED"; exit 1; }
