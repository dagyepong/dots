#!/bin/sh

# Helper for services/LockCropService.qml: a tiny copy of a picture, as plain-text
# PPM ("P3"), so the Calendar lockscreen can work out which parts of it are worth
# showing in its picture frames.
#
#   lock-crop.sh <picture>        prints the picture scaled to fit 96 x 96 as P3
#                                 text on stdout; nothing + exit 1 on failure
#
# Same tool order as scripts/thumbnails/wallpaper-thumbs.sh: ImageMagick (magick /
# convert). Without it nothing is printed and the lockscreen simply uses its fixed
# frame positions. The picture is NOT auto-rotated on purpose: Qt does not rotate it
# by its EXIF tag either, so this sees what the lockscreen shows. A multi-frame file
# (a gif) uses its first frame. Runs at low priority; one call takes a few tens of
# milliseconds. Writes nothing to disk.

f="$1"
[ -f "$f" ] || exit 1

have() { command -v "$1" >/dev/null 2>&1; }

if have magick; then
    tool=magick
elif have convert; then
    tool=convert
else
    exit 1
fi

if have nice; then
    nice -n 15 "$tool" "$f[0]" -background white -alpha remove -alpha off \
        -resize 96x96 -colorspace sRGB -depth 8 -compress none ppm:- 2>/dev/null
else
    "$tool" "$f[0]" -background white -alpha remove -alpha off \
        -resize 96x96 -colorspace sRGB -depth 8 -compress none ppm:- 2>/dev/null
fi
