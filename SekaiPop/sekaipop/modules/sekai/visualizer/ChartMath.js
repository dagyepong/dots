.pragma library

// The chart-writer behind VisualizerEngine.qml: it decides WHEN a note is hit,
// which lane it lands in, and when the slide ribbon runs. Pure functions over a
// plain state object (no QML in here), so it can be run and tested with node.
//
// What changed from the first version (which spawned a note whenever a lane
// rose above its own slow average, so any wobble in cava's bands became a note):
//
//   1. Onsets are EDGES, not levels. A lane fires when it jumps above a
//      follower that trails it (rise = level - follower) by more than an
//      ADAPTIVE threshold (a floor plus a multiple of that lane's recent mean
//      rise), and it must fall back before it can fire again.
//   2. One hit is one note: lanes that fire together or within 70 ms of a
//      neighbouring note are folded together, and a token bucket (8 notes / s,
//      bursts of 2) drops the weakest if the music is busier than that.
//   3. It follows the BEAT. Onset strength is sampled at 50 Hz, the tempo comes
//      from its autocorrelation, the phase from where the energy sits in the
//      last few seconds. Once locked, an onset on a beat or an eighth is
//      accepted at normal strength and one off the grid has to be clearly
//      strong (a real syncopation), which removes most of the jitter without
//      delaying any note: the grid only gates, it never moves a hit.
//   4. The beat clock also drives the bass pulse, so the columns pump in
//      time even between kicks.
//   5. The slide ribbon needs sustained tonal energy (hysteresis + smoothing)
//      and follows the melody lanes, not the kick.

var LANES = 12
var BIN = 0.02                 // onset-strength sampling interval: 50 Hz
var HIST = 300                 // 6 s of history
var MIN_LAG = 18               // 167 BPM
var MAX_LAG = 50               // 60 BPM
var GRID_TOL = 0.065           // seconds either side of a beat / eighth
var RIBBON_STEP = 1 / 15

// ===== live analyzer mode =====
var KICK_LANE = 1.6
var SNARE_LANE = 6.0
var HAT_LANE = 10.4
var BASS_LANES = [0.7, 3.3]       // pitch, low to high
var LEAD_LANES = [3.4, 11.0]      // pitch, low to high
var KICK_CRIT_GAP = 1.4
var LEAD_MIN_HOLD = 0.22          // s of a steady clear tone before a slide starts
var LEAD_MIN_REST = 0.35          // s of rest between two slides
var LEAD_LOST = 0.16              // s without the tone that ends a slide
var LEAD_MAX_LEN = 3.6            // s: a drone is not a melody, cut it short
var LEAD_LONG_REST = 0.9          // s of rest forced after a cut-short slide
var BASS_NOTES = true             // false: no bass-pitch notes at all

function zeros(n) {
    var a = new Array(n)
    for (var i = 0; i < n; i++) a[i] = 0
    return a
}

function create() {
    var armed = new Array(LANES)
    for (var i = 0; i < LANES; i++) armed[i] = true
    return {
        t: 0,
        prevTarget: zeros(LANES),
        follower: zeros(LANES),
        riseMean: zeros(LANES),
        armed: armed,
        cooldown: zeros(LANES),
        levels: zeros(LANES),
        // onset strength history (ring), newest at osHead
        osBuf: zeros(HIST),
        osHead: 0,
        osCount: 0,
        osAcc: 0,
        binAcc: 0,
        estTimer: 0,
        period: 0,             // seconds per beat, 0 = no tempo yet
        beatT: 0,              // time of a beat (any beat: add multiples of period)
        conf: 0,               // 0..1 how periodic the music looks
        pendingPeriod: 0,
        pendingCount: 0,
        budget: 2.5,
        recent: [],            // notes spawned lately: {t, lane}
        bassAverage: 0,
        bass: 0,               // detected kick pulse
        ribbon: { on: false, x: 6, amp: 0, acc: 0, hold: 0, quiet: 0 },
        // live analyzer mode
        tokens: { k: 2, s: 2, h: 1.5, b: 1.5 },
        extBeatAt: -99,        // when aubio last reported a beat (live mode)
        lastKick: -9,
        lastCrit: -9,
        lastHat: -9,
        snareSide: 0,
        lead: { on: false, x: 7, pos: -1, hold: 0, miss: 0, rest: 0, len: 0, since: 0, acc: 0, level: 0, jitter: 0, held: 0 }
    }
}

// ===== tempo + phase =====

function history(s) {
    // oldest -> newest
    var n = Math.min(s.osCount, HIST)
    var a = new Array(n)
    for (var k = 0; k < n; k++)
        a[k] = s.osBuf[(s.osHead - (n - 1 - k) + HIST * 2) % HIST]
    return a
}

