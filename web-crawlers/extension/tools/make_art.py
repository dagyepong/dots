#!/usr/bin/env python3
"""Generate the toolbar icons and Chrome Web Store artwork for "Web Crawlers".

Everything is drawn procedurally from the same spider model the art piece
uses (js/crawler.js: leg table, body box, abdomen chain, palette C), so the
output is original artwork and fully deterministic: run it again and you get
byte-identical PNGs (same fonts, same Pillow).

    python extension/tools/make_art.py

Requires Python 3.10+, Pillow and numpy (no scipy). Fonts: Consolas / Segoe UI
from C:/Windows/Fonts (Courier New / Arial are used as fallbacks).

Outputs
    extension/src/icons/icon{16,32,48,128}.png
    extension/store/promo-small-440x280.png
    extension/store/promo-marquee-1400x560.png
    extension/store/icon-preview.png      (review sheet, not uploaded)
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
EXT = HERE.parent
ICON_DIR = EXT / "src" / "icons"
STORE_DIR = EXT / "store"

# --------------------------------------------------------------------------
# palette (js/crawler.js, const C) + page colours (css/style.css)
# --------------------------------------------------------------------------
PAL = {
    "leg": "#5cc8ff", "legHi": "#9be0ff", "joint": "#ff4a6e", "body": "#cfe8ff",
    "bodyFill": (20, 40, 130, 166),  # rgba(20,40,130,.65)
    "blue": "#3d6dff", "red": "#ff3355", "purple": "#b44dff", "cyan": "#42cfff",
    "magenta": "#ff36d9", "pink": "#ff5ca8", "orange": "#ff7d45", "mint": "#6dffb0",
    "white": "#f2f2f2", "yellow": "#ffe14d", "sky": "#8fd8ff",
    "fg": "#e8e9eb", "dim": "#a2a9b1", "rule": "#54595d", "link": "#7f9dff",
    "ink": "#06061e",
}


def rgba(c, a: float | None = None) -> tuple[int, int, int, int]:
    """'#rrggbb' or (r,g,b[,a]) -> (r,g,b,a); `a` (0..1) multiplies alpha."""
    if isinstance(c, str):
        h = c.lstrip("#")
        col = (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)
    else:
        col = tuple(c) + (255,) * (4 - len(c))
    if a is not None:
        col = col[:3] + (round(col[3] * a),)
    return col


# --------------------------------------------------------------------------
# fonts
# --------------------------------------------------------------------------
FONT_DIRS = [Path("C:/Windows/Fonts"), Path.home() / "AppData/Local/Microsoft/Windows/Fonts",
             Path("/usr/share/fonts/truetype/msttcorefonts")]
FONT_FILES = {
    "mono": ["consola.ttf", "cour.ttf"],
    "monoB": ["consolab.ttf", "courbd.ttf"],
    "sans": ["segoeui.ttf", "arial.ttf"],
    "sansB": ["segoeuib.ttf", "arialbd.ttf"],
}
_font_cache: dict = {}


def font(kind: str, px: float) -> ImageFont.FreeTypeFont:
    key = (kind, int(round(px)))
    if key not in _font_cache:
        for name in FONT_FILES[kind]:
            for d in FONT_DIRS:
                if (d / name).exists():
                    _font_cache[key] = ImageFont.truetype(str(d / name), key[1])
                    break
            if key in _font_cache:
                break
        else:
            raise FileNotFoundError(f"no font for {kind}: {FONT_FILES[kind]}")
    return _font_cache[key]


# --------------------------------------------------------------------------
# supersampled canvas: every primitive is rasterised into an L mask at
# `ss` x resolution and alpha-composited, so translucent strokes blend
# correctly; final() downsamples with LANCZOS (premultiplied by Pillow).
# Coordinates are always in OUTPUT pixels.
# --------------------------------------------------------------------------
def R(X, x0, y0, x1, y1):
    """Mask-space box for Pillow's (end-inclusive) rectangle calls, far edge exclusive."""
    a, b = X(x0, y0)
    c, d = X(x1, y1)
    return [a, b, c - 1, d - 1]


