#!/usr/bin/env python3
"""Turn a Windows cursor pack (.cur / .ani, a folder, or a .zip) into an Xcursor theme.

    win-cursor.py PACK [-n NAME] [--sizes 24,32,48,64] [--dest DIR] [--map Role=file ...]
                       [--dry-run] [--force]

PACK is a .zip, a folder, or a single .cur / .ani / .inf file. The theme is written to
~/.local/share/icons/NAME (that is where Settings -> Desktop -> Icons & cursor looks, so it
shows up there by itself). The last line printed is the theme name; everything else goes to
stderr.

No packages needed (Python 3 standard library only).

How a file becomes a cursor
  1. If the pack has an install.inf (the Windows "Install" button reads it), the roles come
     from it: Arrow, Help, AppStarting, Wait, ... exactly as the pack's author set them.
  2. Otherwise the file names are read ("Normal Select", "Busy", "Link", "aero_ns", ...).
  3. --map Role=file fixes or overrides any of them.
  A role the pack does not have falls back to a close one (Arrow in the end).

Animated cursors keep their frames, their order and their timing. Every cursor is written at
each size in --sizes, so the cursor size stepper in Settings works.
"""

import argparse
import os
import re
import shutil
import struct
import sys
import tempfile
import zipfile
import zlib

# ---------------------------------------------------------------------------------------
# Windows roles -> Xcursor names
# ---------------------------------------------------------------------------------------

# The order of the scheme string in a Windows .inf / registry scheme.
SCHEME_ORDER = ["Arrow", "Help", "AppStarting", "Wait", "Crosshair", "IBeam", "NWPen", "No",
                "SizeNS", "SizeWE", "SizeNWSE", "SizeNESW", "SizeAll", "UpArrow", "Hand",
                "Person", "Pin"]

# The first name is the real file, the rest are symlinks to it.
XNAMES = {
    "Arrow": ["left_ptr", "default", "arrow", "top_left_arrow", "right_ptr", "context-menu",
              "copy", "dnd-copy", "dnd-move", "dnd-none", "zoom-in", "zoom-out", "X_cursor",
              "color-picker", "draft_large", "draft_small"],
    "Help": ["help", "question_arrow", "whats_this", "left_ptr_help",
             "5c6cd98b3f3ebcb1f9c7f1c204630408", "d9ce0ab605698f320427677b458ad60b"],
    "AppStarting": ["left_ptr_watch", "progress", "half-busy",
                    "08e8e1c95fe2fc01f976f1e063a24ccd", "3ecb610c1bf2410f44200f48c40d3599"],
    "Wait": ["wait", "watch", "clock"],
    "Crosshair": ["crosshair", "cross", "tcross", "cross_reverse", "diamond_cross", "cell",
                  "plus"],
    "IBeam": ["text", "xterm", "ibeam", "vertical-text"],
    "NWPen": ["pencil"],
    "No": ["not-allowed", "crossed_circle", "forbidden", "no-drop", "dnd-no-drop", "circle",
           "03b6e0fcb3499374a867c041f52298f0"],
    "SizeNS": ["ns-resize", "size_ver", "sb_v_double_arrow", "v_double_arrow", "row-resize",
               "split_v", "n-resize", "s-resize", "top_side", "bottom_side", "double_arrow",
               "00008160000006810000408080010102", "2870a09082c103050810ffdffffe0204"],
    "SizeWE": ["ew-resize", "size_hor", "sb_h_double_arrow", "h_double_arrow", "col-resize",
               "split_h", "e-resize", "w-resize", "left_side", "right_side",
               "028006030e0e7ebffc7f7070c0600140", "14fef782d02440884392942c11205230"],
    "SizeNWSE": ["nwse-resize", "size_fdiag", "bd_double_arrow", "nw-resize", "se-resize",
                 "top_left_corner", "bottom_right_corner",
                 "c7088f0f3e6c8088236ef8e1e3e70000"],
    "SizeNESW": ["nesw-resize", "size_bdiag", "fd_double_arrow", "ne-resize", "sw-resize",
                 "top_right_corner", "bottom_left_corner",
                 "fcf1c3c7cd4491d801f1e1c78f100000"],
    "SizeAll": ["move", "fleur", "all-scroll", "size_all", "grabbing", "closedhand",
                "4498f0e0c1937ffe01fd06f973665830", "9081237383d90e509aa00f00170e968f"],
    "UpArrow": ["center_ptr", "up_arrow", "sb_up_arrow"],
    "Hand": ["pointer", "hand1", "hand2", "pointing_hand", "grab", "openhand", "alias", "link",
             "dnd-link", "9d800788f1b08800ae810202380a0822",
             "e29285e634086352946a0e7090d73106"],
    "Person": ["person"],
    "Pin": ["pin"],
}