function estimate(s) {
    var a = history(s)
    var n = a.length
    if (n < 150) return
    var m = 0
    for (var i = 0; i < n; i++) m += a[i]
    m /= n
    var c = new Array(n)
    var v = 0
    for (i = 0; i < n; i++) { c[i] = a[i] - m; v += c[i] * c[i] }
    v /= n
    if (v < 1e-5) {                // silence / nothing rhythmic
        s.conf *= 0.8
        return
    }
    function r(l) {
        var sum = 0
        for (var k = l; k < n; k++) sum += c[k] * c[k - l]
        return sum / (n - l) / v
    }
    var best = -1, bestScore = -1e9, rs = {}
    for (var l = MIN_LAG - 1; l <= MAX_LAG + 1; l++) rs[l] = r(l)
    for (l = MIN_LAG; l <= MAX_LAG; l++) {
        var bpm = 60 / (l * BIN)
        var prior = Math.exp(-0.5 * Math.pow(Math.log(bpm / 120) / Math.LN2 / 0.9, 2))
        var sc = rs[l] + (2 * l < n ? 0.5 * r(2 * l) : 0)
        sc *= prior
        if (sc > bestScore) { bestScore = sc; best = l }
    }
    if (best < 0) return
    // A drum loop repeats every 2 or 4 beats, so the lag of the whole pattern
    // often scores higher than the beat itself. If half of it is in range and
    // nearly as periodic, that is the beat.
    var half = Math.round(best / 2)
    if (half >= MIN_LAG && Math.max(rs[half - 1], rs[half], rs[half + 1]) >= 0.55 * rs[best]) {
        var hb = half
        if (rs[half - 1] > rs[hb]) hb = half - 1
        if (rs[half + 1] > rs[hb]) hb = half + 1
        best = hb
    }
    // parabolic interpolation for a sub-bin lag
    var y0 = rs[best - 1], y1 = rs[best], y2 = rs[best + 1]
    var den = y0 - 2 * y1 + y2
    var off = den < -1e-9 ? 0.5 * (y0 - y2) / den : 0
    var newPeriod = (best + Math.max(-0.5, Math.min(0.5, off))) * BIN
    var conf = Math.max(0, Math.min(1, rs[best]))
    s.conf += (conf - s.conf) * 0.5

    if (s.period === 0) {
        s.period = newPeriod
    } else if (Math.abs(newPeriod / s.period - 1) < 0.07) {
        s.period += (newPeriod - s.period) * 0.35
        s.pendingCount = 0
    } else {
        // a different tempo (or an octave jump): believe it only if it persists
        if (s.pendingPeriod > 0 && Math.abs(newPeriod / s.pendingPeriod - 1) < 0.07) s.pendingCount++
        else { s.pendingPeriod = newPeriod; s.pendingCount = 1 }
        if (s.pendingCount >= 3) { s.period = newPeriod; s.pendingCount = 0; s.beatT = 0 }
    }

    // phase: which offset (in bins back from now) puts the most onset energy on the grid
    var p = s.period / BIN
    var steps = Math.ceil(p)
    var score = new Array(steps)
    for (var o = 0; o < steps; o++) {
        var sum = 0
        for (var k = 0; ; k++) {
            var idx = n - 1 - o - Math.round(k * p)
            if (idx < 0) break
            sum += a[idx]
        }
        score[o] = sum
    }
    var bo = 0, bs = -1
    for (o = 0; o < steps; o++) {
        var sm = score[o] + 0.5 * (score[(o + 1) % steps] + score[(o + steps - 1) % steps])
        if (sm > bs) { bs = sm; bo = o }
    }
    var last = s.t - s.binAcc - bo * BIN
    if (s.beatT === 0) {
        s.beatT = last
    } else {
        var ahead = Math.round((last - s.beatT) / s.period)
        var predicted = s.beatT + ahead * s.period
        var err = last - predicted
        s.beatT = predicted + err * 0.4
    }
}

// {on, beat, dist}: is time t on a beat or an eighth of the current grid?
function grid(s, t) {
    if (s.period === 0 || s.conf < 0.2) return { locked: false, on: true, beat: false }
    var sub = s.period / 2
    var x = (((t - s.beatT) % sub) + sub) % sub
    var dist = Math.min(x, sub - x)
    var y = (((t - s.beatT) % s.period) + s.period) % s.period
    var db = Math.min(y, s.period - y)
    var tol = Math.min(GRID_TOL, sub * 0.3)
    return { locked: true, on: dist <= tol, beat: db <= tol }
}