class Canvas:
    def __init__(self, w: int, h: int, ss: int, bg=(0, 0, 0, 0)):
        self.w, self.h, self.ss = w, h, ss
        self.im = Image.new("RGBA", (w * ss, h * ss), rgba(bg))

    # -- core ------------------------------------------------------------
    def _mask(self, bbox, painter, pad=3):
        s = self.ss
        x0 = max(0, math.floor(bbox[0] * s) - pad)
        y0 = max(0, math.floor(bbox[1] * s) - pad)
        x1 = min(self.im.width, math.ceil(bbox[2] * s) + pad)
        y1 = min(self.im.height, math.ceil(bbox[3] * s) + pad)
        if x1 <= x0 or y1 <= y0:
            return None, (0, 0)
        m = Image.new("L", (x1 - x0, y1 - y0), 0)
        d = ImageDraw.Draw(m)
        painter(d, lambda x, y: (x * s - x0, y * s - y0), s)
        return m, (x0, y0)

    def paint(self, bbox, painter, color):
        m, xy = self._mask(bbox, painter)
        if m is not None:
            self.put_mask(m, xy, color)

    def put_mask(self, m: Image.Image, xy, color):
        r, g, b, a = rgba(color)
        if a < 255:
            m = Image.fromarray((np.asarray(m, np.uint16) * a // 255).astype(np.uint8))
        layer = Image.new("RGBA", m.size, (r, g, b, 255))
        layer.putalpha(m)
        self.im.alpha_composite(layer, xy)

    def final(self) -> Image.Image:
        out = self.im.resize((self.w, self.h), Image.LANCZOS)
        # LANCZOS rings up to ~3 px past a shape's edge; wherever the exact area
        # coverage (BOX) is empty, keep the pixel fully transparent
        cover = np.asarray(self.im.getchannel("A").resize((self.w, self.h), Image.BOX))
        px = np.asarray(out).copy()
        px[cover == 0] = 0
        return Image.fromarray(px, "RGBA")

    # -- shapes ----------------------------------------------------------
    def polyline(self, pts, color, w, closed=False, cap=True):
        pts = [tuple(map(float, p)) for p in pts]
        if closed:
            pts = pts + [pts[0]]
        r = w / 2
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        bbox = (min(xs) - r, min(ys) - r, max(xs) + r, max(ys) + r)

        def painter(d, X, s):
            for (ax, ay), (bx, by) in zip(pts, pts[1:]):
                dx, dy = bx - ax, by - ay
                L = math.hypot(dx, dy) or 1e-9
                nx, ny = -dy / L * r, dx / L * r
                d.polygon([X(ax + nx, ay + ny), X(bx + nx, by + ny), X(bx - nx, by - ny), X(ax - nx, ay - ny)], fill=255)
            joints = pts if cap else pts[1:-1]
            for (px, py) in joints:
                cx, cy = X(px, py)
                d.ellipse([cx - r * s, cy - r * s, cx + r * s, cy + r * s], fill=255)

        self.paint(bbox, painter, color)

    def line(self, a, b, color, w):
        self.polyline([a, b], color, w)

    def dot(self, p, r, color):
        x, y = float(p[0]), float(p[1])

        def painter(d, X, s):
            cx, cy = X(x, y)
            d.ellipse([cx - r * s, cy - r * s, cx + r * s, cy + r * s], fill=255)

        self.paint((x - r, y - r, x + r, y + r), painter, color)

    def ring(self, p, r, color, w):
        x, y = float(p[0]), float(p[1])
        ro, ri = r + w / 2, max(0.0, r - w / 2)

        def painter(d, X, s):
            cx, cy = X(x, y)
            d.ellipse([cx - ro * s, cy - ro * s, cx + ro * s, cy + ro * s], fill=255)
            d.ellipse([cx - ri * s, cy - ri * s, cx + ri * s, cy + ri * s], fill=0)

        self.paint((x - ro, y - ro, x + ro, y + ro), painter, color)

    def poly(self, pts, color):
        pts = [tuple(map(float, p)) for p in pts]
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        self.paint((min(xs), min(ys), max(xs), max(ys)),
                   lambda d, X, s: d.polygon([X(*p) for p in pts], fill=255), color)

    def rect(self, x0, y0, x1, y1, color):
        self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], color)

    def frame(self, x0, y0, x1, y1, color, w):
        """Rectangle outline with crisp mitred corners, centred on the edges."""
        h = w / 2

        def painter(d, X, s):
            d.rectangle(R(X, x0 - h, y0 - h, x1 + h, y1 + h), fill=255)
            if x1 - x0 > w and y1 - y0 > w:
                d.rectangle(R(X, x0 + h, y0 + h, x1 - h, y1 - h), fill=0)

        self.paint((x0 - h, y0 - h, x1 + h, y1 + h), painter, color)

    def quad_frame(self, outer, inner, color):
        """Outline of a (rotated) quad: outer polygon minus inner polygon."""
        xs = [p[0] for p in outer]
        ys = [p[1] for p in outer]

        def painter(d, X, s):
            d.polygon([X(*p) for p in outer], fill=255)
            d.polygon([X(*p) for p in inner], fill=0)

        self.paint((min(xs), min(ys), max(xs), max(ys)), painter, color)

    def rounded(self, x0, y0, x1, y1, rad, color):
        self.paint((x0, y0, x1, y1),
                   lambda d, X, s: d.rounded_rectangle(R(X, x0, y0, x1, y1), radius=rad * s, fill=255), color)

    # -- text ------------------------------------------------------------
    def text(self, x, y, txt, kind, px, color, anchor="ls", tracking=0.0):
        """Draw text with its anchor at (x, y) output px. tracking in em."""
        s = self.ss
        f = font(kind, px * s)
        if tracking:
            # per-character advance (monospace use only)
            adv = f.getlength("M") / s + tracking * px
            for i, ch in enumerate(txt):
                self.text(x + i * adv, y, ch, kind, px, color, anchor=anchor)
            return
        l, t, r, b = f.getbbox(txt, anchor=anchor)

        def painter(d, X, s_):
            d.text(X(x, y), txt, font=f, fill=255, anchor=anchor)

        self.paint((x + l / s, y + t / s, x + r / s, y + b / s), painter, color)

    def text_len(self, txt, kind, px, tracking=0.0):
        f = font(kind, px * self.ss)
        if tracking:
            return len(txt) * (f.getlength("M") / self.ss + tracking * px) - tracking * px
        return f.getlength(txt) / self.ss

    def paste_rotated(self, layer: Image.Image, center, angle_deg: float):
        """Composite an RGBA layer (already at ss resolution) rotated about its centre."""
        rot = layer.rotate(angle_deg, resample=Image.BICUBIC, expand=True)
        cx, cy = center[0] * self.ss, center[1] * self.ss
        x0, y0 = int(round(cx - rot.width / 2)), int(round(cy - rot.height / 2))
        # clip to canvas
        sx0, sy0 = max(0, -x0), max(0, -y0)
        sx1 = min(rot.width, self.im.width - x0)
        sy1 = min(rot.height, self.im.height - y0)
        if sx1 <= sx0 or sy1 <= sy0:
            return
        self.im.alpha_composite(rot.crop((sx0, sy0, sx1, sy1)), (x0 + sx0, y0 + sy0))


# --------------------------------------------------------------------------
# the spider (same model as js/crawler.js)
# --------------------------------------------------------------------------
# leg rest angle (rad, relative to heading; +right), reach (units), hip offset along body
LEG_DEF = [(0.55, 118, 7), (1.15, 106, 3), (1.95, 106, -1), (2.55, 126, -5)]
PALP_DEF = (0.22, 38, 10)
# the same legs fanned a little wider for a clean, readable "hero" silhouette (icons, promos)
HERO_LEGS = [(0.50, 112, 7), (1.08, 104, 3), (2.00, 104, -1), (2.62, 116, -5)]
# 16 px: three pairs only (front / side / rear)
TINY_LEGS = [(0.55, 112, 6), (1.57, 98, 1), (2.58, 112, -4)]


def V(x, y=None):
    if y is None:
        return np.array(x, float)
    return np.array([x, y], float)


def rot(v, a):
    c, s = math.cos(a), math.sin(a)
    return V(v[0] * c - v[1] * s, v[0] * s + v[1] * c)


def ik(h, f, L1, L2, bend):
    d = float(np.hypot(*(f - h)))
    base = math.atan2(f[1] - h[1], f[0] - h[0])
    if d >= L1 + L2 - 0.01:
        return h + V(math.cos(base), math.sin(base)) * L1
    c = max(-1.0, min(1.0, (L1 * L1 + d * d - L2 * L2) / (2 * L1 * d)))
    b = base + bend * math.acos(c)
    return h + V(math.cos(b), math.sin(b)) * L1