# When a pack does not have a role, the first one of these it does have is used.
FALLBACK = {
    "Help": ["Arrow"],
    "AppStarting": ["Wait", "Arrow"],
    "Wait": ["AppStarting", "Arrow"],
    "Crosshair": ["Arrow"],
    "IBeam": ["Arrow"],
    "NWPen": ["Arrow"],
    "No": ["Arrow"],
    "SizeNS": ["SizeAll", "Arrow"],
    "SizeWE": ["SizeAll", "Arrow"],
    "SizeNWSE": ["SizeAll", "Arrow"],
    "SizeNESW": ["SizeAll", "Arrow"],
    "SizeAll": ["Arrow"],
    "UpArrow": ["Arrow"],
    "Hand": ["Arrow"],
    "Person": ["Hand", "Arrow"],
    "Pin": ["Hand", "Arrow"],
}

# (role, regex on the normalised file name), most specific first.
NAME_RULES = [
    ("AppStarting", r"\b(working|background|appstart\w*|app starting|progress|half busy)\b"),
    ("Wait", r"\b(busy|wait\w*|hourglass|clock|watch|loading|spinner)\b"),
    ("Help", r"\b(help\w*|question)\b"),
    ("Crosshair", r"\b(precision|crosshair|cross\w*)\b"),
    ("NWPen", r"\b(handwriting|handwritting|pen|pencil|write|writing)\b"),
    ("No", r"\b(unavailable|unavail|not allowed|notallowed|forbidden|no drop|denied|"
           r"blocked|no)\b"),
    ("SizeNWSE", r"\b(diagonal\w* ?1|diagonal resize 1|diag ?1|dgn ?1|nwse|nw se|"
                 r"size ?nwse|fdiag)\b"),
    ("SizeNESW", r"\b(diagonal\w* ?2|diagonal resize 2|diag ?2|dgn ?2|nesw|ne sw|"
                 r"size ?nesw|bdiag)\b"),
    ("SizeNS", r"\b(vertical\w*|north south|ns|size ?ns|updown|up down|ver|resize v)\b"),
    ("SizeWE", r"\b(horizontal\w*|east west|ew|we|size ?we|leftright|left right|hor|"
               r"resize h)\b"),
    ("SizeAll", r"\b(move|size ?all|sizeall|four ?arrows?|all scroll|fleur)\b"),
    ("UpArrow", r"\b(alternate\w*|alt select|up ?arrow|uparrow|up)\b"),
    ("IBeam", r"\b(text\w*|ibeam|i beam|beam)\b"),
    ("Person", r"\b(person\w*)\b"),
    ("Pin", r"\b(pin|location\w*)\b"),
    ("Hand", r"\b(link\w*|hand\w*|finger|pointing)\b"),
    ("Arrow", r"\b(normal\w*|arrow|default|select\w*|pointer|cursor|aero)\b"),
]

REG_ROLES = {r.lower(): r for r in SCHEME_ORDER}
REG_ROLES["appstarting"] = "AppStarting"

DEFAULT_SIZES = [24, 32, 48, 64]


def say(*a):
    print(*a, file=sys.stderr)


class CursorError(Exception):
    pass


# ---------------------------------------------------------------------------------------
# Reading Windows cursors
# ---------------------------------------------------------------------------------------

class Image:
    """One cursor image: straight (not premultiplied) RGBA, rows top to bottom."""

    def __init__(self, w, h, rgba, xhot, yhot):
        self.w, self.h, self.rgba, self.xhot, self.yhot = w, h, rgba, xhot, yhot


