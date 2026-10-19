.pragma library

// Shared numbers for the equalizer card (EqualizerPopup.qml and its Pad*.qml
// parts). Everything is in the screen's own design pixels: the chart is
// 460 x 270, ten lanes of 46 at the bottom edge, narrowing toward the top like a
// rhythm game's highway.

var TOP = 34        // top of the lanes
var BOT = 234       // the judgement line (the lowest edge of the lanes)
var ZERO = 134      // where 0 dB sits
var PER_DB = 8      // pixels for one dB
var LW = 46         // a lane's width at the bottom
var CX = 230        // the middle of the screen

// (The colours of the three groups, bass / mids / treble, follow the theme now:
// modules/common/PadPalette.qml has groups, groupsLight and groupsDark.)
var HZ = ["32 Hz", "63 Hz", "125 Hz", "250 Hz", "500 Hz", "1 kHz", "2 kHz", "4 kHz", "8 kHz", "16 kHz"]
var LABELS = ["32", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]

function group(i) {
    return i < 2 ? 0 : (i < 7 ? 1 : 2)
}

function mix(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
}

// How much narrower the highway is at height y (1 at the bottom).
function s(y) {
    return 0.74 + 0.26 * (y - TOP) / (BOT - TOP)
}

function laneX(i, y) {
    return CX + (23 + i * LW - CX) * s(y)
}

function laneEdge(i, y) {
    return CX + (i * LW - CX) * s(y)
}

function gainToY(g) {
    return ZERO - g * PER_DB
}

function yToGain(y, range) {
    var g = (ZERO - y) / PER_DB
    return Math.max(-range, Math.min(range, g))
}

// Which lane a point is over (-1: none).
function laneAt(x, y) {
    var yy = Math.max(TOP, Math.min(BOT, y))
    var i = Math.floor((x - CX) / (LW * s(yy)) + 5)
    return (i < 0 || i > 9) ? -1 : i
}

// A smooth line through points (Catmull-Rom as bezier), drawn onto a canvas context.
function smooth(ctx, pts) {
    ctx.moveTo(pts[0].x, pts[0].y)
    for (var i = 0; i < pts.length - 1; i++) {
        var p0 = pts[Math.max(i - 1, 0)]
        var p1 = pts[i]
        var p2 = pts[i + 1]
        var p3 = pts[Math.min(i + 2, pts.length - 1)]
        ctx.bezierCurveTo(p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6,
                          p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6,
                          p2.x, p2.y)
    }
}

function rr(ctx, x, y, w, h, r) {
    ctx.roundedRect(x, y, w, h, r, r)
}

// "#rrggbb" + alpha -> "rgba(r,g,b,a)" for canvas styles.
function rgba(hex, a) {
    var n = parseInt(hex.slice(1), 16)
    return "rgba(" + ((n >> 16) & 255) + "," + ((n >> 8) & 255) + "," + (n & 255) + "," + a + ")"
}

// A QML colour (r, g, b, a in 0..1) -> "rgba(r,g,b,a)" for canvas styles.
function css(c) {
    return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + c.a + ")"
}

// A QML colour with its alpha set to `a` (0..1), as a canvas style.
function alpha(c, a) {
    return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")"
}

// mix() of two QML colours, as a canvas style.
function mixCss(a, b, t) {
    return css(mix(a, b, t))
}

// The matrix that tilts a w x h card about its middle: `ax` degrees about the
// vertical axis (positive: the right edge goes away), `ay` about the horizontal
// one (positive: the bottom edge goes away), seen with a little perspective
// (`d` is the eye's distance in pixels). Plain 4 x 4 multiplication, row-major.
function mul4(a, b) {
    var r = []
    for (var i = 0; i < 4; i++)
        for (var j = 0; j < 4; j++) {
            var v = 0
            for (var k = 0; k < 4; k++)
                v += a[i * 4 + k] * b[k * 4 + j]
            r.push(v)
        }
    return r
}

function tilt(w, h, ax, ay, d) {
    var a = ax * Math.PI / 180, b = -ay * Math.PI / 180
    var ca = Math.cos(a), sa = Math.sin(a), cb = Math.cos(b), sb = Math.sin(b)
    var cx = w / 2, cy = h / 2
    var ry = [ca, 0, sa, 0,   0, 1, 0, 0,   -sa, 0, ca, 0,   0, 0, 0, 1]
    var rx = [1, 0, 0, 0,   0, cb, -sb, 0,   0, sb, cb, 0,   0, 0, 0, 1]
    var p = [1, 0, 0, 0,   0, 1, 0, 0,   0, 0, 1, 0,   0, 0, -1 / d, 1]
    var tIn = [1, 0, 0, -cx,   0, 1, 0, -cy,   0, 0, 1, 0,   0, 0, 0, 1]
    var tOut = [1, 0, 0, cx,   0, 1, 0, cy,   0, 0, 1, 0,   0, 0, 0, 1]
    var m = mul4(tOut, mul4(p, mul4(rx, mul4(ry, tIn))))
    return Qt.matrix4x4(m[0], m[1], m[2], m[3], m[4], m[5], m[6], m[7],
                        m[8], m[9], m[10], m[11], m[12], m[13], m[14], m[15])
}