class Spider:
    """Pose of the crawler. Units follow the art piece (scale = its SCALE)."""

    def __init__(self, p, heading, scale, *, body_k=1.0, leg_k=0.8, legs=(0, 1, 2, 3), palps=True,
                 knees="art", abd_swing=0.0, leg_def=None, ext=None, abd_k=None):
        """p: body centre (px), heading (rad, screen coords), scale: px per art unit.
        body_k / abd_k: enlarge body box / abdomen chain; leg_k or ext {idx: k}: foot
        distance as a fraction of reach; knees: "art" (crawler.js) or "out" (classic)."""
        self.p = V(p)
        self.heading = heading
        self.scale = scale
        self.body_k = body_k
        self.fwd = V(math.cos(heading), math.sin(heading))
        bs = body_k * scale
        self.legs = []
        ld = leg_def or LEG_DEF
        defs = [(i, *ld[i]) for i in legs] + ([(4, *PALP_DEF)] if palps else [])
        for side in (1, -1):
            for idx, a, reach, hip in defs:
                palp = idx == 4
                r = reach * scale
                ang = a * side
                hp = self.p + rot(V(hip * bs, side * 3 * bs), heading)
                k = 1.0 if palp else (ext[idx] if ext else leg_k)
                rest = hp + rot(V(math.cos(ang), math.sin(ang)) * r * k, heading)
                L = dict(side=side, idx=idx, palp=palp, ang=ang, reach=r, L1=r * 0.56, L2=r * 0.64,
                         hip=hp, rest=rest, foot=rest.copy(), lifted=False)
                if knees == "art":  # front three bend forward, rear leg + palp outward
                    L["bend"] = (1 if idx in (3, 4) else -1) * side
                else:  # "out": every knee bows away from the body axis
                    L["bend"] = (1 if abs(a) < math.pi / 2 else -1) * side
                self.legs.append(L)
        self.head = self.p + self.fwd * 12 * bs
        ab = (abd_k if abd_k is not None else body_k) * scale
        back = rot(-self.fwd, abd_swing)
        self.abd = self.p + back * 17 * ab
        self.spin = self.abd + rot(back, abd_swing * 0.8) * 13 * ab

    def leg(self, side, idx):
        for L in self.legs:
            if L["side"] == side and L["idx"] == idx:
                return L
        raise KeyError((side, idx))

    def solve(self):
        for L in self.legs:
            L["knee"] = ik(L["hip"], L["foot"], L["L1"], L["L2"], L["bend"])
        return self

    def box(self, grow=0.0):
        """Body box corners (art: x -8..10 along heading, y -5.5..5.5)."""
        g = grow
        if getattr(self, "box_rect", None):  # pixel-aligned override (tiny icons, heading up)
            x0, y0, x1, y1 = self.box_rect
            return [(x0 - g, y0 - g), (x1 + g, y0 - g), (x1 + g, y1 + g), (x0 - g, y1 + g)]
        bs = self.body_k * self.scale
        loc = [(-8 * bs - g, -5.5 * bs - g), (10 * bs + g, -5.5 * bs - g),
               (10 * bs + g, 5.5 * bs + g), (-8 * bs - g, 5.5 * bs + g)]
        return [tuple(self.p + rot(V(*q), self.heading)) for q in loc]

    def points(self):
        pts = [self.head, self.abd, self.spin] + [V(q) for q in self.box()]
        for L in self.legs:
            pts += [L["hip"], L["knee"], L["foot"]]
        return np.array(pts)


def draw_spider(cv: Canvas, sp: Spider, st: dict):
    """Draw order follows crawler.js draw(): legs, body chain, box, dots."""
    lw = st["lw"]
    for L in sp.legs:
        w = lw * (0.75 if L["palp"] else 1.0)
        tint = L.get("tint")
        c1 = tint or PAL["leg"]
        c2 = tint or (PAL["legHi"] if L["idx"] == 3 else PAL["leg"])
        cv.line(L["hip"], L["knee"], c1, w)
        cv.line(L["knee"], L["foot"], c2, w)
        if st.get("knee_r") and not (L["palp"] and st.get("no_palp_knees")):
            cv.dot(L["knee"], st["knee_r"] * (0.7 if L["palp"] else 1.0), PAL["joint"])
        if st.get("foot_r") and not (L["palp"] and st.get("no_palp_feet")):
            cv.dot(L["foot"], st["foot_r"] * (0.67 if L["palp"] else 1.0), tint or PAL["joint"])

    if st.get("abdomen", True):
        cv.line(sp.head, sp.p, PAL["body"], lw)
        cv.line(sp.p, sp.abd, PAL["leg"], lw * 1.15)
        cv.line(sp.abd, sp.spin, PAL["leg"], lw)
    if st.get("connectors", True):
        for L in sp.legs:
            if not L["palp"] and L["idx"] % 2 == 0:
                cv.line(sp.abd, L["hip"], rgba(PAL["leg"], 0.45), st.get("conn_w", lw * 0.5))

    bw = st["box_w"]
    outer = sp.box(bw / 2)
    inner = sp.box(-bw / 2)
    cv.poly(sp.box(0), PAL["bodyFill"])
    cv.quad_frame(outer, inner, PAL["body"])
    if st.get("head_r"):
        cv.dot(sp.head, st["head_r"], PAL["joint"])
    if st.get("abd_r") and st.get("abdomen", True):
        cv.dot(sp.abd, st["abd_r"], PAL["joint"])
        cv.dot(sp.spin, st["spin_r"], PAL["joint"])