function beatPulse(s) {
    if (s.period === 0 || s.conf < 0.2) return 0
    var since = (((s.t - s.beatT) % s.period) + s.period) % s.period
    return Math.exp(-7 * since) * Math.min(1, s.conf * 2) * 0.85
}

// ===== one frame =====

function step(s, dt, target, playing) {
    s.t += dt
    var out = { notes: [], heads: [], ribbon: null, bass: 0 }

    // onset strength at 50 Hz: the sum of this frame's rises
    var flux = 0
    for (var i = 0; i < LANES; i++) {
        var d = target[i] - s.prevTarget[i]
        if (d > 0) flux += d * (i < 3 ? 1.25 : 1)
    }
    s.osAcc += flux
    s.binAcc += dt
    while (s.binAcc >= BIN) {
        s.binAcc -= BIN
        s.osHead = (s.osHead + 1) % HIST
        s.osBuf[s.osHead] = s.osAcc
        s.osAcc = 0
        s.osCount++
    }
    s.estTimer += dt
    if (s.estTimer >= 0.4) {
        s.estTimer = 0
        if (playing) estimate(s)
        else s.conf *= 0.7
    }

    // levels (what the lane slots show): fast attack, slower release
    for (i = 0; i < LANES; i++) {
        var lv = s.levels[i], tg = target[i]
        s.levels[i] = lv + (tg - lv) * Math.min(1, dt * (tg > lv ? 22 : 8))
    }

    // per-lane edge detection
    var upRate = 1 - Math.exp(-dt * 5)
    var downRate = 1 - Math.exp(-dt * 12)
    var meanRate = 1 - Math.exp(-dt * 1.0)
    var rise = zeros(LANES), thr = zeros(LANES), fire = zeros(LANES)
    for (i = 0; i < LANES; i++) {
        var f = s.follower[i]
        tg = target[i]
        rise[i] = tg - f
        s.follower[i] = f + (tg - f) * (tg > f ? upRate : downRate)
        s.riseMean[i] += (Math.max(rise[i], 0) - s.riseMean[i]) * meanRate
        thr[i] = 0.10 + 1.1 * s.riseMean[i]
        s.cooldown[i] -= dt
        if (rise[i] < thr[i] * 0.5) s.armed[i] = true
        if (playing && s.armed[i] && rise[i] >= thr[i] && tg >= 0.2 && s.cooldown[i] <= 0) {
            fire[i] = 1
            s.armed[i] = false
        }
        s.prevTarget[i] = tg
    }

    // a kick pulse (bass rising above its own average) ...
    var bassNow = (target[0] + target[1]) / 2
    s.bassAverage += (bassNow - s.bassAverage) * Math.min(1, dt * 1.5)
    if (bassNow > s.bassAverage * 1.3 + 0.04 && bassNow > 0.25)
        s.bass = Math.min(1, s.bass + (bassNow - s.bassAverage) * 2.5)
    s.bass *= Math.exp(-dt * 5)
    // ... and the beat clock's, so the columns pump in time between kicks
    out.bass = Math.max(s.bass, playing ? beatPulse(s) : 0)

    // runs of lanes that fired are candidates for one note each
    s.budget = Math.min(2.5, s.budget + dt * 8)
    s.recent = s.recent.filter(function (n) { return s.t - n.t < 0.07 })
    var cands = []
    i = 0
    while (i < LANES) {
        if (!fire[i]) { i++; continue }
        var j = i
        while (j + 1 < LANES && fire[j + 1]) j++
        var strength = 0, tmin = 1
        for (var k = i; k <= j; k++) { strength = Math.max(strength, rise[k]); tmin = Math.min(tmin, thr[k]) }
        cands.push({ from: i, to: j, centre: (i + j + 1) / 2, strength: strength, thr: tmin })
        i = j + 1
    }
    cands.sort(function (a, b) { return b.strength - a.strength })

    var g = grid(s, s.t)
    for (var ci = 0; ci < cands.length; ci++) {
        var c = cands[ci]
        // the cooldown also covers the neighbours so one hit isn't two notes
        var lo = Math.max(0, c.from - 1), hi = Math.min(LANES - 1, c.to + 1)
        for (k = lo; k <= hi; k++) s.cooldown[k] = Math.max(s.cooldown[k], 0.16)

        var near = false
        for (var ri = 0; ri < s.recent.length; ri++)
            if (Math.abs(s.recent[ri].lane - c.centre) <= 3.5) near = true
        if (near) continue
        // off the grid: only a clearly strong hit counts
        if (!g.on && c.strength < Math.max(0.30, c.thr * 1.6)) continue
        if (s.budget < 1) continue
        s.budget -= 1

        var width = Math.min(4, Math.max(1, c.to - c.from + 1))
        var type = 0
        if (c.from <= 1 && c.strength > 0.30 && (g.beat || !g.locked) && s.bass > 0.25) type = 2
        else if (c.strength > 0.65) type = 2
        else if (c.centre >= 9 && c.strength > 0.22) type = 1
        s.recent.push({ t: s.t, lane: c.centre })
        out.notes.push({ lane: c.centre, width: width, type: type, strength: c.strength })
    }

    // the slide: sustained energy in the melody lanes, smoothed
    var rb = s.ribbon
    rb.acc += dt
    if (rb.acc >= RIBBON_STEP) {
        rb.acc -= RIBBON_STEP
        var total = 0, weighted = 0, amp = 0
        for (k = 2; k < LANES; k++) {
            var w = s.levels[k] * s.levels[k]
            total += w
            weighted += (k + 0.5) * w
            amp = Math.max(amp, s.levels[k])
        }
        if (!playing) amp = 0
        var centroid = total > 1e-6 ? weighted / total : rb.x
        rb.amp += (amp - rb.amp) * 0.25
        if (!rb.on) {
            rb.hold = rb.amp > 0.34 ? rb.hold + RIBBON_STEP : 0
            if (rb.hold >= 0.25) {
                rb.on = true
                rb.x = centroid
                rb.quiet = 0
                out.heads.push(rb.x)
            }
        } else {
            rb.quiet = rb.amp < 0.18 ? rb.quiet + RIBBON_STEP : 0
            if (rb.quiet >= 0.3) {
                rb.on = false
                rb.hold = 0
                out.heads.push(rb.x)
            }
        }
        if (rb.on) rb.x += (centroid - rb.x) * 0.18
        out.ribbon = { on: rb.on, x: rb.x, w: 1.1 + 1.6 * rb.amp }
    }
    return out
}

