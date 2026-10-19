.pragma library

// Tiny 4x4 matrix helpers for PhoneBody.qml. Matrices are plain arrays of
// 16 numbers, row-major, used with column vectors (p' = M * p) — the same
// layout Qt.matrix4x4(...) takes, so a result goes straight into a
// Matrix4x4 { matrix: ... } transform.
//
// Coordinate system: x right, y down (like the screen), z toward the
// viewer. The phone's front face sits at z = 0 and its body extends
// backwards to z = -thickness.

function ident() {
    return [1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1]
}

function mul(a, b) {
    var r = new Array(16)
    for (var i = 0; i < 4; i++) {
        for (var j = 0; j < 4; j++) {
            var s = 0
            for (var k = 0; k < 4; k++)
                s += a[i * 4 + k] * b[k * 4 + j]
            r[i * 4 + j] = s
        }
    }
    return r
}

function trans(x, y, z) {
    return [1, 0, 0, x,  0, 1, 0, y,  0, 0, 1, z,  0, 0, 0, 1]
}

function rotX(deg) {
    var r = deg * Math.PI / 180, c = Math.cos(r), s = Math.sin(r)
    return [1, 0, 0, 0,  0, c, -s, 0,  0, s, c, 0,  0, 0, 0, 1]
}

function rotY(deg) {
    var r = deg * Math.PI / 180, c = Math.cos(r), s = Math.sin(r)
    return [c, 0, s, 0,  0, 1, 0, 0,  -s, 0, c, 0,  0, 0, 0, 1]
}

function rotZ(deg) {
    var r = deg * Math.PI / 180, c = Math.cos(r), s = Math.sin(r)
    return [c, -s, 0, 0,  s, c, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1]
}

// Perspective from a camera d units in front of the z = 0 plane: things
// nearer the camera (larger z) come out bigger, w = 1 - z / d.
function persp(d) {
    return [1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, -1 / d, 1]
}

// Squash z to 0 after projecting. Qt Quick clips against a very shallow
// depth range, so a tilted plane that keeps its real z can vanish; every
// layer here is flat on screen anyway and is ordered by painting order.
function flatZ() {
    return [1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 0, 0,  0, 0, 0, 1]
}

function apply(m, x, y, z) {
    var X = m[0] * x + m[1] * y + m[2] * z + m[3]
    var Y = m[4] * x + m[5] * y + m[6] * z + m[7]
    var W = m[12] * x + m[13] * y + m[14] * z + m[15]
    return { x: X / W, y: Y / W }
}

// Shortcut for mul(m, trans(0, 0, z)): a matrix times a pure Z-translation
// only ever changes the translation column (col 3 += z * col 2 of m) — see
// the derivation in PhoneBody.qml's matrixZ(), which is the hot path this
// exists for (one of these per depth slice, every frame the phone tilts).
// Same result as mul(m, trans(0, 0, z)), ~15x fewer multiplies and no
// array allocation for the throwaway translation matrix.
function zOffset(m, z) {
    return [m[0], m[1], m[2], m[3] + z * m[2],
            m[4], m[5], m[6], m[7] + z * m[6],
            m[8], m[9], m[10], m[11] + z * m[10],
            m[12], m[13], m[14], m[15] + z * m[14]]
}

// Where a point on the outline of the rounded front face lands, for every
// point we care about (used to find the on-screen bounds).
function outline(W, H, R) {
    var pts = []
    var cs = [[R, R, Math.PI], [W - R, R, 1.5 * Math.PI],
              [W - R, H - R, 0], [R, H - R, 0.5 * Math.PI]]
    for (var c = 0; c < cs.length; c++)
        for (var i = 0; i <= 8; i++) {
            var a = cs[c][2] + (i / 8) * Math.PI / 2
            pts.push([cs[c][0] + R * Math.cos(a), cs[c][1] + R * Math.sin(a)])
        }
    return pts
}

// The rotation + perspective for a pose, before anything is moved into
// place: takes a point of the flat design (x, y, z) to homogeneous screen
// coordinates around the phone's center.
//
// yaw   > 0 turns the right edge toward the viewer (so the right-hand
//         side of the body shows); pitch > 0 tips the bottom edge toward
//         the viewer. Yaw is applied last, about the screen's vertical
//         axis, which is what makes the vertical edges lean like the
//         reference render.
function core(W, H, T, yaw, pitch, roll, d) {
    var rot = mul(rotY(-yaw), mul(rotX(pitch), rotZ(roll)))
    return mul(persp(d), mul(rot, trans(-W / 2, -H / 2, T / 2)))
}

// Everything PhoneBody needs to place its layers at rest:
//   base    matrix taking a point of the flat design (x, y, z) to the
//           screen, with the phone's top-left projected bound moved to
//           (pad, pad)
//   w, h    size of that projected bound (plus the padding)
//   cx, cy  where the middle of the screen lands inside that bound
//   minX, minY, pad   what it took to get there (see baseFor)
function build(W, H, T, R, yaw, pitch, roll, d, pad) {
    var c = core(W, H, T, yaw, pitch, roll, d)

    var outl = outline(W, H, R)
    var minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9
    for (var zi = 0; zi < 2; zi++) {
        var z = zi === 0 ? 0 : -T
        for (var i = 0; i < outl.length; i++) {
            var p = apply(c, outl[i][0], outl[i][1], z)
            minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x)
            minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y)
        }
    }

    var mid = apply(c, W / 2, H / 2, 0)
    var off = trans(-minX + pad, -minY + pad, 0)
    return {
        base: mul(flatZ(), mul(off, c)),
        w: maxX - minX + 2 * pad,
        h: maxY - minY + 2 * pad,
        cx: mid.x - minX + pad,
        cy: mid.y - minY + pad,
        minX: minX, minY: minY, pad: pad
    }
}

// The same for a different pose (say, mid-animation), but placed with the
// offsets of the resting pose `rest` (a result of build) so the phone
// turns about the same spot instead of shifting and resizing.
function baseFor(W, H, T, yaw, pitch, roll, d, rest) {
    var c = core(W, H, T, yaw, pitch, roll, d)
    return mul(flatZ(), mul(trans(-rest.minX + rest.pad, -rest.minY + rest.pad, 0), c))
}

// Where the phone's outline lands (in the same coordinates as a resting
// pose from build) for some other pose — used to find how far it swings
// out past its resting bounds while it's tilted.
function boundsFor(W, H, T, R, yaw, pitch, roll, d, rest) {
    var b = baseFor(W, H, T, yaw, pitch, roll, d, rest)
    var outl = outline(W, H, R)
    var minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9
    for (var zi = 0; zi < 2; zi++) {
        var z = zi === 0 ? 0 : -T
        for (var i = 0; i < outl.length; i++) {
            var p = apply(b, outl[i][0], outl[i][1], z)
            minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x)
            minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y)
        }
    }
    return { minX: minX, maxX: maxX, minY: minY, maxY: maxY }
}

// Blend between color stops given as [t, r, g, b] with r/g/b in 0..255.
function ramp(stops, t) {
    if (t <= stops[0][0])
        return [stops[0][1], stops[0][2], stops[0][3]]
    for (var i = 1; i < stops.length; i++) {
        if (t <= stops[i][0]) {
            var a = stops[i - 1], b = stops[i]
            var f = (t - a[0]) / (b[0] - a[0])
            return [a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f]
        }
    }
    var l = stops[stops.length - 1]
    return [l[1], l[2], l[3]]
}
