.pragma library

// The maths behind the Calendar lockscreen's picture frames (LockCalendar.qml),
// kept free of QML so tests/lock-calendar-test/crop_unit.js can run it under node.
//
// The Calendar lockscreen cuts three frames out of the lockscreen wallpaper, like
// the monthly wallpapers it is modelled on (a wide frame, a tall one, a small close-up
// of another part). Where the frames sit on the screen is fixed (LockCalendar.qml).
// WHICH PART of the picture each one shows is decided here, from a tiny copy of the
// picture (scripts/wallpapers/lock-crop.sh):
//
//   parsePpm(text)             the tiny copy, read from the script's output
//   saliency(img)              how "interesting" each cell is (edges, colours that
//                              stand out from the rest, a little pull to the middle)
//   plan(grid, specs)          the best window for every frame, one after the other,
//                              each one avoiding the parts the earlier ones took
//   fixedPlan(aspect, specs)   the same windows without looking at the picture; what
//                              is used with "Fixed" crops or when there is no tiny copy
//
// A frame spec is { aspect, scale }: `aspect` is the frame's width / height, `scale`
// is how much of the picture's HEIGHT its window covers (smaller = closer-up). A
// window that would not fit the picture is shrunk to fit, keeping the frame's aspect.
// A window is { x, y, w, h } in fractions of the picture (0..1), the same for every
// picture size, so it can be applied to whatever size the picture is decoded at.

var GRID_SIDE = 96

function clamp(v, lo, hi) {
    v = Number(v)
    if (!isFinite(v))
        v = lo
    return Math.max(lo, Math.min(hi, v))
}

// ===== reading the tiny copy =====

// Plain-text PPM ("P3"): { w, h, rgb } with rgb = [r, g, b, r, g, b, ...] (0..255),
// or null for anything that is not one (or is not the size the script makes).
function parsePpm(text) {
    if (typeof text !== "string" || text.length < 12)
        return null
    var tok = text.replace(/#[^\n]*/g, " ").split(/\s+/)
    var t = []
    for (var i = 0; i < tok.length; i++) {
        if (tok[i] !== "")
            t.push(tok[i])
    }
    if (t.length < 4 || t[0] !== "P3")
        return null
    var w = parseInt(t[1], 10), h = parseInt(t[2], 10), mx = parseInt(t[3], 10)
    if (!(w >= 4 && h >= 4 && w <= 256 && h <= 256 && mx > 0 && mx <= 255 * 257))
        return null
    var n = w * h * 3
    if (t.length < 4 + n)
        return null
    var rgb = new Array(n)
    for (var k = 0; k < n; k++) {
        var v = parseInt(t[4 + k], 10)
        if (!isFinite(v))
            return null
        rgb[k] = Math.max(0, Math.min(255, Math.round(v * 255 / mx)))
    }
    return { w: w, h: h, rgb: rgb }
}

// ===== how interesting each cell is =====

function percentile(values, p) {
    var s = values.slice().sort(function (a, b) { return a - b })
    return s[Math.min(s.length - 1, Math.max(0, Math.floor(p * (s.length - 1))))]
}

function boxBlur(src, w, h) {
    var out = new Array(w * h)
    for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
            var sum = 0, cnt = 0
            for (var dy = -1; dy <= 1; dy++) {
                var yy = y + dy
                if (yy < 0 || yy >= h)
                    continue
                for (var dx = -1; dx <= 1; dx++) {
                    var xx = x + dx
                    if (xx < 0 || xx >= w)
                        continue
                    sum += src[yy * w + xx]
                    cnt++
                }
            }
            out[y * w + x] = sum / cnt
        }
    }
    return out
}

