#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   G R E E T I N G                                                        │
# │   animated fastfetch logo · four scenes in the active palette            │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""The greeting's animated scenes, drawn pixel by pixel in the palette.

Each scene is a list of 54 × 60 frames, scaled by a whole number (5, the
fastfetch logo box at the configured font) with ImageMagick into a looping
GIF, because kitty scales images with a linear filter that would blur pixel
art. fastfetch shows it through `kitten icat`, and kitty keeps playing it
after fastfetch exits.

theme_manager.py calls `push` on every palette change and `draw` renders the
scenes in the background. `choose` sets the scene `fa` opens with (or
random), `seed` covers a machine the shell has not painted yet, and
`greeting.py <scene> <out.gif>` draws one scene in a fixed palette.
"""

import json
import math
import os
import random
import shutil
import subprocess
import sys
import time

WIDTH = 54
HEIGHT = 60
SCALE = 5

WHITE = (255, 255, 255)
BLACK = (0, 0, 0)


def rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))


def mix(one, two, amount):
    """`one` taken `amount` of the way towards `two`."""
    return tuple(round(a + (b - a) * amount) for a, b in zip(one, two))


class Canvas:
    """One frame: a colour or None per pixel, None being see-through."""

    def __init__(self, pixels=None):
        self.pixels = list(pixels) if pixels else [None] * (WIDTH * HEIGHT)

    def copy(self):
        return Canvas(self.pixels)

    def put(self, x, y, colour):
        if colour is not None and 0 <= x < WIDTH and 0 <= y < HEIGHT:
            self.pixels[y * WIDTH + x] = colour

    def get(self, x, y):
        if 0 <= x < WIDTH and 0 <= y < HEIGHT:
            return self.pixels[y * WIDTH + x]
        return None

    def rect(self, x, y, width, height, colour):
        for row in range(y, y + height):
            for column in range(x, x + width):
                self.put(column, row, colour)

    def disc(self, cx, cy, radius, colour):
        """Every pixel whose centre is within `radius` of a point."""
        for y in range(math.floor(cy - radius), math.ceil(cy + radius) + 1):
            for x in range(math.floor(cx - radius), math.ceil(cx + radius) + 1):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= radius * radius:
                    self.put(x, y, colour)

    def sprite(self, x, y, rows, key, mirror=False):
        """A drawing in characters: `.` is see-through, anything else a key."""
        for dy, row in enumerate(rows):
            for dx, char in enumerate(row[::-1] if mirror else row):
                if char != ".":
                    self.put(x + dx, y + dy, key[char])

    def pam(self):
        header = (f"P7\nWIDTH {WIDTH}\nHEIGHT {HEIGHT}\nDEPTH 4\nMAXVAL 255\n"
                  "TUPLTYPE RGB_ALPHA\nENDHDR\n").encode()
        body = bytearray()
        for colour in self.pixels:
            body += bytes((*colour, 255)) if colour else b"\0\0\0\0"
        return header + bytes(body)


def ramp(points, y):
    """Piecewise-linear interpolation through (y, value) pairs."""
    for (y0, v0), (y1, v1) in zip(points, points[1:]):
        if y0 <= y <= y1:
            return v0 + (v1 - v0) * ((y - y0) / (y1 - y0) if y1 != y0 else 0)
    return None


# ── LAVA LAMP ───────────────────────────────────────────────────────────────
# · the silhouette, as a half-width per row around x = 27
LAMP_X = 27
LAMP_CAP = [(2, 3.5), (8, 6.5)]
LAMP_GLASS = [(9, 6.0), (19, 8.6), (31, 11.4), (36, 11.2), (40, 9.0)]
LAMP_COLLAR = (41, 42, 9.5)
LAMP_BASE = [(43, 8.5), (57, 15.0)]

# · where the wax turns round, and the blobs themselves: paint, radius, where
#   in its cycle it starts, cycles per loop, how far it wanders sideways
LAVA_TOP = 14.0
LAVA_BOTTOM = 37.5
LAVA_BLOBS = (("accent", 3.9, 0.00, 1, 0.55, 0.10),
              ("green", 3.1, 0.20, 1, 0.75, 0.55),
              ("yellow", 3.5, 0.40, 1, 0.65, 0.30),
              ("red", 4.2, 0.60, 1, 0.55, 0.80),
              ("blue", 2.9, 0.80, 1, 0.75, 0.45))
LAVA_REACH = 1.45
# · the kernel's value one radius out, so a blob on its own is its radius
LAVA_THRESHOLD = (1 - 1 / LAVA_REACH ** 2) ** 2
LAVA_FRAMES = 90
LAVA_DELAY = 8


def metal_tone(u):
    """A cylinder lit from the left, in five bands rather than a gradient."""
    if u < -0.78:
        return "mid"
    if u < -0.52:
        return "light"
    if u < -0.36:
        return "shine"
    if u < 0.38:
        return "mid"
    if u < 0.76:
        return "dark"
    return "edge"


def lava(paint):
    ground, muted, accent = paint["ground"], paint["muted"], paint["accent"]
    metal = {"shine": mix(muted, WHITE, 0.5), "light": muted,
             "mid": mix(muted, ground, 0.42), "dark": mix(muted, ground, 0.66),
             "edge": mix(muted, ground, 0.8)}

    still = Canvas()
    for y in range(HEIGHT):
        half = (ramp(LAMP_CAP, y) or ramp(LAMP_BASE, y)
                or (LAMP_COLLAR[2] if LAMP_COLLAR[0] <= y <= LAMP_COLLAR[1] else None))
        if half is None:
            continue
        for x in range(WIDTH):
            u = (x + 0.5 - LAMP_X) / half
            if abs(u) <= 1:
                still.put(x, y, metal[metal_tone(u)])
    # · a lip on the collar and the base's rim, darker, so the parts read apart
    for y, half in ((LAMP_COLLAR[1], LAMP_COLLAR[2]), (58, 15.5)):
        for x in range(WIDTH):
            if abs(x + 0.5 - LAMP_X) <= half:
                still.put(x, y, metal["edge"] if y == 58 else metal["dark"])
    for x in range(WIDTH):
        if abs(x + 0.5 - LAMP_X) <= 17:
            still.put(x, 59, mix(ground, BLACK, 0.45))

    glass = {}
    for y in range(LAMP_GLASS[0][0], LAMP_GLASS[-1][0] + 1):
        half = ramp(LAMP_GLASS, y)
        for x in range(WIDTH):
            u = (x + 0.5 - LAMP_X) / half
            if abs(u) <= 1:
                glass[(x, y)] = u

    def liquid(y, u):
        # · the bulb is in the base, so the bottom of the column is lit
        tone = mix(ground, accent, 0.26 if y < 33 else 0.34 if y < 38 else 0.44)
        if u > 0.72:
            tone = mix(tone, ground, 0.45)
        elif u < -0.86:
            tone = mix(tone, WHITE, 0.1)
        return tone

    frames = []
    for index in range(LAVA_FRAMES):
        t = index / LAVA_FRAMES
        blobs = []
        for key, radius, phase, cycles, sway, sway_phase in LAVA_BLOBS:
            angle = 2 * math.pi * (cycles * t + phase)
            y = LAVA_BOTTOM - (LAVA_BOTTOM - LAVA_TOP) * (1 - math.cos(angle)) / 2
            speed = abs(math.sin(angle))
            room = max(0.0, ramp(LAMP_GLASS, min(max(y, 9), 40)) - radius - 1)
            x = LAMP_X + sway * room * math.sin(2 * math.pi * (t + sway_phase))
            blobs.append((paint[key], radius, x, y,
                          1 / (1 + 0.14 * speed), 1 + 0.32 * speed))

        # · a kernel that reaches nothing past LAVA_REACH radii, so five blobs
        #   in a narrow glass stay five blobs until two of them touch
        def field(x, y):
            px, py = x + 0.5, y + 0.5
            best, colour, total, nearest = 0.0, None, 0.0, None
            for paint_colour, radius, bx, by, sx, sy in blobs:
                dx, dy = (px - bx) / sx, (py - by) / sy
                reach = dx * dx + dy * dy
                share = max(0.0, 1 - reach / (radius * LAVA_REACH) ** 2) ** 2
                total += share
                if share > best:
                    best, colour = share, paint_colour
                if nearest is None or reach < nearest[0]:
                    nearest = (reach, paint_colour)
            # · the pool of wax the bulb keeps melted, which has no colour of
            #   its own and takes the nearest blob's
            dx, dy = (px - LAMP_X) / 8.0, (py - 41.5) / 2.6
            total += max(0.0, 1 - (dx * dx + dy * dy) / LAVA_REACH ** 2) ** 2
            return total, colour or nearest[1]

        inside = {}
        for (x, y) in glass:
            total, colour = field(x, y)
            inside[(x, y)] = colour if total >= LAVA_THRESHOLD else None

        frame = still.copy()
        for (x, y), u in glass.items():
            colour = inside[(x, y)]
            if colour is None:
                pixel = liquid(y, u)
            elif not inside.get((x - 1, y - 1)) or not inside.get((x, y - 1)):
                pixel = mix(colour, WHITE, 0.38)
            elif not inside.get((x + 1, y + 1)) or not inside.get((x + 1, y)):
                pixel = mix(colour, BLACK, 0.3)
            else:
                pixel = colour
            # · the glass is in front of all of it, and so is its highlight
            if -0.66 <= u <= -0.48 and 11 <= y <= 33 and y not in (26, 27):
                pixel = mix(pixel, WHITE, 0.32)
            frame.put(x, y, pixel)
        frames.append(frame)
    return frames, LAVA_DELAY


# ── CRITTERS ────────────────────────────────────────────────────────────────
# · o outline · b body · l light · d shade · e ink · w glint · n pink · k beak
CAT = [".o...........o.",
       ".oo.........oo.",
       ".ono.......ono.",
       ".onbo.....obno.",
       "olbbbooooobbbbo",
       "olllbbbbbbbbbbo",
       "olbbewbbbewbbbo",
       "obbbeebbbeebbdo",
       "obnbbbbnbbbbndo",
       ".obbbbbbbbbbdo.",
       ".oooobbbbbdooo.",
       "...olbbbbbbdo..",
       "..olbbbbbbbbdo.",
       "..obbbbbbbbbdo.",
       "..obbbobobbbdo.",
       "...ooooooooooo."]
CAT_BLINK = {6: "olbbbbbbbbbbbbo", 7: "obbbeebbbeebbdo"}
CAT_TAIL = (["..oo", ".obo", ".obo", "obo.", "obo.", "bo..", "o..."],
            ["....", "....", "....", "..oo", ".obo", "bbo.", "oo.."])

CRAB = [".oo..........oo.",
        "obbo........obbo",
        "o.bo........ob.o",
        "obbo..o...o.obbo",
        ".obo.oeo.oeoobo.",
        "..ob..o...o.bo..",
        "..oobbbbbbbboo..",
        ".obllbbbbbbbbdo.",
        "obbbbbbbbbbbbbdo",
        "o.obbbbbbbbbbdo.o",
        ".o.oooooooooooo.o",
        "o.o..........o.o"]
CRAB_SNAP = {0: ".oo..........oo.", 1: "obbo........obbo", 2: "obbo........obbo"}

# · the sky behind them: where a star is, and when in the loop it flares
STARS = ((5, 7, 0), (46, 5, 9), (10, 26, 20), (50, 24, 31), (38, 31, 14), (2, 40, 38),
         (27, 3, 26))

GHOST = ["....oooooo....",
         "..oobbbbbboo..",
         ".obllbbbbbbbo.",
         ".oblbbbbbbbbo.",
         "obbwwebbbwwebo",
         "obbwwebbbwwebo",
         "obbbbbbbbbbbbo",
         "obbbbbbbbbbbbo",
         "obbbbbbbbbbbbo",
         "obbbbbbbbbbbdo",
         "obbbbbbbbbbbdo"]
GHOST_HEM = (["obbobbbobbbobo", "oo.oo.ooo.oo.o"],
             ["obobbbobbbobbo", "o.oo.ooo.oo.oo"])

CHICK = ["...oooo....",
         "..olllbo...",
         ".olbbbbbo..",
         ".obbbbebo..",
         "obbbbbebkko",
         "obbbbnbbko.",
         "obbbbbbbbo.",
         ".obbbbbdo..",
         "..oooooo..."]
CHICK_WING = (["obo", "obo", ".o."], ["o..", "obo", "obo"])

CRITTER_FRAMES = 48
CRITTER_DELAY = 10


def critter_key(paint, key):
    body = paint[key]
    return {"o": mix(body, BLACK, 0.62), "b": body, "l": mix(body, WHITE, 0.4),
            "d": mix(body, BLACK, 0.22), "e": mix(paint["ground"], BLACK, 0.6),
            "w": WHITE, "n": mix(paint["red"], WHITE, 0.35),
            "k": mix(paint["yellow"], paint["red"], 0.5)}


def slime(canvas, paint, left, base, squash):
    """A dome, wider and lower the harder it lands."""
    key = critter_key(paint, "green")
    width, height = 14 * (1 + 0.18 * squash), 11 * (1 - 0.22 * squash)
    cx = left + 7.5
    top = base - height
    for y in range(math.floor(top) - 1, base + 1):
        for x in range(math.floor(cx - width / 2) - 1, math.ceil(cx + width / 2) + 1):
            dx = (x + 0.5 - cx) / (width / 2)
            dy = (y + 0.5 - base) / height
            inside = dx * dx + dy * dy <= 1 and y < base
            if not inside:
                continue
            ring = (((x - 0.5 - cx) / (width / 2)) ** 2 + dy * dy > 1
                    or ((x + 1.5 - cx) / (width / 2)) ** 2 + dy * dy > 1
                    or dx * dx + ((y - 0.5 - base) / height) ** 2 > 1
                    or y == base - 1)
            if ring:
                colour = key["o"]
            elif dx < -0.3 and dy < -0.55:
                colour = key["l"]
            elif dx > 0.55:
                colour = key["d"]
            else:
                colour = key["b"]
            canvas.put(x, y, colour)
    eyes = round(base - height * 0.5)
    for ex in (round(cx - 3), round(cx + 2)):
        canvas.put(ex, eyes, key["e"])
        canvas.put(ex, eyes + 1, key["e"])
        canvas.put(ex, eyes, key["w"])
    canvas.put(round(cx - 5), eyes + 2, key["n"])
    canvas.put(round(cx + 4), eyes + 2, key["n"])


def shadow(canvas, paint, cx, y, half):
    for x in range(math.floor(cx - half), math.ceil(cx + half)):
        canvas.put(x, y, mix(paint["ground"], BLACK, 0.45))


def critters(paint):
    frames = []
    for index in range(CRITTER_FRAMES):
        canvas = Canvas()

        for sx, sy, when in STARS:
            age = (index - when) % CRITTER_FRAMES
            dim = mix(paint["muted"], paint["ground"], 0.55)
            if age < 3:
                for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                    canvas.put(sx + dx, sy + dy, dim)
            canvas.put(sx, sy, paint["text"] if age < 6 else dim)

        # · the slime in the middle, bouncing four times a loop
        beat = index % 12
        hop = [0, 0, 2, 4, 6, 7, 7, 6, 4, 2, 0, 0][beat]
        squash = {0: 1.0, 1: 0.5, 10: 0.4, 11: 1.0}.get(beat, -0.25 if hop else 0)
        shadow(canvas, paint, 26.5, 57, 6 - hop * 0.4)
        slime(canvas, paint, 19, 57 - hop, squash)

        # · the crab on the left, sidestepping and snapping
        step = [0, 0, 1, 1, 2, 2, 1, 1][(index // 3) % 8]
        crab = list(CRAB)
        if (index // 4) % 6 in (1, 3):
            for row, line in CRAB_SNAP.items():
                crab[row] = line
        key = critter_key(paint, "red")
        shadow(canvas, paint, 8 + step, 57, 7)
        canvas.sprite(step, 45, crab, key)

        # · the cat on the right, blinking and swishing, away from the crab:
        #   in some palettes the accent is the red
        key = critter_key(paint, "accent")
        cat = list(CAT)
        if index % 24 in (15, 16) or index == 40:
            for row, line in CAT_BLINK.items():
                cat[row] = line
        shadow(canvas, paint, 44.5, 57, 7)
        canvas.sprite(37, 41, cat, key)
        canvas.sprite(49, 49, CAT_TAIL[(index // 6) % 2], key)

        # · the chick on the cat's head, flapping now and then
        key = critter_key(paint, "yellow")
        hopping = 26 <= index <= 31
        lift = [0, 1, 2, 2, 1, 0][index - 26] if hopping else 0
        canvas.sprite(39, 37 - lift, CHICK, key)
        flap = hopping or index % 16 in (5, 6)
        canvas.sprite(40, 42 - lift, CHICK_WING[1 if flap and index % 2 else 0], key)

        # · the ghost, drifting across the top
        key = critter_key(paint, "blue")
        t = index / CRITTER_FRAMES
        gx = round(20 + 16 * math.sin(2 * math.pi * t))
        gy = round(9 + 3 * math.sin(4 * math.pi * t))
        body = list(GHOST)
        look = -1 if math.cos(2 * math.pi * t) < 0 else 1
        for row in (4, 5):
            line = body[row]
            body[row] = (line.replace("wwe", "eww") if look < 0 else line)
        canvas.sprite(gx, gy, body + GHOST_HEM[(index // 4) % 2], key)

        frames.append(canvas)
    return frames, CRITTER_DELAY


# ── KOI ─────────────────────────────────────────────────────────────────────
POND_X, POND_Y = 27.0, 30.0
POND_RX, POND_RY = 23.2, 26.2
POND_RIM = 1.15
KOI_FRAMES = 80
KOI_DELAY = 8
KOI_RADII = (1.5, 2.1, 2.5, 2.6, 2.5, 2.3, 2.0, 1.7, 1.4, 1.1, 0.9)


def pond_path(kind):
    """A closed curve as points, and the running length along it."""
    points = []
    for step in range(480):
        a = 2 * math.pi * step / 480
        if kind == 0:
            points.append((POND_X + 15 * math.cos(a), POND_Y + 17 * math.sin(a)))
        elif kind == 1:
            points.append((POND_X + 3 + 9 * math.cos(-a), POND_Y - 4 + 11 * math.sin(-a)))
        else:
            points.append((POND_X + 14 * math.sin(a), POND_Y + 19 * math.sin(a) * math.cos(a)
                           + 2))
    lengths = [0.0]
    for (x0, y0), (x1, y1) in zip(points, points[1:] + points[:1]):
        lengths.append(lengths[-1] + math.hypot(x1 - x0, y1 - y0))
    return points, lengths


def along(path, distance):
    points, lengths = path
    total = lengths[-1]
    distance %= total
    low, high = 0, len(points)
    while high - low > 1:
        middle = (low + high) // 2
        if lengths[middle] <= distance:
            low = middle
        else:
            high = middle
    x0, y0 = points[low]
    x1, y1 = points[(low + 1) % len(points)]
    span = lengths[low + 1] - lengths[low] or 1
    share = (distance - lengths[low]) / span
    return x0 + (x1 - x0) * share, y0 + (y1 - y0) * share


def koi(paint):
    # · the water is the palette's blue, not its accent, which can be any
    #   colour the wallpaper gives it
    ground, accent, blue = paint["ground"], paint["accent"], paint["blue"]
    deep, middle, shallow = (mix(ground, blue, 0.24), mix(ground, blue, 0.32),
                             mix(ground, blue, 0.40))
    stone_tones = (paint["muted"], mix(paint["muted"], ground, 0.3),
                   mix(paint["muted"], ground, 0.5))

    # · the rim: stones where the water stops, cut as cells around fixed seeds
    seeds = []
    count = 24
    for n in range(count):
        a = 2 * math.pi * (n + 0.3 * math.sin(n * 2.7)) / count
        seeds.append((POND_X + POND_RX * 1.08 * math.cos(a),
                      POND_Y + POND_RY * 1.08 * math.sin(a), stone_tones[(n * 7) % 3]))

    still = Canvas()
    water = {}
    for y in range(HEIGHT):
        for x in range(WIDTH):
            dx = (x + 0.5 - POND_X) / POND_RX
            dy = (y + 0.5 - POND_Y) / POND_RY
            e = math.sqrt(dx * dx + dy * dy)
            if e <= 1:
                tone = deep if e < 0.55 else middle if e < 0.84 else shallow
                # · a dither where one band meets the next, pixel art's gradient
                if 0.52 <= e < 0.58 or 0.81 <= e < 0.87:
                    tone = (middle if e < 0.7 else shallow) if (x + y) % 2 else tone
                water[(x, y)] = tone
                still.put(x, y, tone)
            elif e <= POND_RIM:
                ranked = sorted(((x + 0.5 - sx) ** 2 + (y + 0.5 - sy) ** 2, tone, sx, sy)
                                for sx, sy, tone in seeds)
                (near, tone, sx, sy), (second, *_) = ranked[0], ranked[1]
                if math.sqrt(second) - math.sqrt(near) < 0.9 or e > POND_RIM - 0.03:
                    still.put(x, y, mix(tone, ground, 0.7))
                elif x + 0.5 < sx and y + 0.5 < sy:
                    still.put(x, y, mix(tone, WHITE, 0.2))
                else:
                    still.put(x, y, tone)

    pads = ((13.5, 15.5, 5.6, 0.6), (40.5, 45.0, 4.8, 2.4), (41.0, 15.0, 3.8, 4.0))
    fish = ((pond_path(0), 1, 0.00, paint["text"], paint["red"], {1, 2, 3, 7, 8}),
            (pond_path(1), 1, 0.35, paint["yellow"], mix(paint["yellow"], WHITE, 0.5),
             {0, 1}),
            (pond_path(2), 1, 0.60, paint["text"], accent, {2, 3, 6, 7, 8}))
    ripples = ((12, 30.0, 26.0), (44, 18.0, 38.0), (66, 36.0, 14.0))
    glints = ((20, 36, 0), (33, 23, 20), (24, 48, 40), (37, 34, 60))

    frames = []
    for index in range(KOI_FRAMES):
        t = index / KOI_FRAMES
        frame = still.copy()

        bodies = []
        for path, laps, offset, body, patch, patches in fish:
            head = (t * laps + offset) * path[1][-1]
            spine = []
            for j in range(len(KOI_RADII)):
                x, y = along(path, head - j * 1.05)
                spine.append((x, y))
            wiggled = []
            for j, (x, y) in enumerate(spine):
                ahead = spine[max(0, j - 1)]
                behind = spine[min(len(spine) - 1, j + 1)]
                tx, ty = ahead[0] - behind[0], ahead[1] - behind[1]
                norm = math.hypot(tx, ty) or 1
                nx, ny = -ty / norm, tx / norm
                sway = 0.8 * math.sin(2 * math.pi * 10 * t - j * 0.6) * j / len(spine)
                wiggled.append((x + nx * sway, y + ny * sway, nx, ny, tx / norm, ty / norm))
            bodies.append((wiggled, body, patch, patches))

        # · the shadow on the bottom first, then the fish, then what floats
        for wiggled, *_ in bodies:
            shade = Canvas()
            for j, (x, y, *_) in enumerate(wiggled):
                shade.disc(x + 1.4, y + 2.0, KOI_RADII[j], BLACK)
            for position, colour in enumerate(shade.pixels):
                xy = (position % WIDTH, position // WIDTH)
                if colour and xy in water:
                    frame.put(*xy, mix(frame.get(*xy), BLACK, 0.3))

        for wiggled, body, patch, patches in bodies:
            fin = mix(body, middle, 0.3)
            x, y, nx, ny, tx, ty = wiggled[3]
            for side in (1, -1):
                frame.disc(x + nx * side * 2.3 - tx * 0.6, y + ny * side * 2.3 - ty * 0.6,
                           1.0, fin)
            # · the tail, two lobes close to the body rather than a stick
            x, y, nx, ny, tx, ty = wiggled[-1]
            for side in (1, -1):
                frame.disc(x - tx * 1.1 + nx * side * 1.0, y - ty * 1.1 + ny * side * 1.0,
                           1.1, fin)
            for j in range(len(wiggled) - 1, -1, -1):
                x, y, *_ = wiggled[j]
                frame.disc(x, y, KOI_RADII[j], patch if j in patches else body)

        for start, rx, ry in ripples:
            age = (index - start) % KOI_FRAMES
            if age >= 10:
                continue
            radius = 0.8 + age * 0.38
            colour = mix(shallow, WHITE, 0.28 if age < 5 else 0.12)
            for y in range(int(ry - radius - 2), int(ry + radius + 3)):
                for x in range(int(rx - radius - 2), int(rx + radius + 3)):
                    if (abs(math.hypot(x + 0.5 - rx, y + 0.5 - ry) - radius) < 0.5
                            and (x, y) in water):
                        frame.put(x, y, colour)

        for gx, gy, when in glints:
            if (index - when) % KOI_FRAMES < 6:
                frame.put(gx, gy, mix(shallow, WHITE, 0.6))

        green = paint["green"]
        for px, py, radius, notch in pads:
            for y in range(int(py - radius - 1), int(py + radius + 2)):
                for x in range(int(px - radius - 1), int(px + radius + 2)):
                    dx, dy = x + 0.5 - px, y + 0.5 - py
                    distance = math.hypot(dx, dy)
                    angle = (math.atan2(dy, dx) - notch + math.pi) % (2 * math.pi) - math.pi
                    if distance > radius or (abs(angle) < 0.35 and distance > 0.8):
                        continue
                    if distance > radius - 1:
                        colour = mix(green, BLACK, 0.4)
                    elif dx + dy < -radius * 0.5:
                        colour = mix(green, WHITE, 0.25)
                    else:
                        colour = green
                    frame.put(x, y, colour)
        petal = mix(paint["red"], WHITE, 0.35)
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1), (-1, -1), (1, -1)):
            frame.put(41 + dx, 14 + dy, petal)
        frame.put(41, 14, paint["yellow"])

        frames.append(frame)
    return frames, KOI_DELAY


# ── INVADERS ────────────────────────────────────────────────────────────────
SQUID = (["...##...", "..####..", ".######.", "##.##.##",
          "########", "..#..#..", ".#.##.#.", "#.#..#.#"],
         ["...##...", "..####..", ".######.", "##.##.##",
          "########", ".#.##.#.", "#......#", ".#....#."])
CRAB_INVADER = (["..#.....#..", "...#...#...", "..#######..", ".##.###.##.",
                 "###########", "#.#######.#", "#.#.....#.#", "...##.##..."],
                ["..#.....#..", "#..#...#..#", "#.#######.#", "###.###.###",
                 "###########", ".#########.", "..#.....#..", ".#.......#."])
OCTOPUS = (["....####....", ".##########.", "############", "###..##..###",
            "############", "...##..##...", "..##.##.##..", "##........##"],
           ["....####....", ".##########.", "############", "###..##..###",
            "############", "..###..###..", ".##..##..##.", "..##....##.."])
SAUCER = ["......####......", "...##########...", "..############..",
          ".##.##.##.##.##.", "################", "..###..##..###..", "...#........#..."]
CANNON = ["......#......", ".....###.....", ".....###.....", ".###########.",
          "#############", "#############", "#############"]
BURST = ["....#...#....", ".#...#.#...#.", "..#.......#..", "...#.....#...",
         "##.........##", "...#.....#...", "..#.#...#.#..", ".#..#...#..#."]

INVADER_ROWS = (("accent", SQUID, 10), ("green", CRAB_INVADER, 19),
                ("yellow", CRAB_INVADER, 28), ("blue", OCTOPUS, 37))
INVADER_FRAMES = 80
INVADER_DELAY = 8
# · the one that is shot: its column, the frame the shot leaves, the frame it
#   comes back
INVADER_TARGET = (1, 30, 64)


def march(index):
    """How far right the formation is: one pixel every other frame, and back."""
    step = (index // 2) % 20
    return step if step <= 10 else 20 - step


def cannon_track():
    """Where the cannon is on each frame, walking a pixel a frame to where it
    wants to be — patrolling, or under its target for the shot. Walked over
    two loops and the second one kept, so the loop closes on itself."""
    column, fired, _ = INVADER_TARGET
    x, track = 21, []
    for frame in range(2 * INVADER_FRAMES):
        index = frame % INVADER_FRAMES
        if fired - 14 <= index <= fired + 6:
            want = march(index) + column * 16
        else:
            want = round(20 + 13 * math.sin(2 * math.pi * index / INVADER_FRAMES * 2))
        x += (want > x) - (want < x)
        if frame >= INVADER_FRAMES:
            track.append(x)
    return track


def invaders(paint):
    ink = paint["text"]
    track = cannon_track()
    frames = []
    for index in range(INVADER_FRAMES):
        canvas = Canvas()
        offset = march(index)
        pose = (index // 2) % 2

        column, fired, back = INVADER_TARGET
        shot = index - fired
        hit_at = 4
        for row, (key, pair, y) in enumerate(INVADER_ROWS):
            for c in range(3):
                shape = pair[pose]
                x = offset + c * 16 + (12 - len(shape[0])) // 2
                if row == 3 and c == column:
                    if hit_at <= shot < hit_at + 3:
                        canvas.sprite(offset + c * 16, y, BURST, {"#": ink})
                        continue
                    if hit_at + 3 <= shot and index < back:
                        continue
                    if back <= index < back + 6 and index % 2:
                        continue
                canvas.sprite(x, y, shape, {"#": paint[key]})

        # · the cannon patrols, walks under its target, fires, and goes back
        canvas.sprite(track[index], 53, CANNON, {"#": paint["green"]})
        if 0 <= shot < hit_at:
            canvas.rect(track[fired] + 6, 51 - shot * 2, 1, 3, ink)

        # · a bomb from the octopus row now and then
        for dropped, c in ((8, 0), (48, 2)):
            age = index - dropped
            if 0 <= age < 7:
                bx = offset + c * 16 + 6
                by = 46 + age * 2
                for k in range(3):
                    canvas.put(bx + (1 if (k + age) % 2 else 0), by + k, paint["red"])

        # · the saucer, once a loop, across the top
        sx = -16 + index
        if sx < WIDTH:
            canvas.sprite(sx, 1, SAUCER, {"#": paint["red"]})

        canvas.rect(0, 59, WIDTH, 1, mix(paint["green"], paint["ground"], 0.5))
        frames.append(canvas)
    return frames, INVADER_DELAY


SCENES = {"lava": lava, "critters": critters, "koi": koi, "invaders": invaders}

# · what the settings window can choose: a scene, or a new one every greeting
CHOICES = (*SCENES, "random")

STATE_DIR = os.path.join(os.environ.get("XDG_STATE_HOME")
                         or os.path.expanduser("~/.local/state"), "quickshell")
# · the paint the scenes are drawn in, the choice, the one fastfetch's config
#   names, the moment the last full set landed, and what the drawing said
PAINT_FILE = os.path.join(STATE_DIR, "greeting-paint.json")
CHOICE_FILE = os.path.join(STATE_DIR, "greeting")
LINK = os.path.join(STATE_DIR, "greeting.gif")
STAMP_FILE = os.path.join(STATE_DIR, "greeting.stamp")
LOG_FILE = os.path.join(STATE_DIR, "greeting.log")


def scene_file(scene):
    return os.path.join(STATE_DIR, f"greeting-{scene}.gif")


def read_paint():
    try:
        with open(PAINT_FILE, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


def replace_text(path, text):
    staging = f"{path}.{os.getpid()}.part"
    with open(staging, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.replace(staging, path)


def write(scene, paint, path, magick, current=lambda: True):
    """Draw a scene and write it as a looping GIF, through a staging file.

    `paint` holds the five paints, `ground`, `text` and `muted`, as hex.
    `current` is asked once more before the swap, so a drawing a newer push
    has overtaken is thrown away instead of landing on top of it. Returns
    whether it was written; a failure is a line on stderr.
    """
    colours = {key: rgb(value) for key, value in paint.items()}
    frames, delay = SCENES[scene](colours)
    stream = b"".join(frame.pam() for frame in frames)
    # · not `.gif`, so `fa`'s glob never deals a scene that is half written
    staging = f"{path}.{os.getpid()}.part"
    # · every frame whole, and no `-layers Optimize`: that crops each frame to
    #   what changed, icat takes the first frame's crop for the size of the
    #   image, and kitty draws the whole loop too big and in the wrong places
    command = [magick, "-delay", str(delay), "-dispose", "Background", "pam:-",
               "-scale", f"{SCALE * 100}%", "+dither", "-loop", "0", f"gif:{staging}"]
    try:
        subprocess.run(command, input=stream, capture_output=True, timeout=60, check=True)
        if not current():
            os.remove(staging)
            return False
        os.replace(staging, path)
        return True
    except (OSError, subprocess.SubprocessError) as error:
        sys.stderr.write(f"Cannot render the {scene} greeting: {error}\n")
        return False


def push(paint):
    """Save the palette and draw the scenes in a detached process.

    Drawing takes about five seconds, and the shell drops a palette push while
    the previous one is still running, so this returns at once. The drawing
    stops if a newer push has written different paint.
    """
    os.makedirs(STATE_DIR, exist_ok=True)
    replace_text(PAINT_FILE, json.dumps(paint))
    try:
        with open(LOG_FILE, "w", encoding="utf-8") as log:
            subprocess.Popen([sys.executable, os.path.abspath(__file__), "draw"],
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=log, start_new_session=True)
    except OSError as error:
        sys.stderr.write(f"Cannot start drawing the greetings: {error}\n")


def draw():
    """Every scene in the paint on file, then the stamp the settings watch."""
    magick = shutil.which("magick") or shutil.which("convert")
    if not magick:
        sys.stderr.write("ImageMagick not found, no greetings drawn\n")
        return False
    paint = read_paint()
    if not paint:
        sys.stderr.write(f"No paint to draw the greetings in: {PAINT_FILE}\n")
        return False
    for scene in SCENES:
        if not write(scene, paint, scene_file(scene), magick,
                     current=lambda: read_paint() == paint):
            return False
    replace_text(STAMP_FILE, f"{time.time():.3f}\n")
    if not os.path.lexists(LINK):
        choose(read_choice())
    return True


def read_choice():
    try:
        with open(CHOICE_FILE, encoding="utf-8") as handle:
            choice = handle.read().strip()
        return choice if choice in CHOICES else "random"
    except OSError:
        return "random"


def choose(choice):
    """Keep the choice for `fa`, and point the link fastfetch reads at it.

    `random` is `fa`'s to deal, a new scene every time it greets; the link is
    for fastfetch run by its own name, which cannot deal anything, and gets
    one scene drawn now.
    """
    if choice not in CHOICES:
        sys.stderr.write(f"Unknown greeting: {choice}\n")
        return False
    os.makedirs(STATE_DIR, exist_ok=True)
    replace_text(CHOICE_FILE, choice + "\n")
    scene = random.choice(tuple(SCENES)) if choice == "random" else choice
    staging = f"{LINK}.{os.getpid()}.part"
    os.symlink(os.path.basename(scene_file(scene)), staging)
    os.replace(staging, LINK)
    return True


def seed():
    """What a machine gets before the shell has ever pushed a palette.

    The scenes in a fixed palette, and random, each only if missing — a push
    or a choice made in the settings always wins over this.
    """
    if not all(os.path.isfile(scene_file(scene)) for scene in SCENES):
        os.makedirs(STATE_DIR, exist_ok=True)
        if read_paint() is None:
            replace_text(PAINT_FILE, json.dumps(SAMPLE_PAINT))
        if not draw():
            return False
    if not os.path.isfile(CHOICE_FILE):
        choose("random")
    return True


# · Catppuccin Mocha's, lifted, for a machine the shell has not painted yet and
#   for drawing a scene by hand
SAMPLE_PAINT = {"accent": "#597cce", "green": "#a6e3a1", "yellow": "#f9e2af",
                "red": "#f38ba8", "blue": "#89b4fa", "ground": "#0a1122",
                "text": "#eef2f7", "muted": "#94a1b2"}


USAGE = ("greeting.py draw | choose <" + "|".join(CHOICES) + "> | seed"
         " | <" + "|".join(SCENES) + "> <out.gif>")


if __name__ == "__main__":
    verb = sys.argv[1] if len(sys.argv) > 1 else ""
    if verb == "draw" and len(sys.argv) == 2:
        sys.exit(0 if draw() else 1)
    elif verb == "choose" and len(sys.argv) == 3:
        sys.exit(0 if choose(sys.argv[2]) else 1)
    elif verb == "seed" and len(sys.argv) == 2:
        sys.exit(0 if seed() else 1)
    elif verb in SCENES and len(sys.argv) == 3:
        magick = shutil.which("magick") or shutil.which("convert")
        if not magick:
            sys.stderr.write("ImageMagick not found\n")
            sys.exit(1)
        sys.exit(0 if write(verb, SAMPLE_PAINT, sys.argv[2], magick) else 1)
    sys.stderr.write(f"Usage: {USAGE}\n")
    sys.exit(1)
