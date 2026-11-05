.pragma library

// Colors of the shell computed from the pywal palette.
// A "theme" is only a recipe: which pywal colors play which role, and how the
// background and the surfaces are built. Nothing here costs anything at run time.

// ---------- color helpers (hex strings "#rrggbb") ----------
function parse(h) {
    h = String(h).replace("#", "")
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2]
    return [parseInt(h.substr(0, 2), 16) / 255, parseInt(h.substr(2, 2), 16) / 255, parseInt(h.substr(4, 2), 16) / 255]
}
function hex(r, g, b) {
    const f = v => { const n = Math.round(Math.max(0, Math.min(1, v)) * 255); return (n < 16 ? "0" : "") + n.toString(16) }
    return "#" + f(r) + f(g) + f(b)
}
function toHsl(h) {
    const c = parse(h), r = c[0], g = c[1], b = c[2]
    const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2
    let hh = 0, s = 0
    if (mx !== mn) {
        const d = mx - mn
        s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
        if (mx === r) hh = (g - b) / d + (g < b ? 6 : 0)
        else if (mx === g) hh = (b - r) / d + 2
        else hh = (r - g) / d + 4
        hh /= 6
    }
    return { h: hh, s: s, l: l }
}
function fromHsl(h, s, l) {
    h = ((h % 1) + 1) % 1
    s = Math.max(0, Math.min(1, s)); l = Math.max(0, Math.min(1, l))
    if (s === 0) return hex(l, l, l)
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q
    const t = x => { x = ((x % 1) + 1) % 1; return x < 1 / 6 ? p + (q - p) * 6 * x : x < 0.5 ? q : x < 2 / 3 ? p + (q - p) * (2 / 3 - x) * 6 : p }
    return hex(t(h + 1 / 3), t(h), t(h - 1 / 3))
}
function mix(a, b, t) {
    const x = parse(a), y = parse(b)
    return hex(x[0] + (y[0] - x[0]) * t, x[1] + (y[1] - x[1]) * t, x[2] + (y[2] - x[2]) * t)
}
function lightness(h) { return toHsl(h).l }
function chroma(h) { const c = parse(h); return Math.max(c[0], c[1], c[2]) - Math.min(c[0], c[1], c[2]) }
function relLum(h) {
    const f = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
    const c = parse(h)
    return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2])
}
function contrast(a, b) {
    const x = relLum(a), y = relLum(b)
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
}
function rotate(h, deg, sMin, l) {
    const c = toHsl(h)
    return fromHsl(c.h + deg / 360, Math.max(c.s, sMin || 0), l === undefined ? c.l : l)
}
function desat(h, k) { const c = toHsl(h); return fromHsl(c.h, c.s * k, c.l) }

// Moves the lightness away from the background until the contrast ratio is enough
function fit(col, bg, target) {
    if (contrast(col, bg) >= target) return col
    const c = toHsl(col), dir = toHsl(bg).l < 0.5 ? 1 : -1
    let l = c.l
    for (let i = 0; i < 40; i++) {
        l += dir * 0.02
        if (l > 0.95 || l < 0.05) break
        const n = fromHsl(c.h, c.s, l)
        if (contrast(n, bg) >= target) return n
    }
    return fromHsl(c.h, c.s, Math.max(0.05, Math.min(0.95, l)))
}

// ---------- the themes ----------
const THEMES = [
    { id: "classic",    name: "Classic",       hint: "As it always was" },
    { id: "vivid",      name: "Vivid",         hint: "The most saturated color" },
    { id: "complement", name: "Complementary", hint: "Opposite hue to the wallpaper" },
    { id: "triad",      name: "Triad",         hint: "Three balanced hues" },
    { id: "analog",     name: "Analogous",     hint: "Neighbouring hues, soft" },
    { id: "mono",       name: "Monochrome",    hint: "One single hue" },
    { id: "tinted",     name: "Tinted",        hint: "Surfaces take the accent" },
    { id: "sober",      name: "Sober",         hint: "Muted and neutral" },
    { id: "contrast",   name: "Contrast",      hint: "Pure black / white, sharp" },
    { id: "neon",       name: "Neon",          hint: "Saturation to the max" }
]

function list() { return THEMES }

