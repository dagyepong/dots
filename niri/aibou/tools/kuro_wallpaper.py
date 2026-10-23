#!/usr/bin/env python3
"""Kuro as a wallpaper: a white ring (his outline) with his two long eyes on
black, blinking now and then and glancing aside; and the same inverted for
light mode. Renders a 12 s loop (30 fps) that repeats without a jump as MP4, and a still PNG.

    python3 tools/kuro_wallpaper.py [WIDTH HEIGHT]     (default 2560 1600)

Writes kuro-dunkel.png/.mp4 and kuro-hell.png/.mp4 into the current folder.
Put the PNGs into ~/Pictures/Wallpapers: Aibou recognises them, swaps them
with the light/dark mode and draws Kuro's eyes alive over them.

Eye shape and proportions as in shell/LongEyes.qml: eye 6 × 15 units,
centres ±9.5 units apart, face slightly above the middle, body 58 units."""
import math, subprocess, sys
from pathlib import Path
from PIL import Image, ImageDraw

W, H = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) > 2 else (2560, 1600)
FPS, SECS = 30, 12
OUT = Path.cwd()
SS = 2                                     # drawn at twice the size, then scaled down (smooth edges)

D = H * 0.30                               # the ring's diameter
k = D / 58
RING = max(4, round(H * 0.006))            # line width

# when he blinks (seconds into the loop) and how; a look aside between them
BLINKS = [1.6, 5.2, 5.45, 8.9]             # 5.2 + 5.45: a double blink
BLINK = 0.16                               # closing and opening, in seconds
LOOKS = [(6.6, 7.9, -1), (10.2, 11.2, 1)]  # from, to, which side


def lid(t):
    """1 open, 0 shut."""
    for b in BLINKS:
        d = t - b
        if 0 <= d < BLINK:
            return abs(1 - 2 * d / BLINK) ** 0.8
    return 1.0


def gaze(t):
    """-1 … 1, eased in and out over a quarter second."""
    for a, b, side in LOOKS:
        if a <= t <= b:
            e = min(t - a, b - t, 0.25) / 0.25
            return side * (0.5 - 0.5 * math.cos(math.pi * e))
    return 0.0


def frame(t, fg, bg, eyes=True):
    s = SS
    img = Image.new("RGB", (W * s, H * s), bg)
    g = ImageDraw.Draw(img)
    cx, cy = W * s / 2, H * s / 2
    r = D * s / 2
    g.ellipse((cx - r, cy - r, cx + r, cy + r), outline=fg, width=RING * s)
    if not eyes:
        return img.resize((W, H), Image.LANCZOS)
    gx = gaze(t) * 4 * k * s
    ew, eh = 6 * k * s, 15 * k * s * max(0.15, lid(t))
    ey = cy - D * s * 0.03
    for side in (-1, 1):
        ex = cx + side * 9.5 * k * s + gx
        g.rounded_rectangle((ex - ew / 2, ey - eh / 2, ex + ew / 2, ey + eh / 2), radius=ew / 2, fill=fg)
    return img.resize((W, H), Image.LANCZOS)


def render(name, fg, bg):
    # the wallpaper DMS shows is the ring alone: Mochi draws the eyes on it,
    # alive (shell.qml, kuroEyes); with eyes for when Mochi is not running
    frame(0, fg, bg, eyes=False).save(OUT / f"{name}.png")
    frame(0, fg, bg).save(OUT / f"{name}-augen.png")
    ff = subprocess.Popen(["ffmpeg", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
                           "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                           "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-tune", "animation",
                           "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(OUT / f"{name}.mp4")],
                          stdin=subprocess.PIPE)
    cache = {}
    for i in range(FPS * SECS):
        t = i / FPS
        key = (round(lid(t), 3), round(gaze(t), 3))
        if key not in cache:
            cache[key] = frame(t, fg, bg).tobytes()
        ff.stdin.write(cache[key])
    ff.stdin.close()
    ff.wait()
    print(name, "fertig,", len(cache), "verschiedene Bilder")


render("kuro-dunkel", (255, 255, 255), (0, 0, 0))
render("kuro-hell", (0, 0, 0), (255, 255, 255))
