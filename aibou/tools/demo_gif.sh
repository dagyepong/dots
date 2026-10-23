#!/usr/bin/env bash
# demo_gif.sh WALLPAPER [OUT]: the README animation. Renders shell/demo.qml
# (frames with a clear ground in shell/.demo), lays a 1200×340 band of the
# wallpaper under them at their real timing and writes a GIF (default
# docs/demo.gif) and a still for the plugin registry (docs/screenshot.png).
set -euo pipefail
repo="$(readlink -f "$(dirname "$0")/..")"
wall="$1"; out="${2:-$repo/docs/demo.gif}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
rm -rf "$repo/shell/.demo"; mkdir -p "$repo/shell/.demo"
qs -p "$repo/shell/demo.qml" >/dev/null 2>&1
# the band a little below the middle of the picture
magick "$wall" -resize 1200x -gravity center -crop 1200x340+0+60 +repage "$tmp/bg.png"
python3 - "$repo/shell/.demo" "$tmp/list.txt" <<'PY'
import os, re, sys
d, out = sys.argv[1], sys.argv[2]
fs = sorted(os.listdir(d))
ts = [int(re.search(r"-(\d+)\.png", f).group(1)) for f in fs]
with open(out, "w") as o:
    for i, f in enumerate(fs):
        dur = ((ts[i + 1] - ts[i]) if i + 1 < len(fs) else 40) / 1000
        o.write(f"file '{os.path.join(d, f)}'\nduration {dur:.3f}\n")
    o.write(f"file '{os.path.join(d, fs[-1])}'\n")
PY
ffmpeg -loglevel error -y -loop 1 -i "$tmp/bg.png" -f concat -safe 0 -i "$tmp/list.txt" -filter_complex \
  "[0][1]overlay=shortest=1,fps=20,scale=900:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle" "$out"
still="$(ls "$repo/shell/.demo" | awk -F- '{split($2, a, "."); if (a[1] > 7900) { print; exit }}')"
magick "$tmp/bg.png" "$repo/shell/.demo/$still" -composite "$repo/docs/screenshot.png"
echo "$out"