// img = { w, h, rgb } -> { w, h, sal } with sal[y * w + x] in 0..1.
// Edges (Sobel on the brightness) count most, then how far a cell's colour is from the
// picture's average colour (a subject usually differs from its background), then a
// soft pull to the middle so a flat picture still gets sensible frames.
function saliency(img) {
    var w = img.w, h = img.h, n = w * h
    var lum = new Array(n)
    var mr = 0, mg = 0, mb = 0
    for (var i = 0; i < n; i++) {
        var r = img.rgb[i * 3], g = img.rgb[i * 3 + 1], b = img.rgb[i * 3 + 2]
        lum[i] = (0.299 * r + 0.587 * g + 0.114 * b) / 255
        mr += r; mg += g; mb += b
    }
    mr /= n; mg /= n; mb /= n

    var edge = new Array(n), col = new Array(n)
    for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
            var xm = Math.max(0, x - 1), xp = Math.min(w - 1, x + 1)
            var ym = Math.max(0, y - 1), yp = Math.min(h - 1, y + 1)
            var a = lum[ym * w + xm], bb = lum[ym * w + x], c = lum[ym * w + xp]
            var d = lum[y * w + xm], f = lum[y * w + xp]
            var gg = lum[yp * w + xm], hh = lum[yp * w + x], ii = lum[yp * w + xp]
            var sx = (c + 2 * f + ii) - (a + 2 * d + gg)
            var sy = (gg + 2 * hh + ii) - (a + 2 * bb + c)
            var k = y * w + x
            edge[k] = Math.sqrt(sx * sx + sy * sy)
            var dr = img.rgb[k * 3] - mr, dg = img.rgb[k * 3 + 1] - mg, db = img.rgb[k * 3 + 2] - mb
            col[k] = Math.sqrt(dr * dr + dg * dg + db * db) / 441.67
        }
    }
    // Scale each to 0..1 by its 98th percentile (one bright speck must not flatten the
    // rest), with a floor so a nearly flat picture's noise is not blown up.
    var eMax = Math.max(0.15, percentile(edge, 0.98))
    var cMax = Math.max(0.08, percentile(col, 0.98))

    var sal = new Array(n)
    for (var y2 = 0; y2 < h; y2++) {
        for (var x2 = 0; x2 < w; x2++) {
            var k2 = y2 * w + x2
            var fx = x2 / (w - 1) - 0.5, fy = y2 / (h - 1) - 0.5
            var prior = Math.exp(-(fx * fx + fy * fy) / (2 * 0.3 * 0.3))
            sal[k2] = 0.55 * Math.min(1, edge[k2] / eMax)
                    + 0.30 * Math.min(1, col[k2] / cMax)
                    + 0.15 * prior
        }
    }
    sal = boxBlur(boxBlur(sal, w, h), w, h)
    return { w: w, h: h, sal: sal }
}

// ===== choosing the windows =====

// The window's size in the same units as w x h (floats): `scale` of the height, as wide
// as the frame's aspect makes it, shrunk (same aspect) if it does not fit.
function sizeIn(w, h, aspect, scale) {
    aspect = clamp(aspect, 0.2, 8)
    scale = clamp(scale, 0.05, 1)
    var wh = scale * h
    var ww = wh * aspect
    if (ww > w) {
        ww = w
        wh = ww / aspect
    }
    if (wh > h) {
        wh = h
        ww = wh * aspect
    }
    return { ww: ww, wh: wh }
}

function integral(sal, w, h) {
    var iw = w + 1
    var out = new Array(iw * (h + 1))
    for (var i = 0; i < out.length; i++)
        out[i] = 0
    for (var y = 0; y < h; y++) {
        var row = 0
        for (var x = 0; x < w; x++) {
            row += sal[y * w + x]
            out[(y + 1) * iw + (x + 1)] = out[y * iw + (x + 1)] + row
        }
    }
    return out
}

function boxSum(ii, w, x0, y0, x1, y1) {       // cells x0..x1-1, y0..y1-1
    var iw = w + 1
    return ii[y1 * iw + x1] - ii[y0 * iw + x1] - ii[y1 * iw + x0] + ii[y0 * iw + x0]
}

function overlap(ax, ay, aw, ah, bx, by, bw, bh) {
    var ox = Math.min(ax + aw, bx + bw) - Math.max(ax, bx)
    var oy = Math.min(ay + ah, by + bh) - Math.max(ay, by)
    return ox > 0 && oy > 0 ? ox * oy : 0
}