# --------------------------------------------------------------------------
# icons
# --------------------------------------------------------------------------
ICON_SPECS = {
    # tile: (x0, y0, x1, y1, radius) px. inset: spider margin inside the tile.
    # ext: per-leg extension (foot distance / reach); legs 1-2 nearly straight so the
    # side femurs don't merge into one bar, legs 0 and 3 keep a visible knee (and the
    # knee dots don't line up into a ladder).
    128: dict(tile=(16, 16, 112, 112, 21), inset=6.0, border=1.3, rows=True,
              legs=(0, 1, 2, 3), palps=True, body_k=1.9, abd_k=1.25, lw=2.6, box_w=1.7,
              ext={0: 1.04, 1: 1.14, 2: 1.10, 3: 1.0},
              knee_r=2.5, foot_r=2.3, head_r=2.5, abd_r=2.7, spin_r=2.1,
              no_palp_knees=True, connectors=False),
    48: dict(tile=(1, 1, 47, 47, 9.5), inset=2.6, border=1.0,
             legs=(0, 1, 2, 3), palps=False, body_k=2.0, abd_k=1.2, lw=1.7, box_w=1.15,
             ext={0: 1.04, 1: 1.14, 2: 1.10, 3: 1.0},
             knee_r=1.15, foot_r=1.05, head_r=1.35, abd_r=1.25, spin_r=0.0, connectors=False),
    32: dict(tile=(0, 0, 32, 32, 6.5), inset=2.0, border=1.0, snap=True,
             box_rect=(14.5, 13.5, 17.5, 19.5), head_at=(16.0, 12.0),
             legs=(0, 1, 2, 3), palps=False, body_k=2.15, abd_k=1.0, lw=1.3, box_w=1.0,
             ext={0: 1.04, 1: 1.14, 2: 1.10, 3: 1.0},
             knee_r=0.95, foot_r=0.0, head_r=1.2, abd_r=0.0, spin_r=0.0, connectors=False),
    16: dict(tile=(0, 0, 16, 16, 3.5), inset=0.9, border=0.0, snap=True,
             box_rect=(6.5, 6.5, 9.5, 10.5), head_at=(8.0, 5.0),
             legs=(0, 1, 2), leg_def=TINY_LEGS, palps=False, body_k=2.4, lw=1.1, box_w=1.0,
             ext={0: 1.1, 1: 1.16, 2: 1.1},
             knee_r=0.0, foot_r=0.0, head_r=1.05, abd_r=0.0, spin_r=0.0, connectors=False, abdomen=False),
}
ICON_SS = 8


def icon_tile(cv: Canvas, spec):
    x0, y0, x1, y1, rad = spec["tile"]
    s = cv.ss
    # near-black tile with a faint deep-blue lift at the top (reads on light AND dark toolbars)
    m, xy = cv._mask((x0, y0, x1, y1),
                     lambda d, X, s_: d.rounded_rectangle(R(X, x0, y0, x1, y1), radius=rad * s, fill=255))
    hgt = m.height
    t = np.linspace(0, 1, hgt)[:, None, None]
    top = np.array([13, 18, 40], float)
    k = (1 - t) ** 1.8
    col = np.broadcast_to(top * k, (hgt, m.width, 3)).astype(np.uint8)
    layer = Image.fromarray(np.dstack([col, np.asarray(m)]), "RGBA")
    cv.im.alpha_composite(layer, xy)
    if spec["border"]:
        b = spec["border"]

        def ring(d, X, s_):
            d.rounded_rectangle(R(X, x0, y0, x1, y1), radius=rad * s, fill=255)
            d.rounded_rectangle(R(X, x0 + b, y0 + b, x1 - b, y1 - b), radius=max(0, rad - b) * s, fill=0)

        cv.paint((x0, y0, x1, y1), ring, rgba("#2e4290", 0.9))


def icon_spider(spec):
    x0, y0, x1, y1, _ = spec["tile"]
    kw = dict(body_k=spec["body_k"], abd_k=spec.get("abd_k"), legs=spec["legs"], palps=spec["palps"],
              knees="out", leg_def=spec.get("leg_def", HERO_LEGS), ext=spec.get("ext"))
    probe = Spider((0, 0), -math.pi / 2, 1.0, **kw).solve()
    pts = probe.points()
    lo, hi = pts.min(0), pts.max(0)
    ext = hi - lo
    edge = max(spec["lw"] / 2, spec["foot_r"], spec["knee_r"])  # stroke / dot overhang in px
    avail = min(x1 - x0, y1 - y0) - 2 * (spec["inset"] + edge)
    scale = avail / float(ext.max())
    c_tile = V((x0 + x1) / 2, (y0 + y1) / 2)
    c_pts = (lo + hi) / 2 * scale
    sp = Spider(c_tile - c_pts, -math.pi / 2, scale, **kw).solve()
    if spec.get("snap"):
        # tiny sizes: put knees and feet on pixel centres so straight runs of a leg
        # land on one pixel column/row instead of smearing over two
        pc = lambda q: np.floor(q) + 0.5
        for L in sp.legs:
            L["knee"] = pc(L["knee"])
            L["foot"] = pc(L["foot"])
        sp.head = V(spec["head_at"]) if "head_at" in spec else pc(sp.head)
        sp.box_rect = spec.get("box_rect")
    return sp


def icon_rows(cv: Canvas, sp: Spider, spec):
    """Faint 'lines of text' under the spider. The line grid is fitted to the feet,
    every foot stands on a word (nudged vertically onto its line, like findAnchor in
    the art) and some of those words light up the way the extension mutates them."""
    x0, y0, x1, y1, rad = spec["tile"]
    feet = [L for L in sp.legs if not L["palp"]]
    levels = sorted({round(float(L["foot"][1]), 2) for L in feet})
    top = levels[0]
    # line pitch that puts every foot level closest to a line
    pitch = min(np.arange(8.6, 11.0, 0.02),
                key=lambda p: max(abs((v - top) / p - round((v - top) / p)) * p for v in levels))
    ys = [top + k * pitch for k in range(-3, 20) if y0 + 5 <= top + k * pitch <= y1 - 5]
    hgt, gap, margin = 2.8, 2.6, 4.5

    def x_span(y):  # usable x range of a line inside the rounded tile
        cy = min(max(y, y0 + rad), y1 - rad)
        dy = abs(y - cy)
        dx = rad - math.sqrt(max(0.0, rad * rad - dy * dy))
        return x0 + dx + margin, x1 - dx - margin

    req = {}  # line index -> [(x0, x1, leg)]
    for L in feet:
        fy = float(L["foot"][1])
        r = min(range(len(ys)), key=lambda i: abs(ys[i] - fy))
        fx = float(L["foot"][0])
        L["foot"] = V(fx, ys[r])
        w = 11.0 if L["idx"] in (0, 3) else 9.0
        req.setdefault(r, []).append((fx - w * 0.42, fx + w * 0.58, L))
    sp.solve()

    widths = [9, 5, 13, 7, 4, 11, 6, 15, 8, 5, 10, 7, 12, 4, 9, 6, 14, 5]
    wi = 5
    marks = {(1, 0): ("box", PAL["blue"]), (-1, 3): ("hl", PAL["cyan"]),
             (-1, 1): ("box", PAL["magenta"]), (1, 2): ("box", PAL["mint"]),
             (-1, 0): ("hl", PAL["sky"])}
    for r, yy in enumerate(ys):
        lo, hi = x_span(yy)
        fixed = sorted(req.get(r, []), key=lambda t: t[0])
        ragged = (r % 4 == 2) and not any(f[1] > hi - 22 for f in fixed)  # paragraph end
        stop = hi - 22 if ragged else hi
        plain, lit = [], []
        x = lo + (4 if r % 3 == 1 else 0)
        for fx0, fx1, L in fixed + [(stop + gap, stop + gap, None)]:
            while x + 4 <= fx0 - gap:  # filler words up to the next foot word
                w = min(widths[wi % len(widths)], fx0 - gap - x)
                wi += 1
                if w >= 3:
                    plain.append((x, w))
                x += w + gap
            if L is not None:
                mark = marks.get((L["side"], L["idx"]))
                if mark:
                    lit.append((fx0, fx1 - fx0, mark))
                else:
                    plain.append((fx0, fx1 - fx0))
                x = fx1 + gap
        for bx, bw in plain:
            cv.rounded(bx, yy - hgt / 2, bx + bw, yy + hgt / 2, hgt / 2, rgba("#9aa4c0", 0.15))
        for bx, bw, (kind, col) in lit:
            bx0, by0, bx1, by1 = bx - 0.7, yy - hgt / 2 - 1.0, bx + bw + 0.7, yy + hgt / 2 + 1.0
            if kind == "hl":
                cv.rect(bx0, by0, bx1, by1, rgba(col, 0.92))
            else:
                cv.rounded(bx, yy - hgt / 2, bx + bw, yy + hgt / 2, hgt / 2, rgba("#9aa4c0", 0.3))
                cv.frame(bx0, by0, bx1, by1, col, 1.0)