def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def decode_png(data):
    """A small PNG reader (no interlace): returns (w, h, rgba bytes)."""
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise CursorError("not a PNG")
    pos = 8
    ihdr = None
    plte = None
    trns = None
    idat = bytearray()
    while pos + 8 <= len(data):
        ln, typ = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + ln]
        pos += 12 + ln
        if typ == b"IHDR":
            ihdr = struct.unpack(">IIBBBBB", body)
        elif typ == b"PLTE":
            plte = body
        elif typ == b"tRNS":
            trns = body
        elif typ == b"IDAT":
            idat += body
        elif typ == b"IEND":
            break
    if ihdr is None:
        raise CursorError("PNG without a header")
    w, h, depth, ctype, _, _, interlace = ihdr
    if interlace:
        raise CursorError("interlaced PNG inside a cursor is not supported")
    chans = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(ctype)
    if chans is None:
        raise CursorError("PNG colour type %d" % ctype)
    bits = depth * chans
    stride = (w * bits + 7) // 8
    bpp = max(1, bits // 8)
    raw = zlib.decompress(bytes(idat))
    rows = []
    prev = bytearray(stride)
    p = 0
    for _ in range(h):
        f = raw[p]
        line = bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        if f == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 255
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                ul = prev[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + paeth(left, prev[i], ul)) & 255
        elif f != 0:
            raise CursorError("bad PNG filter")
        rows.append(line)
        prev = line

    out = bytearray(w * h * 4)
    o = 0
    for line in rows:
        for x in range(w):
            if depth == 8:
                if ctype == 6:
                    r, g, b, a = line[4 * x:4 * x + 4]
                elif ctype == 2:
                    r, g, b = line[3 * x:3 * x + 3]
                    a = 255
                elif ctype == 0:
                    r = g = b = line[x]
                    a = 255
                elif ctype == 4:
                    r = g = b = line[2 * x]
                    a = line[2 * x + 1]
                else:
                    i = line[x]
                    r, g, b = plte[3 * i:3 * i + 3]
                    a = trns[i] if trns and i < len(trns) else 255
            elif depth == 16:
                if ctype == 6:
                    r, g, b, a = line[8 * x:8 * x + 8:2]
                elif ctype == 2:
                    r, g, b = line[6 * x:6 * x + 6:2]
                    a = 255
                elif ctype == 0:
                    r = g = b = line[2 * x]
                    a = 255
                else:
                    r = g = b = line[4 * x]
                    a = line[4 * x + 2]
            else:  # 1, 2, 4 bit grey or palette
                per = 8 // depth
                v = (line[x // per] >> (8 - depth * (x % per + 1))) & ((1 << depth) - 1)
                if ctype == 3:
                    r, g, b = plte[3 * v:3 * v + 3]
                    a = trns[v] if trns and v < len(trns) else 255
                else:
                    r = g = b = v * 255 // ((1 << depth) - 1)
                    a = 255
            out[o:o + 4] = bytes((r, g, b, a))
            o += 4
    return w, h, bytes(out)


def decode_dib(data):
    """The bitmap inside a .cur entry: XOR image + AND mask. Returns (w, h, rgba)."""
    hsize, w, h2, planes, bpp, comp, _, _, _, ncol, _ = struct.unpack("<IiiHHIIiiII", data[:40])
    if comp not in (0, 3):
        raise CursorError("compressed cursor bitmap (type %d)" % comp)
    # A cursor's height field counts the image and its mask; a few files hold the image only.
    h = abs(h2) // 2
    has_mask = True
    top_down = h2 < 0
    pos = hsize
    pal = []
    if bpp <= 8:
        n = ncol or (1 << bpp)
        for i in range(n):
            b, g, r, _ = data[pos + 4 * i:pos + 4 * i + 4]
            pal.append((r, g, b))
        pos += 4 * n
    elif comp == 3 and hsize == 40:
        pos += 12  # bit masks follow the header
    stride = ((w * bpp + 31) // 32) * 4
    mstride = ((w + 31) // 32) * 4
    if pos + stride * h + mstride * h > len(data):
        h = abs(h2)
        has_mask = False
    xor_rows = []
    for y in range(h):
        xor_rows.append(data[pos + y * stride:pos + (y + 1) * stride])
    pos += stride * h
    mask_rows = None
    if has_mask:
        mask_rows = [data[pos + y * mstride:pos + (y + 1) * mstride] for y in range(h)]

    out = bytearray(w * h * 4)
    any_alpha = False
    px = []
    for y in range(h):
        row = xor_rows[y]
        for x in range(w):
            if bpp == 32:
                b, g, r, a = row[4 * x:4 * x + 4]
                if a:
                    any_alpha = True
            elif bpp == 24:
                b, g, r = row[3 * x:3 * x + 3]
                a = 255
            elif bpp == 8:
                r, g, b = pal[row[x]] if row[x] < len(pal) else (0, 0, 0)
                a = 255
            elif bpp == 4:
                v = (row[x >> 1] >> (4 if x % 2 == 0 else 0)) & 15
                r, g, b = pal[v] if v < len(pal) else (0, 0, 0)
                a = 255
            elif bpp == 1:
                v = (row[x >> 3] >> (7 - (x & 7))) & 1
                r, g, b = pal[v] if v < len(pal) else (0, 0, 0)
                a = 255
            else:
                raise CursorError("%d-bit cursor bitmap" % bpp)
            px.append((r, g, b, a))
    # 32-bit with real alpha: the mask is ignored. Everything else: the mask decides.
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[y * w + x]
            if not (bpp == 32 and any_alpha) and mask_rows is not None:
                masked = (mask_rows[y][x >> 3] >> (7 - (x & 7))) & 1
                if masked:
                    # AND=1, XOR=0: see through. AND=1, XOR!=0: "invert the screen";
                    # drawn as solid black, the nearest thing a plain image can do.
                    a = 255 if (r or g or b) else 0
                    if a:
                        r = g = b = 0
                else:
                    a = 255
            elif bpp == 32 and not any_alpha:
                a = 255
            ry = y if top_down else h - 1 - y
            o = (ry * w + x) * 4
            out[o:o + 4] = bytes((r, g, b, a))
    return w, h, bytes(out)


def parse_cur(data):
    """Every image of a .cur / .ico file, biggest first."""
    if len(data) < 6:
        raise CursorError("file too short")
    reserved, typ, count = struct.unpack("<HHH", data[:6])
    if reserved != 0 or typ not in (1, 2) or count == 0:
        raise CursorError("not a .cur file")
    imgs = []
    for i in range(count):
        e = data[6 + 16 * i:6 + 16 * i + 16]
        if len(e) < 16:
            break
        _, _, _, _, xhot, yhot, size, off = struct.unpack("<BBBBHHII", e)
        blob = data[off:off + size]
        try:
            if blob[:8] == b"\x89PNG\r\n\x1a\n":
                w, h, rgba = decode_png(blob)
            else:
                w, h, rgba = decode_dib(blob)
        except (CursorError, struct.error, IndexError, zlib.error) as ex:
            say("  skipped one image of a cursor file: %s" % ex)
            continue
        if typ == 1:  # an .ico has no hot spot
            xhot = yhot = 0
        imgs.append(Image(w, h, rgba, min(xhot, w - 1), min(yhot, h - 1)))
    if not imgs:
        raise CursorError("no readable image")
    imgs.sort(key=lambda im: -im.w * im.h)
    return imgs


class Cursor:
    """A cursor: steps of (image, delay in ms). One step = still cursor."""

    def __init__(self, steps):
        self.steps = steps

    @property
    def animated(self):
        return len(self.steps) > 1


def parse_ani(data):
    if data[:4] != b"RIFF" or data[8:12] != b"ACON":
        raise CursorError("not an .ani file")
    pos = 12
    end = min(len(data), 8 + struct.unpack("<I", data[4:8])[0])
    anih = None
    rates = None
    seq = None
    frames = []

    def chunks(buf, p, stop):
        while p + 8 <= stop:
            cid = buf[p:p + 4]
            ln = struct.unpack("<I", buf[p + 4:p + 8])[0]
            yield cid, p + 8, ln
            p += 8 + ln + (ln & 1)

    for cid, p, ln in chunks(data, pos, end):
        if cid == b"anih":
            anih = struct.unpack("<9I", data[p:p + 36])
        elif cid == b"rate":
            rates = list(struct.unpack("<%dI" % (ln // 4), data[p:p + ln]))
        elif cid == b"seq ":
            seq = list(struct.unpack("<%dI" % (ln // 4), data[p:p + ln]))
        elif cid == b"LIST" and data[p:p + 4] == b"fram":
            for c2, p2, l2 in chunks(data, p + 4, p + ln):
                if c2 == b"icon":
                    frames.append(parse_cur(data[p2:p2 + l2]))
    if anih is None or not frames:
        raise CursorError("an .ani file with no frames")
    n_frames, n_steps, disp = anih[1], anih[2], anih[7]
    flags = anih[8]
    if not flags & 1:
        raise CursorError("an .ani with raw (non-icon) frames is not supported")
    if not seq:
        seq = list(range(len(frames)))
    n_steps = len(seq) if not n_steps or n_steps > len(seq) else n_steps
    seq = seq[:n_steps]
    steps = []
    for i, f in enumerate(seq):
        if f >= len(frames):
            f = len(frames) - 1
        jif = rates[i] if rates and i < len(rates) else (disp or 6)
        ms = max(10, int(round(jif * 1000.0 / 60.0)))
        steps.append((frames[f][0], ms))
    return Cursor(steps)


def load_cursor(path):
    with open(path, "rb") as fh:
        data = fh.read()
    if data[:4] == b"RIFF":
        return parse_ani(data)
    return Cursor([(parse_cur(data)[0], 0)])


# ---------------------------------------------------------------------------------------
# Resizing and writing Xcursor
# ---------------------------------------------------------------------------------------

def _weights(n_in, n_out):
    """For each output pixel: [(input index, weight)], a triangle filter whose width follows
    the scale, so shrinking averages and enlarging smooths."""
    scale = n_in / float(n_out)
    support = max(1.0, scale)
    table = []
    for o in range(n_out):
        centre = (o + 0.5) * scale
        lo = max(0, int(centre - support))
        hi = min(n_in, int(centre + support) + 1)
        ws = []
        tot = 0.0
        for i in range(lo, hi):
            d = abs((i + 0.5) - centre) / support
            w = 1.0 - d
            if w > 0:
                ws.append((i, w))
                tot += w
        if not ws:
            i = min(n_in - 1, int(centre))
            ws, tot = [(i, 1.0)], 1.0
        table.append([(i, w / tot) for i, w in ws])
    return table


def resize(img, size):
    """Scale to `size` pixels on the long side (cursors are square-ish), in premultiplied
    colour so the edge does not turn dark. Returns (w, h, premultiplied ARGB ints, xhot, yhot)."""
    f = size / float(max(img.w, img.h))
    nw, nh = max(1, int(round(img.w * f))), max(1, int(round(img.h * f)))
    xhot = min(nw - 1, int(round(img.xhot * f)))
    yhot = min(nh - 1, int(round(img.yhot * f)))
    src = img.rgba
    # premultiply into floats
    pm = []
    for i in range(0, len(src), 4):
        r, g, b, a = src[i:i + 4]
        k = a / 255.0
        pm.append((r * k, g * k, b * k, float(a)))
    if (nw, nh) == (img.w, img.h):
        tmp = pm
    else:
        wx = _weights(img.w, nw)
        wy = _weights(img.h, nh)
        mid = []  # img.h rows of nw
        for y in range(img.h):
            row = pm[y * img.w:(y + 1) * img.w]
            for ws in wx:
                r = g = b = a = 0.0
                for i, w in ws:
                    p = row[i]
                    r += p[0] * w
                    g += p[1] * w
                    b += p[2] * w
                    a += p[3] * w
                mid.append((r, g, b, a))
        tmp = []
        for y in range(nh):
            for x in range(nw):
                r = g = b = a = 0.0
                for j, w in wy[y]:
                    p = mid[j * nw + x]
                    r += p[0] * w
                    g += p[1] * w
                    b += p[2] * w
                    a += p[3] * w
                tmp.append((r, g, b, a))
    out = []
    for r, g, b, a in tmp:
        a8 = min(255, max(0, int(round(a))))
        out.append((a8 << 24) | (min(a8, max(0, int(round(r)))) << 16)
                   | (min(a8, max(0, int(round(g)))) << 8) | min(a8, max(0, int(round(b)))))
    return nw, nh, out, xhot, yhot


def write_xcursor(path, cursor, sizes):
    """Xcursor file: for each nominal size, every step in order (that is what makes it play)."""
    chunks = []
    cache = {}
    for size in sizes:
        for img, delay in cursor.steps:
            key = (id(img), size)
            if key not in cache:
                cache[key] = resize(img, size)
            w, h, px, xh, yh = cache[key]
            body = struct.pack("<IIIIIIIII", 36, 0xFFFD0002, size, 1, w, h, xh, yh, delay)
            body += struct.pack("<%dI" % len(px), *px)
            chunks.append((size, body))
    head = 16 + 12 * len(chunks)
    toc = b""
    off = head
    for size, body in chunks:
        toc += struct.pack("<III", 0xFFFD0002, size, off)
        off += len(body)
    with open(path, "wb") as fh:
        fh.write(b"Xcur" + struct.pack("<III", 16, 0x10000, len(chunks)) + toc)
        for _, body in chunks:
            fh.write(body)


# ---------------------------------------------------------------------------------------
# Finding out which file is which role
# ---------------------------------------------------------------------------------------

def norm_name(stem):
    s = re.sub(r"([a-z])([A-Z])", r"\1 \2", stem)
    s = s.lower()
    s = re.sub(r"[_\-.()\[\]]+", " ", s)
    s = re.sub(r"(?<=\D)(\d+)$", r" \1", s)
    return re.sub(r"\s+", " ", s).strip()


def role_from_name(stem):
    n = norm_name(stem)
    n = re.sub(r"^\d+\s+", "", n)  # a leading "01 "
    for role, rx in NAME_RULES:
        if re.search(rx, n):
            return role
    return None


def parse_inf(text, files):
    """role -> file path, from a Windows cursor install .inf. `files`: lower-case basename -> path."""
    strings = {}
    sec = ""
    lines = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith(";"):
            continue
        m = re.match(r"^\[(.+)\]$", line)
        if m:
            sec = m.group(1).strip().lower()
            continue
        lines.append((sec, line))
        if sec == "strings":
            m = re.match(r'^([^=]+?)\s*=\s*"?(.*?)"?\s*$', line)
            if m:
                strings[m.group(1).strip().lower()] = m.group(2)

    def expand(s):
        for _ in range(4):
            s2 = re.sub(r"%([^%]+)%", lambda m: strings.get(m.group(1).lower(), m.group(0)), s)
            if s2 == s:
                break
            s = s2
        return s

    def find(token):
        base = re.split(r"[\\/]", expand(token.strip().strip('"')))[-1].strip().lower()
        return files.get(base)

    roles = {}
    # per-role registry lines:  HKCU,"Control Panel\Cursors",Arrow,0x00020000,"%10%\...\x.cur"
    for sec, line in lines:
        m = re.match(r'^HK\w+\s*,\s*"?Control Panel\\Cursors"?\s*,\s*"?(\w+)"?\s*,[^,]*,\s*(.+)$',
                     line, re.I)
        if m and m.group(1).lower() in REG_ROLES:
            f = find(m.group(2))
            if f:
                roles[REG_ROLES[m.group(1).lower()]] = f
    if roles:
        return roles
    # the scheme string:  HKCU,"Control Panel\Cursors\Schemes","Name",,"a.cur,b.cur,..."
    for sec, line in lines:
        if re.search(r"Cursors\\Schemes", line, re.I):
            m = re.search(r',\s*"([^"]*)"\s*$', line)
            if m:
                parts = expand(m.group(1)).split(",")
                for role, part in zip(SCHEME_ORDER, parts):
                    f = find(part)
                    if f:
                        roles[role] = f
                if roles:
                    return roles
    return roles


def scheme_name_from_inf(text):
    strings = {}
    sec = ""
    for raw in text.splitlines():
        line = raw.strip()
        m = re.match(r"^\[(.+)\]$", line)
        if m:
            sec = m.group(1).strip().lower()
            continue
        if sec == "strings":
            m = re.match(r'^([^=;]+?)\s*=\s*"?(.*?)"?\s*$', line)
            if m:
                strings[m.group(1).strip().lower()] = m.group(2)
    for k in ("scheme_name", "scheme", "name", "cursor_name", "cursorname", "scheme.name"):
        if strings.get(k):
            return strings[k]
    return ""


# ---------------------------------------------------------------------------------------
# Putting it together
# ---------------------------------------------------------------------------------------

def gather(src, work):
    """-> (list of .cur/.ani paths, inf text or '', suggested name)"""
    if os.path.isfile(src) and zipfile.is_zipfile(src):
        dest = os.path.join(work, "unzipped")
        with zipfile.ZipFile(src) as z:
            for info in z.infolist():
                # no path tricks out of the folder
                target = os.path.realpath(os.path.join(dest, info.filename))
                if not target.startswith(os.path.realpath(dest) + os.sep) and \
                        target != os.path.realpath(dest):
                    continue
                z.extract(info, dest)
        root = dest
        name = os.path.splitext(os.path.basename(src))[0]
    elif os.path.isdir(src):
        root = src
        name = os.path.basename(os.path.abspath(src))
    elif os.path.isfile(src):
        root = os.path.dirname(os.path.abspath(src))
        name = os.path.splitext(os.path.basename(src))[0]
        if src.lower().endswith((".cur", ".ani")):
            return [os.path.abspath(src)], "", name
    else:
        raise CursorError("no such file or folder: %s" % src)
    paths, inf = [], ""
    for d, _, fs in os.walk(root):
        for f in sorted(fs):
            low = f.lower()
            if low.endswith((".cur", ".ani")):
                paths.append(os.path.join(d, f))
            elif low.endswith(".inf") and not inf:
                try:
                    with open(os.path.join(d, f), "rb") as fh:
                        raw = fh.read()
                    inf = raw.decode("utf-16") if raw[:2] in (b"\xff\xfe", b"\xfe\xff") \
                        else raw.decode("utf-8", "replace")
                except OSError:
                    pass
    return paths, inf, name


def clean_name(s):
    s = re.sub(r"[^A-Za-z0-9._+ -]+", " ", s)
    s = re.sub(r"\s+", " ", s).strip(" .-")
    return s or "Windows-Cursors"


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("pack")
    ap.add_argument("-n", "--name", help="theme name (default: from the pack)")
    ap.add_argument("--sizes", default=",".join(map(str, DEFAULT_SIZES)),
                    help="pixel sizes to write, comma separated (default %(default)s)")
    ap.add_argument("--dest", help="icons folder (default ~/.local/share/icons)")
    ap.add_argument("--map", action="append", default=[], metavar="Role=file",
                    help="force a role, e.g. --map Hand=link.cur (roles: %s)" % ", ".join(SCHEME_ORDER))
    ap.add_argument("--dry-run", action="store_true", help="only show which file becomes which cursor")
    ap.add_argument("--force", action="store_true", help="replace a theme with the same name")
    a = ap.parse_args(argv)

    try:
        sizes = sorted({int(s) for s in a.sizes.split(",") if s.strip()})
        if not sizes or sizes[0] < 8 or sizes[-1] > 256:
            raise ValueError
    except ValueError:
        say("--sizes must be numbers from 8 to 256, e.g. 24,32,48,64")
        return 2

    work = tempfile.mkdtemp(prefix="win-cursor-")
    try:
        try:
            paths, inf, suggested = gather(a.pack, work)
        except (CursorError, zipfile.BadZipFile, OSError) as ex:
            say("win-cursor: %s" % ex)
            return 2
        if not paths:
            say("win-cursor: no .cur / .ani files found in %s" % a.pack)
            return 2
        byname = {os.path.basename(p).lower(): p for p in paths}

        roles = {}
        how = {}
        if inf:
            for r, p in parse_inf(inf, byname).items():
                roles[r] = p
                how[r] = "install.inf"
        for p in paths:
            r = role_from_name(os.path.splitext(os.path.basename(p))[0])
            if r and r not in roles:
                roles[r] = p
                how[r] = "file name"
        for m in a.map:
            if "=" not in m:
                say("win-cursor: --map wants Role=file, got %s" % m)
                return 2
            r, f = m.split("=", 1)
            r = REG_ROLES.get(r.strip().lower())
            if not r:
                say("win-cursor: unknown role in --map (roles: %s)" % ", ".join(SCHEME_ORDER))
                return 2
            hit = byname.get(os.path.basename(f).lower()) or (f if os.path.isfile(f) else None)
            if not hit:
                say("win-cursor: --map file not found: %s" % f)
                return 2
            roles[r] = hit
            how[r] = "--map"

        for r in SCHEME_ORDER:
            if r in roles:
                say("  %-12s <- %s  (%s)" % (r, os.path.basename(roles[r]), how[r]))
        for r in SCHEME_ORDER:
            if r not in roles and r not in ("Person", "Pin"):
                for alt in FALLBACK.get(r, ["Arrow"]):
                    if alt in roles:
                        say("  %-12s    (no file; uses %s)" % (r, alt))
                        break
        used = set(roles.values())
        left = [os.path.basename(p) for p in paths if p not in used]
        if left:
            say("  not used: %s" % ", ".join(left))
        if "Arrow" not in roles:
            say("win-cursor: no normal arrow cursor found; name one with --map Arrow=<file>")
            return 2
        if a.dry_run:
            return 0

        name = clean_name(a.name or scheme_name_from_inf(inf) or suggested)
        base = a.dest or os.path.join(os.environ.get("XDG_DATA_HOME")
                                      or os.path.expanduser("~/.local/share"), "icons")
        theme = os.path.join(base, name)
        if os.path.exists(theme) and not a.force:
            if os.path.isfile(os.path.join(theme, ".win-cursor")):
                a.force = True  # made by this script before: refresh it
            else:
                say("win-cursor: %s already exists and was not made by this script "
                    "(use -n for another name, or --force)" % theme)
                return 2
        stage = os.path.join(work, "theme")
        os.makedirs(os.path.join(stage, "cursors"))

        loaded = {}
        for r, p in roles.items():
            try:
                loaded[r] = load_cursor(p)
            except (CursorError, struct.error, OSError, zlib.error) as ex:
                say("  %s (%s): skipped, %s" % (r, os.path.basename(p), ex))
        if "Arrow" not in loaded:
            say("win-cursor: the arrow cursor could not be read")
            return 2

        written = 0
        for r in SCHEME_ORDER:
            cur = loaded.get(r)
            if cur is None:
                continue
            names = XNAMES[r]
            write_xcursor(os.path.join(stage, "cursors", names[0]), cur, sizes)
            written += 1
            for alias in names[1:]:
                dst = os.path.join(stage, "cursors", alias)
                if not os.path.lexists(dst):
                    os.symlink(names[0], dst)
        # A role the pack does not have: its names point at the cursor it falls back to.
        for r in SCHEME_ORDER:
            if r in loaded or r in ("Person", "Pin"):
                continue
            for alt in FALLBACK.get(r, ["Arrow"]):
                if alt in loaded:
                    for n in XNAMES[r]:
                        dst = os.path.join(stage, "cursors", n)
                        if not os.path.lexists(dst):
                            os.symlink(XNAMES[alt][0], dst)
                    break

        with open(os.path.join(stage, "index.theme"), "w") as fh:
            fh.write("[Icon Theme]\nName=%s\nComment=Converted from a Windows cursor pack by "
                     "win-cursor.py\n" % name)
        with open(os.path.join(stage, ".win-cursor"), "w") as fh:
            fh.write("source=%s\nsizes=%s\n" % (os.path.basename(a.pack),
                                                 ",".join(map(str, sizes))))

        os.makedirs(base, exist_ok=True)
        if os.path.exists(theme):
            shutil.rmtree(theme)
        shutil.move(stage, theme)
        anim = sum(1 for c in loaded.values() if c.animated)
        say("win-cursor: %d cursors (%d animated) written to %s" % (written, anim, theme))
        print(name)
        return 0
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)