// The best window for each spec, in order: the first one takes the most interesting
// part, each later one the best part that is not (mostly) taken yet. grid is what
// saliency() returns. Always returns one valid window per spec.
function plan(grid, specs) {
    var w = grid.w, h = grid.h
    var ii = integral(grid.sal, w, h)
    var taken = []
    var out = []
    for (var s = 0; s < specs.length; s++) {
        var size = sizeIn(w, h, specs[s].aspect, specs[s].scale)
        var cw = Math.max(1, Math.min(w, Math.round(size.ww)))
        var ch = Math.max(1, Math.min(h, Math.round(size.wh)))
        var area = cw * ch
        var best = -1e9, bx = Math.floor((w - cw) / 2), by = Math.floor((h - ch) / 2)
        for (var y = 0; y + ch <= h; y++) {
            for (var x = 0; x + cw <= w; x++) {
                var mean = boxSum(ii, w, x, y, x + cw, y + ch) / area
                var shared = 0
                for (var t = 0; t < taken.length; t++)
                    shared += overlap(x, y, cw, ch, taken[t].x, taken[t].y, taken[t].w, taken[t].h) / area
                var score = mean * (1 - Math.min(0.9, 0.9 * shared))
                if (score > best + 1e-12) {
                    best = score
                    bx = x
                    by = y
                }
            }
        }
        taken.push({ x: bx, y: by, w: cw, h: ch })
        // The window keeps the frame's exact aspect (size is in floats), anchored at
        // the cell the search chose and pulled back inside the picture.
        out.push(window(w, h, bx, by, size.ww, size.wh))
    }
    return out
}

function window(w, h, x, y, ww, wh) {
    var nw = ww / w, nh = wh / h
    return { x: clamp(x / w, 0, 1 - nw), y: clamp(y / h, 0, 1 - nh), w: nw, h: nh }
}

// Where the windows sit without looking at the picture: the centre of each is a fixed
// spot (first: upper middle, second: lower middle, third: a lower detail), pulled
// back inside. `aspect` is the picture's width / height.
var FIXED_CENTERS = [[0.50, 0.36], [0.50, 0.66], [0.60, 0.74]]

function fixedPlan(aspect, specs) {
    aspect = clamp(aspect, 0.2, 8)
    var w = aspect, h = 1
    var out = []
    for (var s = 0; s < specs.length; s++) {
        var size = sizeIn(w, h, specs[s].aspect, specs[s].scale)
        var c = FIXED_CENTERS[s % FIXED_CENTERS.length]
        var x = c[0] * w - size.ww / 2
        var y = c[1] * h - size.wh / 2
        out.push(window(w, h, clamp(x, 0, w - size.ww), clamp(y, 0, h - size.wh), size.ww, size.wh))
    }
    return out
}

// How the three frames are cut: aspect comes from the frame's size on screen, scale is
// the part of the picture's height its window covers (wide: most of it; tall: a bit
// less; small: a close-up).
var FRAME_SCALES = [0.55, 0.72, 0.34]

function specsFor(aspects) {
    var out = []
    for (var i = 0; i < aspects.length; i++)
        out.push({ aspect: aspects[i], scale: FRAME_SCALES[i % FRAME_SCALES.length] })
    return out
}

// For the frame to draw a window: the size the whole picture is drawn at and where its
// corner goes, so the window just fills a frame of fw x fh (a window of a slightly
// different aspect is covered, never left with gaps). iw / ih is the picture's own
// aspect; returns { width, height, x, y } in the frame's pixels.
function place(win, iw, ih, fw, fh) {
    var aspect = ih > 0 ? iw / ih : 1
    // Width needed so the window's width covers the frame, and so its height does.
    var needW = fw / Math.max(0.0001, win.w)
    var needH = (fh / Math.max(0.0001, win.h)) * aspect
    var width = Math.max(needW, needH)
    var height = width / aspect
    var cx = (win.x + win.w / 2) * width
    var cy = (win.y + win.h / 2) * height
    var x = Math.min(0, Math.max(fw - width, fw / 2 - cx))
    var y = Math.min(0, Math.max(fh - height, fh / 2 - cy))
    return { width: width, height: height, x: x, y: y }
}