def make_icon(size: int) -> Image.Image:
    spec = ICON_SPECS[size]
    cv = Canvas(size, size, ICON_SS)
    icon_tile(cv, spec)
    sp = icon_spider(spec)
    if spec.get("rows"):
        icon_rows(cv, sp, spec)
    draw_spider(cv, sp, spec)
    return cv.final()


# --------------------------------------------------------------------------
# faux page text
# --------------------------------------------------------------------------
PARAS = [
    "Every page is a landscape of small words. A careful spider crosses it slowly, "
    "testing each line with the tip of one foot before it trusts its weight to the next. "
    "Where a foot lands, the word wakes up for a moment: it glows, it shifts, it echoes, "
    "and then it settles back exactly as it was.",
    "Silk is drawn out behind it in thin bright threads, anchored to a verb here and a noun "
    "there, so the path can be found again. Nothing on the page is changed and nothing is "
    "carried away; the spider only reads, and the words remember being read.",
    "Eight legs, one small box of a body, a pair of feelers held out in front. It never hurries. "
    "It reads the margins, the captions, the long quiet sentences in the middle of the page, "
    "and when you call it back it simply lets go of the last word and is gone.",
]
LINKS = {"landscape", "silk", "threads", "margins", "captions"}


def layout_text(cv: Canvas, region, px, lh, paras=PARAS, para_gap=0.55, indent=0.0, heading=None,
                alpha=(0.82, 0.66, 0.95)):
    """Greedy word wrap. Returns list of word dicts (output px)."""
    x0, y0, x1, y1 = region
    words = []
    y = y0
    if heading:
        hpx = px * 1.45
        y += hpx
        words.append(dict(text=heading, x=x0, base=y, w=cv.text_len(heading, "sansB", hpx), px=hpx,
                          kind="sansB", color=rgba(PAL["fg"], alpha[0]), heading=True, para=-1, line=-1))
        y += px * 0.55
        words.append(dict(rule=(x0, y, x1, y), heading=True))
        y += lh * 0.35
    space = cv.text_len(" ", "sans", px)
    line = 0
    for pi, para in enumerate(paras):
        x = x0 + indent
        y += lh * 0.78
        if y > y1:
            break
        for w in para.split():
            wl = cv.text_len(w, "sans", px)
            if x + wl > x1 and x > x0:
                x = x0
                y += lh
                line += 1
                if y > y1:
                    break
            bare = w.strip(".,;:").lower()
            color = rgba(PAL["link"], alpha[2]) if bare in LINKS else rgba(PAL["fg"], alpha[1])
            words.append(dict(text=w, x=x, base=y, w=wl, px=px, kind="sans", color=color,
                              para=pi, line=line, heading=False))
            x += wl + space
        else:
            y += lh * (0.22 + para_gap)
            line += 1
            continue
        break
    for wd in words:
        if "rule" in wd:
            continue
        p = wd["px"]
        wd["box"] = (wd["x"], wd["base"] - p * 0.80, wd["x"] + wd["w"], wd["base"] + p * 0.26)
    return words


def anchor_on(word, target):
    """Closest point to `target` inside the word's anchor zone (crawler.js findAnchor: u .08-.92, v .25-.75)."""
    x0, y0, x1, y1 = word["box"]
    w, h = x1 - x0, y1 - y0
    ax0, ax1 = x0 + 0.08 * w, x0 + 0.92 * w
    ay0, ay1 = y0 + 0.25 * h, y0 + 0.75 * h
    return V(min(max(target[0], ax0), ax1), min(max(target[1], ay0), ay1))


def plant_feet(sp: Spider, words, lifted=(), reach_frac=0.86):
    """Snap every foot's rest position to the nearest word (feet stand on real text)."""
    body = [w for w in words if "box" in w and not w.get("heading")]
    for L in sp.legs:
        key = (L["side"], L["idx"])
        if key in lifted:
            hp, f = L["hip"], L["rest"]
            L["foot"] = f + (hp - f) * 0.22  # mid-step: lifted and pulled in
            L["lifted"] = True
            L["word"] = None
            continue
        best, bd = None, 1e9
        for wd in body:
            a = anchor_on(wd, L["rest"])
            dd = float(np.hypot(*(a - L["rest"])))
            if float(np.hypot(*(a - L["hip"]))) > (L["L1"] + L["L2"]) * reach_frac:
                continue
            if dd < bd:
                best, bd = (wd, a), dd
        if best:
            L["word"], L["foot"] = best[0], best[1]
    return sp.solve()


def find_word(words, text, nth=0):
    hits = [w for w in words if "box" in w and w["text"].strip(".,;:").lower() == text]
    return hits[nth] if len(hits) > nth else None


