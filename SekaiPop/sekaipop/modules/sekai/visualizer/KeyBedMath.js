.pragma library

// The physics behind the visualizer's key-bed (SekaiVisualizer.qml).
//
// The picture is a sheet of keycaps with the album cover printed on it. The
// music does not light the keys, it PRESSES them: the sheet is a lattice of
// springs, every key is a mass joined to its four neighbours, and whatever
// happens in the song is a push on that lattice. A key that is pushed down
// pulls its neighbours down a little, then springs back past rest (the soft
// bottom-out and bounce of a good keyboard) and the dent runs outwards as a
// ripple. Nothing is drawn from "levels": what you see is the sheet's own
// motion, so every hit has the same weight and the same afterglow.
//
// Who pushes how (all in cell units, the sheet is `cols` x `rows`):
//
//   spectrum   twelve emitters along the bottom edge, one per lane (low on the
//              left). Each one rocks its patch of the sheet at its own speed:
//              slow and wide for the bass, quick and fine for the highs, so the
//              WAVELENGTH you see is the pitch you hear, and where it comes
//              from is where it lives. Quiet lanes stay silent.
//   kick       one big press in the middle of the sheet, a drum head: the dent
//              springs back and a ring runs out to the edges. A critical (a big
//              accent) is deeper and wider and flashes the keys it lands on.
//   bass note  a small dent at its pitch along the bottom.
//   snare      a slap: a line of presses sweeps across the sheet, left to right
//              then right to left, like a hand run over the keys.
//   hat        a tiny sharp tap high up, and the key glints.
//   voice      a held tone is a finger: a steady dent that travels to the pitch.
//   pointer    your finger: it holds the keys under it down; letting go pops
//              them back up with the same overshoot as everything else.
//   volume     the bottom row of keys is held up as far as the volume reaches.
//
// A track change re-keys the sheet: a wave of presses runs out from the middle
// and every key it passes swaps its colour at the bottom of its press.
//
// Pure functions over a plain state object (no QML in here), so it can be run
// and tested with node (see keybed_test.js).

var SUB = 1 / 120             // fixed sub-step, seconds
var WAVE_SPEED = 15           // cells per second the ripples travel at
var STIFF = 42                // spring back to rest, 1/s^2: ~1 Hz for a lone key (quick enough for a beat)
var DAMP = 6.5                // 1/s: under-damped on purpose, a key bounces once
var EDGE_DAMP = 1.7           // extra damping at the border (x this)
var MAX_DEPTH = 1.35          // |depth| limit: 1 is a key fully pressed
var GLINT_FALL = 5.5          // 1/s

// One emitter per lane. phase speed (rad/s) rises with the pitch, so low lanes
// make long slow waves and high lanes short quick ones.
var LANES = 12
var EMIT_W0 = 5.5
var EMIT_W1 = 21
var EMIT_GAIN = 760
var EMIT_GATE = 0.1

function create(cols, rows) {
    var n = cols * rows
    var s = {
        cols: cols,
        rows: rows,
        n: n,
        p: new Array(n).fill(0),        // depth: + pressed, - raised
        v: new Array(n).fill(0),
        g: new Array(n).fill(0),        // glint 0..1
        f: new Array(n).fill(0),        // force scratch
        lastP: new Array(n).fill(0),
        lastG: new Array(n).fill(0),
        edge: new Array(n).fill(1),
        hold: new Array(n).fill(0),     // volume row target, 0 = none
        t: 0,
        acc: 0,
        awake: false,
        // spectrum emitters: bilinear splat of each lane's position on the bottom edge
        emit: [],
        phase: new Array(LANES).fill(0),
        // snare sweep
        sweep: { on: false, x: 0, dir: 1, power: 0, next: 1 },
        // voice finger
        voice: { on: false, amp: 0, x: cols / 2, y: rows * 0.32, tx: cols / 2 },
        // pointer finger (cell coordinates, down?)
        ptr: { down: false, x: 0, y: 0, amp: 0 },
        // volume row
        vol: { v: 0, left: 0 },
        // re-key sweep
        rekey: { on: false, t: 0, ox: 0, oy: 0, delay: new Array(n).fill(0), done: new Array(n).fill(true), pending: 0 },
        hatSeed: 7,
        swapped: []
    }
    var y = rows - 1
    for (var i = 0; i < LANES; i++) {
        var x = (i + 0.5) / LANES * cols - 0.5
        var x0 = Math.max(0, Math.min(cols - 1, Math.floor(x)))
        var x1 = Math.min(cols - 1, x0 + 1)
        var fx = Math.max(0, Math.min(1, x - x0))
        s.emit.push({ a: y * cols + x0, wa: 1 - fx, b: y * cols + x1, wb: fx })
    }
    for (var j = 0; j < rows; j++) {
        for (var k = 0; k < cols; k++) {
            var dx = Math.min(k, cols - 1 - k)
            var dy = Math.min(j, rows - 1 - j)
            var d = Math.min(dx, dy)
            s.edge[j * cols + k] = d === 0 ? EDGE_DAMP : 1
        }
    }
    return s
}