// ===== live analyzer mode =====

function laneOf(pos, range) {
    return range[0] + Math.max(0, Math.min(1, pos)) * (range[1] - range[0])
}

// Like step(), but the hits come from the analyzer instead of being guessed.
//   target   12 lane levels 0..1 (the lane meters)
//   an       what arrived since the last call: { o: onset strength summed,
//            e: [["k", strength], ["s", s], ["h", s], ["b", s, pos]], v: null
//            or [pos, clarity] (the last lead-tone reading) }
//   sens     0.5 .. 2.5, the visualizer's sensitivity setting
// Returns the same { notes, heads, ribbon, bass } as step().
function stepLive(s, dt, target, an, playing, sens) {
    s.t += dt
    var out = { notes: [], heads: [], ribbon: null, bass: 0 }
    var live = playing && an

    // beat tracker: the analyzer's onset strength, same 50 Hz history as step()
    s.osAcc += live ? an.o * 0.5 : 0
    s.binAcc += dt
    while (s.binAcc >= BIN) {
        s.binAcc -= BIN
        s.osHead = (s.osHead + 1) % HIST
        s.osBuf[s.osHead] = s.osAcc
        s.osAcc = 0
        s.osCount++
    }
    // aubio's beat tracker, when the analyzer runs on it: [bpm, confidence, seconds ago].
    // While it keeps reporting, it is the beat clock and the autocorrelation guess below sits out.
    if (live && an.t) {
        var bp = 60 / an.t[0]
        while (bp < 0.35) bp *= 2             // aubio sometimes counts half or double: fold into 60-170 BPM
        while (bp > 1.0) bp /= 2
        s.period = s.period === 0 || Math.abs(bp / s.period - 1) > 0.12 ? bp : s.period + (bp - s.period) * 0.25
        s.beatT = s.t - an.t[2]
        s.conf = Math.max(0.5, Math.min(1, an.t[1] + 0.3))
        s.extBeatAt = s.t
    }
    s.estTimer += dt
    if (s.estTimer >= 0.4) {
        s.estTimer = 0
        if (!playing) s.conf *= 0.7
        else if (s.t - s.extBeatAt > 3) estimate(s)
    }

    // lane meters
    for (var i = 0; i < LANES; i++) {
        var lv = s.levels[i], tg = target[i]
        s.levels[i] = lv + (tg - lv) * Math.min(1, dt * (tg > lv ? 22 : 8))
    }

    // note budgets, one per instrument so hats can't starve the kick
    var rates = { k: 5, s: 5, h: 3, b: 4 }
    var caps = { k: 2, s: 2, h: 1.5, b: 1.5 }
    for (var key in rates) s.tokens[key] = Math.min(caps[key], s.tokens[key] + dt * rates[key])

    var g = grid(s, s.t)
    var minStrength = 0.14 / Math.max(0.5, sens || 1)
    var evs = live ? an.e : []
    var haveKick = false
    for (var ei = 0; ei < evs.length; ei++) {
        var e = evs[ei]
        var kind = e[0], st = e[1]
        if (st < minStrength) continue
        // off the grid: only a clearly strong hit counts (the grid gates, it never moves a hit)
        if (kind !== "b" && !g.on && st < 0.6) continue
        if (s.tokens[kind] < 1) continue
        if (kind === "k") {
            s.tokens.k -= 1
            s.lastKick = s.t
            s.bass = Math.min(1, s.bass + 0.5 + 0.5 * st)
            var crit = st > 0.75 && (g.beat || !g.locked) && s.t - s.lastCrit > KICK_CRIT_GAP
            if (crit) s.lastCrit = s.t
            out.notes.push({ lane: KICK_LANE, width: 2.6, type: crit ? 2 : 0, strength: st })
        } else if (kind === "s") {
            s.tokens.s -= 1
            s.snareSide = 1 - s.snareSide
            out.notes.push({ lane: SNARE_LANE + (s.snareSide ? 0.6 : -0.6), width: 2.6, type: 0, strength: st })
        } else if (kind === "h") {
            if (s.t - s.lastHat < 0.18) continue
            s.tokens.h -= 1
            s.lastHat = s.t
            out.notes.push({ lane: HAT_LANE, width: 1.5, type: 1, strength: st })
        } else if (kind === "b" && BASS_NOTES) {
            // a kick already put a note there (or is about to)
            if (s.t - s.lastKick < 0.35) continue
            s.tokens.b -= 1
            out.notes.push({ lane: laneOf(e[2], BASS_LANES), width: 1.3, type: 0, strength: st })
        }
    }

    // the columns pump with kicks, and with the beat clock in between
    s.bass *= Math.exp(-dt * 5)
    out.bass = Math.max(s.bass, playing ? beatPulse(s) : 0)

    leadStep(s, dt, live ? an.v : null, playing, out)
    return out
}