# --------------------------------------------------------------------------
# mutations (css/style.css .m-* classes, rendered as an overlay)
# --------------------------------------------------------------------------
def draw_words(cv: Canvas, words, muts: dict):
    for wd in words:
        if "rule" in wd:
            x0, y, x1, _ = wd["rule"]
            cv.rect(x0, y, x1, y + max(1.0, wd.get("rule_w", 1.0)), rgba(PAL["rule"], 0.9))
            continue
        m = muts.get(id(wd))
        if m and m["kind"] in ("big", "rot", "solid"):
            continue  # drawn later on top / replaces the word
        color = wd["color"]
        kind, px = wd["kind"], wd["px"]
        x, base = wd["x"], wd["base"]
        if m:
            x0, y0, x1, y1 = wd["box"]
            c = m.get("c")
            if m["kind"] == "hl":
                cv.rect(x0 - 1, y0, x1 + 1, y1, c)
                color = m.get("t", PAL["ink"])
            elif m["kind"] == "ink":
                color = c
                if m.get("mono"):  # monospace swap, shrunk to the word's own width
                    kind = "mono"
                    nw = cv.text_len(wd["text"], "mono", px)
                    if nw > wd["w"] * 1.04:
                        px = px * wd["w"] * 1.04 / nw
                        nw = cv.text_len(wd["text"], "mono", px)
                    x = x + (wd["w"] - nw) / 2
        cv.text(x, base, wd["text"], kind, px, color)
        if m:
            x0, y0, x1, y1 = wd["box"]
            c = m.get("c")
            k = m["kind"]
            lw = m.get("w", 1.0)
            if k == "box":
                o = m.get("off", 1.0)
                cv.frame(x0 - o, y0 - o, x1 + o, y1 + o, c, lw)
            elif k == "under":
                # wavy underline
                yb = base + px * 0.2
                amp, per = px * 0.08, px * 0.32
                pts = [(xx, yb + amp * math.sin((xx - x0) / per * 2 * math.pi))
                       for xx in np.linspace(x0, x1, max(8, int((x1 - x0) / 1.5)))]
                cv.polyline(pts, c, lw)
            elif k == "strike":
                ym = base - px * 0.3
                cv.line((x0, ym), (x1, ym), c, lw * 1.6)


def draw_word_overlays(cv: Canvas, words, muts: dict):
    for wd in words:
        m = muts.get(id(wd))
        if not m:
            continue
        x0, y0, x1, y1 = wd["box"]
        cxw, cyw = (x0 + x1) / 2, (y0 + y1) / 2
        if m["kind"] == "solid":
            cv.rect(x0 - 1, y0, x1 + 1, y1, m["c"])
        elif m["kind"] == "big":
            # .m-hl.m-mono.m-big.m-pad : monospace blow-up on a colour block
            px = wd["px"] * m.get("s", 1.8)
            txt = m.get("text", wd["text"].strip(".,;:"))
            tw = cv.text_len(txt, "monoB", px, m.get("track", 0.04))
            pad = 0.35 * px
            if m.get("align") == "left":  # grows to the right, like an inline blow-up
                bx0 = x0 - pad * 0.4
                bx1 = bx0 + tw + 2 * pad
            else:
                bx0, bx1 = cxw - tw / 2 - pad, cxw + tw / 2 + pad
            by0, by1 = cyw - px * 0.62, cyw + px * 0.58
            cv.rect(bx0, by0, bx1, by1, m["c"])
            cv.text(bx0 + pad, cyw + px * 0.36, txt, "monoB", px, m.get("t", "#ffffff"), tracking=m.get("track", 0.04))
        elif m["kind"] == "rot":
            px = wd["px"] * m.get("s", 1.3)
            txt = wd["text"].strip(".,;:")
            s = cv.ss
            f = font("mono", px * s)
            l, t, r, b = f.getbbox(txt, anchor="mm")
            lay = Image.new("RGBA", (int(r - l) + 8, int(b - t) + 8), (0, 0, 0, 0))
            ImageDraw.Draw(lay).text((lay.width / 2, lay.height / 2), txt, font=f, fill=rgba(m["c"]), anchor="mm")
            cv.paste_rotated(lay, (cxw, cyw), m.get("deg", 90))


def draw_bar(cv: Canvas, a, b, h, color, txt, txt_color, px):
    """crawler.js bar(): a word's text stretched along a line from that word to the body.
    The text is kept upright (reads left to right whatever the direction)."""
    a, b = V(a), V(b)
    if b[0] < a[0]:
        a, b = b, a
    d = b - a
    L = float(np.hypot(*d))
    ang = math.degrees(math.atan2(d[1], d[0]))
    s = cv.ss
    W, H = int(L * s), int(h * s)
    lay = Image.new("RGBA", (W, H), rgba(color))
    f = font("mono", px * s)
    dr = ImageDraw.Draw(lay)
    tx = 0.35 * px * s
    adv = f.getlength(txt + "   ")
    while tx < W:
        dr.text((tx, H / 2), txt, font=f, fill=rgba(txt_color), anchor="lm")
        tx += adv
    cv.paste_rotated(lay, (a + b) / 2, -ang)


def glow_under(base: Image.Image, top: Image.Image, radius: float, strength: float) -> Image.Image:
    """Composite `top` over `base` with a soft neon glow of `top` underneath."""
    g = top.filter(ImageFilter.GaussianBlur(radius))
    a = np.asarray(g, np.float32).copy()
    a[..., 3] = np.clip(a[..., 3] * strength, 0, 255)
    g = Image.fromarray(a.astype(np.uint8), "RGBA")
    out = base.copy()
    out.alpha_composite(g)
    out.alpha_composite(top)
    return out


# --------------------------------------------------------------------------
# promo scenes
# --------------------------------------------------------------------------
GLYPH = "/[•]\\"


def title_block(cv: Canvas, x, y_glyph, glyph_px, title_px, tag_px, tag_lines, tag_gap=1.55):
    """Glyph '/[•]\\', stacked title 'Web / Crawlers', tagline + cursor block."""
    gcol = [PAL["leg"], PAL["body"], PAL["joint"], PAL["body"], PAL["leg"]]
    adv = cv.text_len("M", "monoB", glyph_px)
    for i, ch in enumerate(GLYPH):
        cv.text(x + i * adv, y_glyph, ch, "monoB", glyph_px, gcol[i])
    y = y_glyph + title_px * 1.06
    for t in ("Web", "Crawlers"):
        cv.text(x - title_px * 0.03, y, t, "monoB", title_px, PAL["white"])
        y += title_px * 0.98
    y += tag_px * tag_gap - title_px * 0.98
    for i, t in enumerate(tag_lines):
        cv.text(x, y, t, "mono", tag_px, PAL["dim"])
        if i == len(tag_lines) - 1:
            cx = x + cv.text_len(t + " ", "mono", tag_px)
            cv.rect(cx, y - tag_px * 0.76, cx + tag_px * 0.55, y + tag_px * 0.14, PAL["leg"])
        y += tag_px * 1.4
    return y