// pal: { bg, fg, c: [color0..color15] }   light: true when the pywal scheme is a light one
function compute(pal, id, light) {
    const dark = !light
    const c = pal.c
    const bg0 = pal.bg, fg0 = pal.fg

    // colors ordered from the most to the least colorful (pywal colors 1..6)
    const cand = [c[1], c[2], c[3], c[4], c[5], c[6]].slice().sort((a, b) => chroma(b) - chroma(a))
    const v1 = cand[0], v2 = cand[1]
    const domH = toHsl(v1).h
    const gray = chroma(v1) < 0.15            // almost gray wallpaper: do not trust the hue too much
    const sBase = gray ? 0.55 : 0
    const Lacc = dark ? 0.64 : 0.38           // lightness of "built" accents
    const Lnote = dark ? 0.76 : 0.30
    const hsl = (h, s, l) => fromHsl(h, s, l)

    // defaults = Classic
    let r = {
        bg: bg0, fg: fg0, accent: c[4], note: c[5], danger: c[1],
        islandK: dark ? 0.5 : 0.35, tint: 0, borderCol: null, borderK: dark ? 0.10 : 0.14
    }

    if (id === "vivid") {
        r.accent = v1; r.note = v2
    } else if (id === "complement") {
        const h = domH + 0.5
        r.accent = hsl(h, Math.max(0.62, sBase), Lacc)
        r.note = hsl(h - 30 / 360, Math.max(0.55, sBase), Lnote)
        r.bg = hsl(h, 0.30, dark ? 0.10 : 0.93)
        r.borderCol = r.accent; r.borderK = 0.16
    } else if (id === "triad") {
        r.accent = hsl(domH + 1 / 3, Math.max(0.60, sBase), Lacc)
        r.note = hsl(domH + 2 / 3, Math.max(0.55, sBase), Lnote)
        r.bg = hsl(domH, 0.08, dark ? 0.09 : 0.94)
    } else if (id === "analog") {
        r.accent = hsl(domH + 30 / 360, Math.max(0.55, sBase), Lacc)
        r.note = hsl(domH - 30 / 360, Math.max(0.50, sBase), Lnote)
        r.bg = hsl(domH, 0.22, dark ? 0.10 : 0.93)
    } else if (id === "mono") {
        r.accent = hsl(domH, Math.max(0.75, sBase), Lacc)
        r.note = hsl(domH, 0.55, Lnote)
        r.danger = hsl(domH, 0.60, dark ? 0.55 : 0.42)
        r.bg = hsl(domH, 0.22, dark ? 0.09 : 0.94)
        r.fg = hsl(domH, 0.12, dark ? 0.90 : 0.12)
    } else if (id === "tinted") {
        r.accent = v1; r.note = v2
        r.bg = mix(bg0, v1, 0.18)
        r.tint = 0.12
        r.borderCol = v1; r.borderK = 0.35
    } else if (id === "sober") {
        r.accent = desat(c[4], 0.35); r.note = desat(c[5], 0.30); r.danger = desat(c[1], 0.45)
        r.bg = hsl(0, 0.02, dark ? 0.10 : 0.95)
        r.fg = hsl(0, 0.02, dark ? 0.82 : 0.20)
        r.borderK = dark ? 0.07 : 0.10
    } else if (id === "contrast") {
        r.bg = dark ? "#000000" : "#ffffff"
        r.fg = dark ? "#ffffff" : "#000000"
        r.accent = hsl(domH, Math.max(0.85, sBase), dark ? 0.68 : 0.32)
        r.note = hsl(domH + 0.5, 0.85, dark ? 0.72 : 0.30)
        r.danger = hsl(0, 0.9, dark ? 0.62 : 0.40)
        r.islandK = 0
        r.borderCol = r.fg; r.borderK = 0.30
    } else if (id === "neon") {
        r.accent = hsl(domH, 1.0, dark ? 0.62 : 0.40)
        r.note = hsl(domH + 60 / 360, 1.0, dark ? 0.66 : 0.40)
        r.danger = hsl(350 / 360, 1.0, dark ? 0.60 : 0.42)
        r.bg = hsl(240 / 360, 0.35, dark ? 0.06 : 0.97)
        r.borderCol = r.accent; r.borderK = 0.50
    }

    // readability
    const base = dark ? "#000000" : "#ffffff"
    let island = mix(r.bg, base, r.islandK)
    if (r.tint > 0) island = mix(island, r.accent, r.tint)
    if (contrast(r.fg, island) < 7) r.fg = dark ? "#f2f2f2" : "#141414"
    r.accent = fit(r.accent, island, 3.6)
    r.note = fit(r.note, island, 3.3)
    r.danger = fit(r.danger, island, 3.3)
    const fg = r.fg
    return {
        background: r.bg,
        foreground: fg,
        accent: r.accent,
        note: r.note,
        danger: r.danger,
        muted: mix(r.bg, fg, dark ? 0.45 : 0.58),
        island: island,
        islandHover: mix(island, fg, dark ? 0.10 : 0.08),
        surfaceSoft: mix(island, fg, dark ? 0.06 : 0.05),
        border: mix(island, r.borderCol || fg, r.borderK)
    }
}