function clamp(x, a, b) { return x < a ? a : (x > b ? b : x) }

// ===== pushes =====

function dent(s, cx, cy, sigma, amp, snap) {
    var r = Math.ceil(sigma * 3)
    var x0 = Math.max(0, Math.floor(cx - r)), x1 = Math.min(s.cols - 1, Math.ceil(cx + r))
    var y0 = Math.max(0, Math.floor(cy - r)), y1 = Math.min(s.rows - 1, Math.ceil(cy + r))
    var inv = 1 / (2 * sigma * sigma)
    for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
            var d2 = (x - cx) * (x - cx) + (y - cy) * (y - cy)
            var w = Math.exp(-d2 * inv)
            var i = y * s.cols + x
            s.v[i] += amp * w
            if (snap) s.p[i] = Math.min(MAX_DEPTH, s.p[i] + snap * w)
        }
    }
    s.awake = true
}

function glint(s, cx, cy, sigma, amount) {
    var r = Math.ceil(sigma * 2.5)
    var x0 = Math.max(0, Math.floor(cx - r)), x1 = Math.min(s.cols - 1, Math.ceil(cx + r))
    var y0 = Math.max(0, Math.floor(cy - r)), y1 = Math.min(s.rows - 1, Math.ceil(cy + r))
    var inv = 1 / (2 * sigma * sigma)
    for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
            var d2 = (x - cx) * (x - cx) + (y - cy) * (y - cy)
            var i = y * s.cols + x
            s.g[i] = Math.max(s.g[i], amount * Math.exp(-d2 * inv))
        }
    }
    s.awake = true
}

// One thing that happened in the song. kind: "kick" | "crit" | "bass" | "snare" | "hat".
// lane is 0..12 (the analyzer's lane position), strength 0..1.
function hit(s, kind, lane, strength) {
    var C = s.cols, R = s.rows
    var st = clamp(strength, 0, 1)
    var unit = Math.min(C, R)
    if (kind === "kick" || kind === "crit") {
        var big = kind === "crit"
        var sig = unit * (big ? 0.36 : 0.3)
        var f = 0.55 + 0.45 * st
        dent(s, C / 2 - 0.5, R * 0.62, sig, (big ? 12 : 7) * f, (big ? 1.1 : 0.85) * f)
        glint(s, C / 2 - 0.5, R * 0.62, sig * (big ? 1.2 : 0.95), (big ? 0.95 : 0.55) * f)
    } else if (kind === "bass") {
        var bx = clamp(lane / LANES * C - 0.5, 0, C - 1)
        var bf = 0.55 + 0.45 * st
        dent(s, bx, R - 1.8, unit * 0.2 + 0.6, 5 * bf, 0.8 * bf)
        glint(s, bx, R - 1.8, unit * 0.2 + 0.6, 0.4 * bf)
    } else if (kind === "snare") {
        sweepStart(s, st)
    } else if (kind === "hat") {
        // two quick taps in the top half (deterministic, no Math.random)
        var hf = 0.6 + 0.4 * st
        for (var n = 0; n < 2; n++) {
            s.hatSeed = (s.hatSeed * 1103515245 + 12345) & 0x7fffffff
            var hx = (s.hatSeed % 1000) / 1000 * (C - 1)
            s.hatSeed = (s.hatSeed * 1103515245 + 12345) & 0x7fffffff
            var hy = 0.4 + (s.hatSeed % 1000) / 1000 * Math.max(1, R * 0.42 - 0.4)
            dent(s, hx, hy, 1.0, 2.2 * hf, 0.95 * hf)
            glint(s, hx, hy, 1.2, 0.95)
        }
    }
}