def scene(W, H, cfg, debug=False) -> Image.Image:
    ss = cfg["ss"]
    bg = Canvas(W, H, ss, bg="#000000")
    fx = Canvas(W, H, ss)  # spider + silk on their own layer (they get the glow)

    words = layout_text(bg, cfg["text_region"], cfg["px"], cfg["lh"], heading=cfg.get("heading"),
                        alpha=cfg.get("text_alpha", (0.82, 0.66, 0.95)))
    for wd in words:
        if "rule" in wd:
            wd["rule_w"] = cfg.get("rule_w", 1.0)

    sc = cfg["scale"]
    DR = sc ** 0.6
    sp = Spider(cfg["spider_at"], cfg["heading_ang"], sc, body_k=cfg["body_k"], abd_k=cfg.get("abd_k"),
                abd_swing=cfg.get("abd_swing", 0.0), knees="out", leg_def=PROMO_LEGS, ext=cfg["ext"])
    # walking gait: tetrapod stride offsets along the heading (units)
    for L in sp.legs:
        L["rest"] = L["rest"] + sp.fwd * cfg["gait"].get((L["side"], L["idx"]), 0.0) * sc
    plant_feet(sp, words, lifted=cfg["lifted"])

    if debug:
        for L in sp.legs:
            w = L.get("word")
            print(L["side"], L["idx"], np.round(L["foot"]), w and w["text"])
        print("p", np.round(sp.p), "spin", np.round(sp.spin))
        for wd in words:
            if "box" in wd:
                print(f'{wd["text"]:>12} {wd["x"]:7.1f} {wd["base"]:6.1f}')

    muts = {}
    for key, m in cfg["foot_muts"].items():
        L = sp.leg(*key)
        if L.get("word") is not None:
            muts[id(L["word"])] = dict(m)
    for (txt, nth), m in cfg["word_muts"].items():
        wd = find_word(words, txt, nth)
        if wd is None:
            print("  (missing word)", txt, nth)
        elif id(wd) not in muts:
            muts[id(wd)] = dict(m)

    draw_words(bg, words, muts)

    for b in cfg.get("bars", []):  # silk bars: word -> body
        wd = find_word(words, *b["word"])
        a = anchor_on(wd, sp.p)
        draw_bar(bg, a, sp.p, b["h"], b["c"], b["text"], b.get("t", "#ffffff"), b["px"])

    for g in cfg.get("ghosts", []):  # ghost echoes: enlarged mono copies, offset
        wd = find_word(words, *g["word"])
        txt = g.get("text", wd["text"].strip(".,;:"))
        bg.text(wd["x"] + g["dx"], wd["base"] + g["dy"], txt, "mono", g["px"], g["c"], tracking=g.get("track", 0.0))

    draw_word_overlays(bg, words, muts)

    for (txt, nth), col in cfg.get("threads", []):  # silk threads from the spinneret
        wd = find_word(words, txt, nth)
        if wd is None:
            print("  (missing thread word)", txt, nth)
            continue
        end = anchor_on(wd, sp.spin)
        fx.line(sp.spin, end, col, cfg["thread_w"])
        fx.dot(end, cfg["thread_tip"], col)

    for key, t in cfg.get("flashes", {}).items():  # plant flashes
        fx.ring(sp.leg(*key)["foot"], (3 + t * 9) * DR, rgba(PAL["joint"], 1 - t), cfg["thread_w"])

    st = dict(cfg["style"])
    dk = st.pop("dot_k", 1.0)
    st.update(knee_r=2.3 * DR * dk, foot_r=2.1 * DR * dk, head_r=2.2 * DR * dk,
              abd_r=2.8 * DR * dk, spin_r=2.0 * DR * dk)
    draw_spider(fx, sp, st)

    title_block(bg, **cfg["title"])

    return glow_under(bg.final(), fx.final(), cfg["glow_r"], cfg["glow_k"])


GAIT = {(1, 0): 6, (-1, 1): 6, (1, 2): 6, (-1, 3): 6,
        (-1, 0): -5, (1, 1): -5, (-1, 2): -5, (1, 3): -5}
# promo pose: legs 1/2 fanned further apart and kept nearly straight so their knees
# (which bow towards each other in the "out" convention) never cross
PROMO_LEGS = [(0.45, 112, 7), (0.98, 104, 3), (2.12, 104, -1), (2.68, 108, -5)]
HERO_EXT = {0: 1.06, 1: 1.15, 2: 1.15, 3: 1.04}


def marquee_cfg():
    sc = 1.9
    return dict(
        ss=4,
        text_region=(650, 58, 1340, 530), px=19.5, lh=31.5, text_alpha=(0.62, 0.52, 0.8),
        heading="Field notes on walking over words", rule_w=1.2,
        spider_at=(1000, 290), heading_ang=math.pi / 2 + 0.25, scale=sc, body_k=1.5, abd_k=1.25,
        abd_swing=-0.2, ext=HERO_EXT, gait=GAIT, lifted=set(),
        foot_muts={
            (1, 0): dict(kind="box", c=PAL["blue"], w=1.6, off=2.0),
            (-1, 0): dict(kind="hl", c=PAL["cyan"], t=PAL["ink"]),
            (-1, 1): dict(kind="box", c=PAL["magenta"], w=1.6, off=2.0),
            (1, 1): dict(kind="box", c=PAL["mint"], w=1.6, off=3.0),
            (-1, 2): dict(kind="hl", c=PAL["mint"], t="#04140a"),
            (1, 2): dict(kind="hl", c=PAL["sky"], t=PAL["ink"]),
            (-1, 3): dict(kind="box", c=PAL["red"], w=1.6, off=2.0),
            (1, 3): dict(kind="ink", c=PAL["yellow"], mono=True),
            (1, 4): dict(kind="ink", c=PAL["cyan"], mono=True),
            (-1, 4): dict(kind="under", c=PAL["orange"], w=1.8),
        },
        word_muts={
            ("read", 0): dict(kind="big", c=PAL["magenta"], s=2.1, t="#ffffff", text="read", align="left"),
            ("shifts", 0): dict(kind="rot", c=PAL["sky"], s=1.15, deg=90),
            ("small", 0): dict(kind="box", c=PAL["red"], w=1.5, off=2.0),
            ("echoes", 0): dict(kind="box", c=PAL["purple"], w=1.5, off=2.0),
            ("captions", 0): dict(kind="box", c=PAL["white"], w=1.4, off=2.0),
            ("eight", 0): dict(kind="box", c=PAL["blue"], w=1.5, off=3.0),
            ("exactly", 0): dict(kind="solid", c="#4f7dff"),
        },
        bars=[dict(word=("remember", 0), h=21, c=(255, 60, 200, 200), text="remember", px=14)],
        ghosts=[dict(word=("sentences", 0), dx=-330, dy=63, px=34, text="sentences",
                     c=rgba(PAL["sky"], 0.5), track=0.32)],
        threads=[(("landscape", 0), PAL["purple"]), (("verb", 0), PAL["orange"]),
                 (("next", 0), PAL["yellow"])],
        thread_w=1.5, thread_tip=2.6,
        flashes={(1, 0): 0.35, (-1, 3): 0.6},
        style=dict(lw=3.0, box_w=2.2, conn_w=1.4, connectors=True, dot_k=1.12),
        glow_r=8, glow_k=0.7,
        title=dict(x=96, y_glyph=150, glyph_px=48, title_px=104, tag_px=27, tag_gap=1.95,
                   tag_lines=["a spider that walks", "on the page you read"]),
    )