// The slide. Only a clear tone that holds still (a voice, a lead synth) makes
// one: it has to be there for LEAD_MIN_HOLD, can't start again before
// LEAD_MIN_REST has passed, ends when the tone is gone for LEAD_LOST (a flick
// note marks the end), and is cut after LEAD_MAX_LEN even if the note goes on.
function leadStep(s, dt, v, playing, out) {
    var L = s.lead
    L.since += dt
    L.acc += dt
    var have = playing && v && v.length >= 2

    if (have) {
        L.miss = 0
        var x = laneOf(v[0], LEAD_LANES)
        L.level += (v[1] - L.level) * 0.3
        if (L.pos < 0) L.pos = x
        // how much the pitch is moving: a held note or a slow glide is small,
        // chatter between several instruments is not
        var jump = Math.abs(x - L.pos)
        L.jitter += (jump - L.jitter) * 0.25
        L.pos += (x - L.pos) * (jump > 2.5 ? 0.6 : 0.3)
        L.hold += dt
    } else {
        L.miss += dt
        if (L.miss > LEAD_LOST) L.hold = 0
        L.level *= Math.exp(-dt * 6)
        if (L.miss > 0.5) L.pos = -1
    }

    if (!L.on) {
        if (have && L.hold >= LEAD_MIN_HOLD && L.since >= LEAD_MIN_REST && L.jitter < 1.2) {
            L.on = true
            L.len = 0
            L.x = L.pos
            L.acc = 0
            out.heads.push(L.x)
        }
    } else {
        L.len += dt
        var ended = L.miss >= LEAD_LOST
        var cut = L.len >= LEAD_MAX_LEN
        if (ended || cut) {
            L.on = false
            L.hold = 0
            L.since = cut ? -LEAD_LONG_REST + LEAD_MIN_REST : 0
            // the end of a slide is a flick
            out.notes.push({ lane: L.x, width: 1.6, type: 1, strength: 0.5 })
        }
    }

    if (L.acc >= RIBBON_STEP) {
        L.acc -= RIBBON_STEP
        if (L.on) {
            if (have) L.x += (L.pos - L.x) * 0.45
            out.ribbon = { on: true, x: L.x, w: 1.1 + 1.0 * Math.min(1, L.level) }
        } else {
            out.ribbon = { on: false, x: L.x, w: 0 }
        }
    }
}