// The slap: a line of presses runs across the sheet. Direction alternates.
function sweepStart(s, st, dir) {
    var w = s.sweep
    w.dir = dir ? (dir > 0 ? 1 : -1) : w.next
    w.next = -w.dir
    w.x = w.dir > 0 ? -1.2 : s.cols + 0.2
    w.power = 0.55 + 0.45 * clamp(st, 0, 1)
    w.on = true
    s.awake = true
}

function sweepStep(s, dt) {
    var w = s.sweep
    if (!w.on) return
    var speed = s.cols * 4.2                  // the sheet in about a quarter of a second
    var nx = w.x + w.dir * speed * dt
    // press every column the line passed this step (so a fast line leaves no gaps)
    var a = Math.min(w.x, nx), b = Math.max(w.x, nx)
    var c0 = Math.max(0, Math.ceil(a - 0.5)), c1 = Math.min(s.cols - 1, Math.floor(b + 0.5))
    for (var c = c0; c <= c1; c++) {
        for (var r = 0; r < s.rows; r++) {
            // the middle rows take the hardest slap
            var prof = 0.55 + 0.45 * Math.sin(Math.PI * (r + 0.5) / s.rows)
            var k = r * s.cols + c
            s.v[k] += 1.0 * w.power * prof
            s.p[k] = Math.min(MAX_DEPTH, s.p[k] + 0.55 * w.power * prof)
            s.g[k] = Math.max(s.g[k], 0.6 * w.power)
        }
    }
    w.x = nx
    if (w.x > s.cols + 1.5 || w.x < -2.5)
        w.on = false
    s.awake = true
}

// A slap in a chosen direction (next track runs left to right, previous the other way).
function slap(s, dir, strength) {
    sweepStart(s, clamp(strength === undefined ? 1 : strength, 0, 1), dir)
}

// ===== the finger =====

function voiceSet(s, on, lanePos) {
    var v = s.voice
    v.on = on
    if (on)
        v.tx = clamp(lanePos / LANES * s.cols - 0.5, 0.5, s.cols - 1.5)
}

function pointerSet(s, down, cx, cy) {
    var p = s.ptr
    if (p.down && !down) {
        // letting go: a small upward flick on top of the spring-back
        dent(s, p.x, p.y, 1.6, -3.5)
    }
    p.down = down
    if (down) {
        if (p.amp < 0.05) { p.x = cx; p.y = cy }
        p.tx = cx
        p.ty = cy
        s.awake = true
    }
}

// Hold the bottom row up as far as the volume reaches, for a moment.
function volumeShow(s, v) {
    s.vol.v = clamp(v, 0, 1)
    s.vol.left = 1.3
    s.awake = true
}

// ===== track change =====

function rekey(s) {
    var r = s.rekey
    r.on = true
    r.t = 0
    r.ox = s.cols / 2 - 0.5
    r.oy = s.rows / 2 - 0.5
    r.pending = s.n
    for (var y = 0; y < s.rows; y++) {
        for (var x = 0; x < s.cols; x++) {
            var d = Math.sqrt((x - r.ox) * (x - r.ox) + ((y - r.oy) * 1.15) * ((y - r.oy) * 1.15))
            r.delay[y * s.cols + x] = d / 24
            r.done[y * s.cols + x] = false
        }
    }
    s.awake = true
}

// ===== the step =====