def small_cfg():
    sc = 0.98
    return dict(
        ss=6,
        text_region=(234, 24, 426, 266), px=9.6, lh=15.4, text_alpha=(0.62, 0.55, 0.85),
        heading=None,
        spider_at=(332, 138), heading_ang=math.pi / 2 + 0.25, scale=sc, body_k=1.6, abd_k=1.3,
        abd_swing=-0.2, ext=HERO_EXT, gait=GAIT, lifted=set(),
        foot_muts={
            (1, 0): dict(kind="box", c=PAL["blue"], w=1.1, off=1.3),
            (-1, 0): dict(kind="hl", c=PAL["cyan"], t=PAL["ink"]),
            (-1, 1): dict(kind="box", c=PAL["magenta"], w=1.1, off=1.3),
            (1, 1): dict(kind="box", c=PAL["mint"], w=1.1, off=1.8),
            (-1, 2): dict(kind="hl", c=PAL["mint"], t="#04140a"),
            (1, 2): dict(kind="hl", c=PAL["sky"], t=PAL["ink"]),
            (-1, 3): dict(kind="box", c=PAL["red"], w=1.1, off=1.3),
            (1, 3): dict(kind="ink", c=PAL["yellow"], mono=True),
        },
        word_muts={
            ("word", 0): dict(kind="big", c=PAL["magenta"], s=2.0, t="#ffffff", text="word", align="left"),
            ("echoes", 0): dict(kind="box", c=PAL["purple"], w=1.0, off=1.3),
            ("exactly", 0): dict(kind="solid", c="#4f7dff"),
        },
        bars=[dict(word=("noun", 0), h=10, c=(255, 60, 200, 200), text="noun", px=7.2)],
        ghosts=[],
        threads=[(("landscape", 0), PAL["purple"]), (("lands", 0), PAL["orange"])],
        thread_w=0.9, thread_tip=1.5,
        flashes={(1, 0): 0.4},
        style=dict(lw=1.9, box_w=1.25, conn_w=0.8, connectors=True, dot_k=1.0),
        glow_r=3.5, glow_k=0.65,
        title=dict(x=24, y_glyph=73, glyph_px=24, title_px=44, tag_px=15, tag_gap=1.85,
                   tag_lines=["a spider that walks", "on the page you read"]),
    )


# --------------------------------------------------------------------------
# review sheet
# --------------------------------------------------------------------------
def preview_sheet(icons: dict) -> Image.Image:
    W, H = 760, 470
    cv = Canvas(W, H, 2, bg="#000000")
    rows = [("light toolbar  #f1f3f4", "#f1f3f4", "#5f6368"), ("dark toolbar  #202124", "#202124", "#9aa0a6"),
            ("black page  #000000", "#000000", "#9aa0a6")]
    rh = 150
    for r, (label, col, lab) in enumerate(rows):
        y0 = 10 + r * (rh + 2)
        cv.rect(10, y0, W - 10, y0 + rh, col)
        cv.text(24, y0 + 22, label, "mono", 12, lab)
    img = cv.final()
    for r in range(len(rows)):
        y0 = 10 + r * (rh + 2)
        x = 30
        for size in (128, 48, 32, 16):
            ic = icons[size]
            img.alpha_composite(ic, (x, y0 + 12 + (128 - size) // 2 + 6))
            x += size + 28
        # pixel zoom (nearest) of the small sizes: 32 @3x, 16 @4x
        x += 18
        for size in (32, 16):
            z = icons[size].resize((size * 4 if size == 16 else size * 3,) * 2, Image.NEAREST)
            img.alpha_composite(z, (x, y0 + 12 + (128 - z.height) // 2 + 6))
            x += z.width + 24
    d = ImageDraw.Draw(img)
    f = font("mono", 11)
    for r, (_, col, lab) in enumerate(rows):
        y0 = 10 + r * (rh + 2)
        x = 30
        for size in (128, 48, 32, 16):
            d.text((x, y0 + rh - 12), f"{size}", font=f, fill=lab)
            x += size + 28
        x += 18
        d.text((x, y0 + rh - 12), "32 @3x", font=f, fill=lab)
        d.text((x + 96 + 24, y0 + rh - 12), "16 @4x", font=f, fill=lab)
    return img


# --------------------------------------------------------------------------
def save(img: Image.Image, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    print(f"  {path.relative_to(EXT.parent)}  {img.width}x{img.height}")


def main():
    print("icons")
    icons = {}
    for size in (16, 32, 48, 128):
        icons[size] = make_icon(size)
        save(icons[size], ICON_DIR / f"icon{size}.png")
    print("store")
    save(scene(440, 280, small_cfg()).convert("RGB"), STORE_DIR / "promo-small-440x280.png")
    save(scene(1400, 560, marquee_cfg()).convert("RGB"), STORE_DIR / "promo-marquee-1400x560.png")
    save(preview_sheet(icons).convert("RGB"), STORE_DIR / "icon-preview.png")


if __name__ == "__main__":
    main()