function step(s, dt, input) {
    var C = s.cols, R = s.rows, N = s.n
    dt = clamp(dt, 0, 0.05)
    s.swapped = []

    // ===== forces that are fixed over this frame =====
    var F = s.f
    for (var i = 0; i < N; i++) F[i] = 0
    var levels = input && input.levels ? input.levels : null
    var any = false
    if (levels) {
        for (var l = 0; l < LANES; l++) {
            var e = (levels[l] - EMIT_GATE) / (1 - EMIT_GATE)
            s.phase[l] += dt * (EMIT_W0 + (EMIT_W1 - EMIT_W0) * l / (LANES - 1))
            if (e <= 0) continue
            any = true
            var amp = EMIT_GAIN * Math.pow(e, 1.25) * Math.sin(s.phase[l])
            var em = s.emit[l]
            F[em.a] += amp * em.wa
            F[em.b] += amp * em.wb
        }
    }

    // the voice finger: eased towards its pitch, pressing steadily while it is held
    var vo = s.voice
    vo.amp += ((vo.on ? 1 : 0) - vo.amp) * Math.min(1, dt * (vo.on ? 9 : 5))
    if (vo.amp > 0.01) {
        vo.x += (vo.tx - vo.x) * Math.min(1, dt * 7)
        var vy = R * 0.3 + Math.sin(s.t * 2.3) * R * 0.04
        vo.y += (vy - vo.y) * Math.min(1, dt * 4)
        pull(s, F, vo.x, vo.y, 1.25, 0.9 * vo.amp, 190)
        any = true
    }

    // the pointer finger: holds the keys under it down
    var pt = s.ptr
    pt.amp += ((pt.down ? 1 : 0) - pt.amp) * Math.min(1, dt * (pt.down ? 16 : 20))
    if (pt.down) {
        pt.x += (pt.tx - pt.x) * Math.min(1, dt * 22)
        pt.y += (pt.ty - pt.y) * Math.min(1, dt * 22)
    }
    if (pt.amp > 0.01) {
        pull(s, F, pt.x, pt.y, 1.05, 1.0 * pt.amp, 480)
        any = true
    }

    // the volume row
    var vl = s.vol
    var holdOn = vl.left > 0
    if (holdOn) {
        vl.left -= dt
        var lit = vl.v * C
        var base = (R - 1) * C
        for (var c = 0; c < C; c++) {
            var w = clamp(lit - c, 0, 1)
            s.hold[base + c] = w
            if (w > 0) F[base + c] += 260 * (-0.8 - s.p[base + c]) * w
        }
        any = true
    } else if (vl.left > -1) {
        vl.left = -2
        var base2 = (R - 1) * C
        for (var c2 = 0; c2 < C; c2++) s.hold[base2 + c2] = 0
    }

    // ===== sweeps and re-keying =====
    sweepStep(s, dt)
    var rk = s.rekey
    if (rk.on) {
        rk.t += dt
        for (var q = 0; q < N; q++) {
            if (!rk.done[q] && rk.t >= rk.delay[q]) {
                rk.done[q] = true
                rk.pending--
                s.swapped.push(q)
                s.v[q] += 7.5
                s.g[q] = Math.max(s.g[q], 0.55)
            }
        }
        if (rk.pending <= 0) rk.on = false
        s.awake = true
    }

    // ===== integrate =====
    s.acc += dt
    var c2w = WAVE_SPEED * WAVE_SPEED
    var P = s.p, V = s.v, E = s.edge
    while (s.acc >= SUB) {
        s.acc -= SUB
        for (var y = 0; y < R; y++) {
            var row = y * C
            for (var x = 0; x < C; x++) {
                var k = row + x
                var pc = P[k]
                var pl = x > 0 ? P[k - 1] : pc
                var pr = x < C - 1 ? P[k + 1] : pc
                var pu = y > 0 ? P[k - C] : pc
                var pd = y < R - 1 ? P[k + C] : pc
                var a = c2w * (pl + pr + pu + pd - 4 * pc) - STIFF * pc - DAMP * E[k] * V[k] + F[k]
                V[k] += a * SUB
            }
        }
        for (var m = 0; m < N; m++) {
            var np = P[m] + V[m] * SUB
            P[m] = np > MAX_DEPTH ? MAX_DEPTH : (np < -MAX_DEPTH ? -MAX_DEPTH : np)
        }
    }
    s.t += dt

    // ===== glints fade, and what changed =====
    var fall = Math.exp(-GLINT_FALL * dt)
    var dirty = []
    var energy = 0
    for (var z = 0; z < N; z++) {
        s.g[z] *= fall
        if (s.g[z] < 0.01) s.g[z] = 0
        var e1 = Math.abs(P[z]) + Math.abs(V[z]) * 0.1
        if (e1 > energy) energy = e1
        if (Math.abs(P[z] - s.lastP[z]) > 0.004 || Math.abs(s.g[z] - s.lastG[z]) > 0.02
            || (P[z] === 0 && s.lastP[z] !== 0) || (s.g[z] === 0 && s.lastG[z] !== 0)) {
            s.lastP[z] = P[z]
            s.lastG[z] = s.g[z]
            dirty.push(z)
        }
    }
    // snap tiny leftovers to rest so the sheet can sleep
    if (!any && !s.sweep.on && !s.rekey.on && !pt.down && energy < 0.004) {
        var moved = false
        for (var w2 = 0; w2 < N; w2++) {
            if (P[w2] !== 0 || V[w2] !== 0) { P[w2] = 0; V[w2] = 0; moved = true }
        }
        if (moved) {
            for (var w3 = 0; w3 < N; w3++) {
                if (s.lastP[w3] !== 0) { s.lastP[w3] = 0; dirty.push(w3) }
            }
        }
        s.awake = false
    } else {
        s.awake = true
    }
    return { dirty: dirty, swapped: s.swapped, awake: s.awake }
}

// A spring-pull towards full depth under a round finger: F += k * (target - p) * weight.
function pull(s, F, cx, cy, sigma, target, k) {
    var r = Math.ceil(sigma * 3)
    var x0 = Math.max(0, Math.floor(cx - r)), x1 = Math.min(s.cols - 1, Math.ceil(cx + r))
    var y0 = Math.max(0, Math.floor(cy - r)), y1 = Math.min(s.rows - 1, Math.ceil(cy + r))
    var inv = 1 / (2 * sigma * sigma)
    for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
            var d2 = (x - cx) * (x - cx) + (y - cy) * (y - cy)
            var i = y * s.cols + x
            F[i] += k * (target - s.p[i]) * Math.exp(-d2 * inv)
        }
    }
}

// ===== colours =====

function layCover(cells, cw, ch, cols, rows) {
    var out = new Array(cols * rows)
    var offX = Math.floor((cols - cw) / 2)
    var offY = Math.floor((rows - ch) / 2)
    for (var y = 0; y < rows; y++) {
        for (var x = 0; x < cols; x++) {
            var sx = x - offX
            var sy = y - offY
            var wing = 0
            if (sx < 0 || sx >= cw) wing = 1
            // mirror-repeat both axes
            var mx = ((sx % (2 * cw)) + 2 * cw) % (2 * cw)
            if (mx >= cw) mx = 2 * cw - 1 - mx
            var my = ((sy % (2 * ch)) + 2 * ch) % (2 * ch)
            if (my >= ch) my = 2 * ch - 1 - my
            var c = cells[my * cw + mx]
            out[y * cols + x] = [c[0], c[1], c[2], wing]
        }
    }
    return out
}

// Make a sampled colour work as a key on a slate well: a bit more colour, never black, never white.
function tuneColor(r, g, b) {
    var mx = Math.max(r, g, b), mn = Math.min(r, g, b)
    var l = (mx + mn) / 2
    var d = mx - mn
    var sat = d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1))
    var h = 0
    if (d !== 0) {
        if (mx === r) h = ((g - b) / d) % 6
        else if (mx === g) h = (b - r) / d + 2
        else h = (r - g) / d + 4
        h /= 6
        if (h < 0) h += 1
    }
    sat = clamp(sat * 1.14, 0, 1)
    l = clamp(l, 0.3, 0.86)
    var c = (1 - Math.abs(2 * l - 1)) * sat
    var hp = h * 6
    var xx = c * (1 - Math.abs(hp % 2 - 1))
    var m = l - c / 2
    var rr = 0, gg = 0, bb = 0
    if (hp < 1) { rr = c; gg = xx }
    else if (hp < 2) { rr = xx; gg = c }
    else if (hp < 3) { gg = c; bb = xx }
    else if (hp < 4) { gg = xx; bb = c }
    else if (hp < 5) { rr = xx; bb = c }
    else { rr = c; bb = xx }
    return [rr + m, gg + m, bb + m]
}
