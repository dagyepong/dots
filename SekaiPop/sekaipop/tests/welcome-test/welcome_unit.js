// Runs under node: loads the real modules/common/functions/WelcomeMath.js and
// WelcomeSlides.js and checks the progress maths behind the welcome screen
// (WelcomePage.qml and the pieces in modules/sekai/welcome/), then runs the real
// scripts/state/welcome-state.sh against a temporary state folder.
// Quickshell can't run here, so the QML itself is checked as text at the end.
// Usage: node tests/welcome-test/welcome_unit.js
const fs = require("fs"), path = require("path"), assert = require("assert"), os = require("os")
const { execFileSync } = require("child_process")
const top = path.join(__dirname, "..", "..")
const load = (rel, names) => {
    const src = fs.readFileSync(require("../lib/locate")(rel), "utf8").replace(".pragma library", "")
    return new Function(src + "\nreturn { " + names + " };")()
}
const M = load("modules/common/functions/WelcomeMath.js",
    "unitFor, clamp01, stagger, easeOutBack, easeOutCubic, splitLines, wordCount, firstWordOf, pageLabel, step, keyDirection, wobble, hintFor, DESIGN_W, DESIGN_H, spring, captionMs, subStepMs, wordProgress, CAPTION, LOGO_RUN_MS, LOGO_LEAVE_MS, seg, springEx, BURST, burstOf, burstSpring, LETTER_REST, letterProgress, letterRest, squash, POP_ZETA, POP_OMEGA, POP_SECONDS, popSpring, layerRun, STROKE_AT, STROKE_MS, HALFTONE_AT, HALFTONE_MS, DECOR_AT, DECOR_GAP, DECOR_MS, SQUIGGLE_AT, SQUIGGLE_MS, WARP_AT, WARP_MS, SWEEP_AT, SWEEP_MS, IGNITION_MS, strokeRun, halftoneRun, decorRun, squiggleRun, ignitionRun, FX_WAVE_AT, FX_WAVE_MS, FX_DOTS_AT, FX_DOTS_MS, FX_MATTE_AT, FX_MATTE_MS, FX_SHINE_AT, FX_SHINE_MS, fxWaveRun, fxDotsRun, fxMatteRun, fxShineRun, warpRun, warpAmount, warpPhase, sweepRun, sweepPos, leaveStart, LEAVE_LETTER_MS, LEAVE_KANA_MS, leaveProgress, easeInBack, collapse, leaveDecor, leaveStroke, leaveFlash")
const S = load("modules/common/functions/WelcomeSlides.js", "SLIDES, heroMs, HERO_MS, LEAVE_MS, leaveMs, subOf, heroCenter, heroPose, HERO_POSE")

let fails = 0
function ok(c, m) { if (!c) { fails++; console.log("FAIL", m) } else console.log("ok  ", m) }
const near = (a, b, e = 1e-9) => Math.abs(a - b) <= e

// ---- unitFor: one unit = 1/768 of the height, until the screen is narrower than 3:4 ----
ok(near(M.unitFor(1920, 1080), 1080 / 768), "1920x1080: a unit is height / 768")
ok(near(M.unitFor(576, 768), 1), "576x768 (the video's page): a unit is 1")
ok(near(M.unitFor(576, 1024), 1), "576x1024 (the video's frame): width is the limit, a unit is 1")
ok(M.unitFor(0, 0) === 1 && M.unitFor(NaN, 100) === 1 && M.unitFor(-5, 100) === 1, "a window with no size yet does not break the layout")

// ---- stagger: first part starts at 0, last ends at 1, everything in between is ordered ----
for (const [n, span] of [[1, 0.5], [2, 0.4], [8, 0.38], [13, 0.45]]) {
    let allZero = true, allOne = true, ordered = true
    for (let i = 0; i < n; i++) {
        if (M.stagger(0, i, n, span) !== 0) allZero = false
        if (M.stagger(1, i, n, span) !== 1) allOne = false
        if (i > 0 && M.stagger(0.5, i, n, span) > M.stagger(0.5, i - 1, n, span)) ordered = false
    }
    ok(allZero, `stagger n=${n}: nothing has started at reveal 0`)
    ok(allOne, `stagger n=${n}: everything is done at reveal 1`)
    ok(ordered, `stagger n=${n}: a later part is never ahead of an earlier one`)
}
ok(M.stagger(0.5, 0, 4, 0) === 0 && M.stagger(0.999, 3, 4, 0) === 0 && M.stagger(1, 3, 4, 0) === 1, "span 0: a hard switch at reveal 1 only")
ok(M.stagger(-1, 0, 3, 0.5) === 0 && M.stagger(5, 2, 3, 0.5) === 1, "reveal outside 0..1 is clamped")
let mono = true, prev = -1
for (let r = 0; r <= 1.0001; r += 0.01) { const v = M.stagger(r, 3, 8, 0.38); if (v < prev - 1e-12) mono = false; prev = v }
ok(mono, "one part only ever moves forward as the reveal grows")

// ---- easing ----
ok(M.easeOutBack(0) === 0 && near(M.easeOutBack(1), 1), "easeOutBack runs 0 -> 1")
let peak = 0; for (let t = 0; t <= 1; t += 0.01) peak = Math.max(peak, M.easeOutBack(t))
ok(peak > 1.05 && peak < 1.4, "easeOutBack hops a little past 1 (" + peak.toFixed(3) + ") but not wildly")
ok(M.easeOutBack(5) === M.easeOutBack(1) && M.easeOutBack(-3) === 0, "easeOutBack clamps its input")
ok(M.easeOutCubic(0) === 0 && M.easeOutCubic(1) === 1 && M.easeOutCubic(0.5) > 0.5, "easeOutCubic is fast at the start")

// ---- words and lines ----
assert.deepStrictEqual(M.splitLines("Welcome to SekaiPop,\nyour desktop"), [["Welcome", "to", "SekaiPop,"], ["your", "desktop"]])
ok(true, "splitLines: words and lines")
assert.deepStrictEqual(M.splitLines("  a   b \n\n c "), [["a", "b"], ["c"]])
ok(true, "splitLines: extra spaces and blank lines are dropped")
ok(M.splitLines("").length === 0 && M.splitLines(undefined).length === 0 && M.splitLines(null).length === 0, "splitLines: no text, no lines")
const ls = M.splitLines("a b c\nd e")
ok(M.wordCount(ls) === 5 && M.firstWordOf(ls, 0) === 0 && M.firstWordOf(ls, 1) === 3 && M.firstWordOf(ls, 9) === 5, "wordCount / firstWordOf count across lines")

// ---- the page counter ----
ok(M.pageLabel(0, 5) === "1/5" && M.pageLabel(4, 5) === "5/5", "the counter counts from 1")

// ---- moving between slides ----
assert.deepStrictEqual(M.step(0, 5, 1), { index: 1, finish: false, stay: false })
assert.deepStrictEqual(M.step(3, 5, 1), { index: 4, finish: false, stay: false })
assert.deepStrictEqual(M.step(4, 5, 1), { index: 4, finish: true, stay: false })
assert.deepStrictEqual(M.step(0, 5, -1), { index: 0, finish: false, stay: true })
assert.deepStrictEqual(M.step(2, 5, -1), { index: 1, finish: false, stay: false })
ok(true, "step: next, back, finish on the last slide, nothing before the first")
ok(M.step(0, 1, 1).finish === true && M.step(0, 1, -1).stay === true, "a one-slide tour: next finishes, back does nothing")

const K = { Escape: 1, Right: 2, Down: 3, Space: 4, Return: 5, Enter: 6, PageDown: 7, Left: 8, Up: 9, Backspace: 10, PageUp: 11 }
ok([2, 3, 4, 5, 6, 7].every(k => M.keyDirection(k, K) === 1), "Right / Down / Space / Enter / PageDown go forward")
ok([8, 9, 10, 11].every(k => M.keyDirection(k, K) === -1), "Left / Up / Backspace / PageUp go back")
ok(M.keyDirection(1, K) === 0, "Escape is the skip")
ok(M.keyDirection(99, K) === null, "any other key does nothing (so typing is not eaten)")

// ---- wobble: the same every time, inside -1..1, not all equal ----
const w = [0, 1, 2, 3, 4, 5, 6, 7].map(M.wobble)
ok(w.every(v => v >= -1 && v <= 1) && w.every((v, i) => v === M.wobble(i)), "wobble is steady and in range")
ok(new Set(w.map(v => v.toFixed(3))).size === w.length, "every letter tilts differently")

ok(/FINISH/.test(M.hintFor(4, 5)) && /CONTINUE/.test(M.hintFor(0, 5)) && /ESC/.test(M.hintFor(2, 5)), "the hint changes on the last slide and always says how to skip")

// ---- the slides ----
const kinds = ["logo", "glyph", "units", "frame", "credits"]
ok(S.SLIDES.length === 5, "five slides (the corner counter reads n/5, like the video)")
ok(S.SLIDES.every(s => kinds.includes(s.kind)), "every slide has a hero kind the page knows")
ok(S.SLIDES.every(s => typeof s.title === "string" && s.title.length > 0), "every slide has a title")
ok(S.SLIDES.every(s => s.kind === "credits" ? Array.isArray(s.lines) && s.lines.length > 0 : typeof s.sub === "string"), "every slide has its grey text")
ok(S.SLIDES.filter(s => s.kind === "glyph").every(s => /^[a-z0-9_]+$/.test(s.glyph)), "a glyph slide names a Material Symbols icon")
ok(S.SLIDES[0].ghost && S.SLIDES[S.SLIDES.length - 1].ghost && S.SLIDES.slice(1, -1).every(s => !s.ghost), "the ghost logo is on the first and last slide only, as in the video")
ok(S.SLIDES[0].top && S.SLIDES.slice(1).every(s => !s.top), "only the first slide has its title above the hero")
ok(kinds.every(k => S.heroMs(k) > 0) && S.heroMs("nope") > 0, "every hero has a duration")

ok(S.subOf({ sub: "grey" }) === "grey" && S.subOf({ lines: ["a", "b"] }) === "a\nb" && S.subOf({ sub: "x", lines: ["a"] }) === "a" && S.subOf(null) === "" && S.subOf({}) === "", "subOf: the grey text, or the lines of a credits slide joined")
ok(S.SLIDES.every(s => S.subOf(s) !== "" || s.kind === "logo"), "every slide but the first has grey text to show")
ok(["logo", "glyph", "units", "frame", "credits"].every(k => S.heroCenter(k) > 0.4 && S.heroCenter(k) < 0.6), "every hero sits near the middle of the screen")


// ---- the video's pace ----
ok(M.spring(0) === 0 && M.spring(1) === 1 && M.spring(-1) === 0 && M.spring(2) === 1, "spring runs 0 -> 1 and clamps its input")
{
    let pk = 0, pkAt = 0, fast = 0, mono = true, prev = -1, over = 0
    for (let p = 0; p <= 1.00001; p += 0.001) {
        const v = M.spring(p)
        if (v > pk) { pk = v; pkAt = p }
        if (fast === 0 && v >= 0.9) fast = p
    }
    // 90% of the size by about 6 frames (0.2 s) of a 0.62 s landing; a hop of 5..12%; the peak around the middle
    ok(pk > 1.05 && pk < 1.12, "spring hops about 8% past 1 like the video's hero (" + pk.toFixed(3) + ")")
    ok(fast * 0.62 > 0.12 && fast * 0.62 < 0.26, "spring is 90% of the way in about 6 frames (" + (fast * 0.62 * 1000).toFixed(0) + " ms)")
    ok(pkAt > 0.35 && pkAt < 0.55, "spring peaks around the middle of the landing (" + pkAt.toFixed(2) + ")")
    ok(Math.abs(M.spring(0.97) - 1) < 0.01, "spring has settled before the end, so the last stretch can't snap")
    ok(M.spring(0.5, 0.6) < M.spring(0.5) || M.spring(0.3, 0.6) < M.spring(0.3), "a slower rate (the logo) arrives later than the icons' pace")
    ok(M.spring(0, 0.6) === 0 && M.spring(1, 0.6) === 1 && Math.abs(M.spring(0.995, 0.6) - 1) < 0.01, "a slower spring still starts at 0 and ends exactly at 1 without a snap")
}
ok(M.captionMs(0, 0) === 1, "an empty caption still has a length (no division by zero)")
ok(M.captionMs(10, 0) === 9 * 70 + 160, "ten title words take 790 ms (the video's: about 0.8 s)")
ok(M.captionMs(3, 12) > M.captionMs(3, 0) && M.captionMs(7, 0) === 6 * 70 + 160, "the grey line can make a caption longer, never shorter")
ok(M.subStepMs(1) === 0 && M.subStepMs(5) === 40 && M.subStepMs(60) < 40 && 150 + 59 * M.subStepMs(60) <= 150 + 600 + 1e-9, "the grey line's word gap is squeezed when there are many words")
ok(M.captionMs(3, 60) < 1100, "even a long grey line stays under about a second")
ok(M.wordProgress(0, 800, 0, 160) === 0 && M.wordProgress(1, 800, 700, 160) === 1, "wordProgress is exactly 0 at 0 and exactly 1 at 1")
{
    let ordered = true
    for (let r = 0; r <= 1; r += 0.05)
        for (let i = 1; i < 6; i++)
            if (M.wordProgress(r, 600, i * 70, 160) > M.wordProgress(r, 600, (i - 1) * 70, 160) + 1e-12) ordered = false
    ok(ordered, "wordProgress: a later word is never ahead of an earlier one")
}
ok(S.HERO_MS.logo === M.LOGO_RUN_MS && S.HERO_MS.logo >= 2500 && S.HERO_MS.logo <= 3600 && S.HERO_MS.glyph <= 800 && S.HERO_MS.units <= 800 && S.HERO_MS.frame <= 800, "the page runs the logo for exactly as long as its timeline (WM.LOGO_RUN_MS, a relaxed 3 s: slower than the video's sped-up breakdown), the other heroes land well under a second")
ok(S.heroPose("logo").scale === 1 && S.heroPose("logo").openY === 1 && S.heroPose("logo").rise === 0 && S.heroPose("logo").rotate === 0, "the logo has no pose of its own: its letters do the popping")

// ---- the logo's run: a burst out of the middle, in ms ----
{
    const n = 11
    ok(M.BURST.length === n && M.LETTER_REST.length === n, "one burst and one resting pose for each of the 11 slots (5 + 3 letters and 3 kana)")
    let exact = true, mono = true
    for (let i = 0; i < n; i++) {
        if (M.letterProgress(0, i) !== 0 || M.letterProgress(1, i) !== 1 || M.burstSpring(0, i) !== 0 || M.burstSpring(1, i) !== 1) exact = false
        let prev = 0
        for (let r = 0; r <= 1; r += 0.005) { const v = M.letterProgress(r, i); if (v < prev - 1e-12) mono = false; prev = v }
    }
    ok(exact, "every slot is at exactly 0 at reveal 0 and exactly 1 at reveal 1 (its progress and its spring)")
    ok(mono, "no slot's progress ever goes backwards")
    const at = M.BURST.slice(0, 8).map(b => b.at)
    ok(!at.every((v, i) => i === 0 || v > at[i - 1]), "the letters do not come in left to right (a burst, not a text cursor)")
    ok(at[2] === Math.min(...at), "the letter in the middle of the word (the k) is the first to leave the middle")
    ok(new Set(at).size === 8, "no two letters start together")
    ok(new Set(M.BURST.map(b => b.zeta + "/" + b.omega)).size === n, "no two slots share a spring (each has its own damping and speed)")
    ok(new Set(M.BURST.map(b => b.tilt)).size === n && M.BURST.every(b => Math.abs(b.tilt) >= 20 && Math.abs(b.tilt) <= 60), "each slot starts at its own angle (20-60 degrees)")
    let peaksOk = true, peaks = []
    for (let i = 0; i < n; i++) {
        let peak = 0
        for (let p = 0; p <= 1; p += 0.002) peak = Math.max(peak, M.burstSpring(p, i))
        peaks.push(peak.toFixed(2))
        if (peak < 1.1 || peak > 1.3) peaksOk = false
    }
    ok(peaksOk, "every slot hops 10-30% past its size, each a different amount (" + peaks.join(" ") + ")")
    ok(M.BURST.every(b => b.dur >= 600), "each pop runs for at least 600 ms (not rushed)")
    const lettersEnd = Math.max(...M.BURST.slice(0, 8).map(b => b.at + b.dur))
    ok(M.BURST[8].at < lettersEnd && M.BURST[8].at > Math.min(...at), "the kana come in while the last letters are still landing, not before the burst and not after it")
    ok(M.BURST.every(b => b.at + b.dur <= 0.6 * M.LOGO_RUN_MS), "every pop is over by 60% of the run, leaving the rest for the combined pass")
    ok(M.BURST.slice(8).every(b => Math.abs(b.swirl) >= 0.25) && M.BURST.slice(0, 8).every(b => Math.abs(b.swirl) < 0.2), "the kana fly on arcs, the letters on nearly straight lines")
}
{
    ok(M.seg(0, 100, 200) === 0 && M.seg(1, 100, 200) === 1 && M.seg(100 / M.LOGO_RUN_MS, 100, 200) === 0 && near(M.seg(200 / M.LOGO_RUN_MS, 100, 200), 0.5), "seg: a stretch of the run starts at its start and takes its length")
    ok(M.seg(0.1, 500, 0) === 0 && M.seg(0.3, 500, 0) === 1, "seg: a length of 0 is a switch")
    const exact = [M.strokeRun, M.halftoneRun, M.squiggleRun, M.ignitionRun, M.warpRun, M.sweepRun, r => M.decorRun(r, 0), r => M.decorRun(r, 3)]
    ok(exact.every(f => f(0) === 0 && f(1) === 1), "every combined pass is exactly 0 at reveal 0 and exactly 1 at reveal 1")
    ok(exact.every(f => { let prev = 0, ok2 = true; for (let r = 0; r <= 1; r += 0.005) { const v = f(r); if (v < prev - 1e-12) ok2 = false; prev = v } return ok2 }), "no combined pass goes backwards")
    const lettersEnd = Math.max(...M.BURST.slice(0, 8).map(b => b.at + b.dur))
    ok(M.STROKE_AT > Math.min(...M.BURST.slice(0, 8).map(b => b.at)) && M.STROKE_AT < lettersEnd, "the light outer stroke starts growing while the letters are still arriving")
    ok(M.HALFTONE_AT > M.STROKE_AT && M.DECOR_AT > M.HALFTONE_AT && M.SQUIGGLE_AT > M.DECOR_AT, "the stroke, its halftone, the sparkles and the squiggle come one after the other")
    ok(M.WARP_AT >= lettersEnd, "the wave pass starts once every letter has landed")
    ok(M.SWEEP_AT >= M.WARP_AT && M.SWEEP_AT + M.SWEEP_MS <= M.WARP_AT + M.WARP_MS, "the light sweep crosses while the wave pass runs (the shader draws both)")
    const ends = [M.STROKE_AT + M.STROKE_MS, M.HALFTONE_AT + M.HALFTONE_MS, M.DECOR_AT + 3 * M.DECOR_GAP + M.DECOR_MS, M.SQUIGGLE_AT + M.SQUIGGLE_MS, M.WARP_AT + M.WARP_MS, M.IGNITION_MS]
    ok(Math.max(...ends) <= M.LOGO_RUN_MS - 200, "everything is done at least 200 ms before the run ends: the logo settles still, with no tail")
    ok(M.warpAmount(0) === 0 && M.warpAmount(1) === 0 && near(M.warpAmount(0.5), 1), "the wave's strength is 0 before and after and 1 in the middle (the word is undistorted when the pass starts and ends)")
    ok(M.warpPhase(0) === 0 && M.warpPhase(1) > 2 * Math.PI, "the wave travels: its phase turns more than a full cycle over the pass")
    let sweepMono = true, prev = -9
    for (let u = 0; u <= 1; u += 0.01) { const v = M.sweepPos(u); if (v < prev) sweepMono = false; prev = v }
    ok(sweepMono && M.sweepPos(0) < 0 && M.sweepPos(1) > 1, "the light sweep starts off the word on the left, ends off it on the right and never goes back")
    ok(M.IGNITION_MS < M.BURST[1].at + M.BURST[1].dur && M.ignitionRun(0.5 * M.IGNITION_MS / M.LOGO_RUN_MS) > 0.4, "the ignition at the centre plays at the start, while the first letters leave it")
}
// ---- the word's own textures: one field over all the letters ----
{
    const fx = [M.fxWaveRun, M.fxDotsRun, M.fxMatteRun, M.fxShineRun]
    ok(fx.every(f => f(0) === 0 && f(1) === 1), "every texture of the word is exactly 0 at reveal 0 and exactly 1 at reveal 1")
    ok(fx.every(f => { let prev = 0, good = true; for (let r = 0; r <= 1; r += 0.005) { const v = f(r); if (v < prev - 1e-12) good = false; prev = v } return good }), "no texture of the word goes backwards")
    const lastStart = Math.max(...M.BURST.slice(0, 8).map(b => b.at))
    const lettersEnd = Math.max(...M.BURST.slice(0, 8).map(b => b.at + b.dur))
    const starts = [M.FX_WAVE_AT, M.FX_DOTS_AT, M.FX_MATTE_AT, M.FX_SHINE_AT]
    ok(starts.every(t => t > lastStart), "the textures start once every letter has left the middle (a letter is never the only one without them)")
    ok(starts.every(t => t >= 0.75 * lettersEnd), "and while the last letters are only settling, not before they are on their way")
    ok(starts.every((t, i) => i === 0 || t > starts[i - 1]), "wave, then the halftone's shading, then the matte band, then the shine: one after the other, the same order for every letter")
    ok(M.FX_SHINE_AT + M.FX_SHINE_MS <= M.WARP_AT + 100 && M.FX_MATTE_AT + M.FX_MATTE_MS <= M.WARP_AT + 100, "the word's texture passes are over (or nearly) when the combined wave pass begins")
}
// ---- the exit: everything collapses into the middle ----
{
    const n = 11
    let exact = true, endsOk = true
    for (let i = 0; i < n; i++) {
        if (M.leaveProgress(0, i) !== 0 || M.leaveProgress(1, i) !== 1) exact = false
        const dur = i >= 8 ? M.LEAVE_KANA_MS : M.LEAVE_LETTER_MS
        if (M.leaveStart(i) + dur > M.LOGO_LEAVE_MS) endsOk = false
    }
    ok(exact, "leaveProgress: exactly 0 when the exit has not started and exactly 1 when it is over, for every slot")
    ok(endsOk, "every slot has gone into the middle before the exit's last frame")
    ok(M.leaveStart(8) < Math.min(...Array.from({ length: 8 }, (_, i) => M.leaveStart(i))) || M.leaveStart(8) === 0, "the kana are the first to go")
    ok(M.leaveStart(7) <= M.leaveStart(5) && M.leaveStart(5) < M.leaveStart(2) && M.leaveStart(7) === 0, "the last letters to come in are the first to go (the exit mirrors the entrance)")
    ok(M.collapse(0) === 0 && M.collapse(1) === 1, "collapse: starts at 0 and ends exactly at 1")
    let lo = 0
    for (let t = 0; t <= 1; t += 0.005) lo = Math.min(lo, M.collapse(t))
    ok(lo < -0.03 && lo > -0.15, "collapse draws a short breath outward before the pull (" + lo.toFixed(3) + "), not a lunge")
    let mono = true, prev = M.collapse(0.41)
    for (let t = 0.41; t <= 1; t += 0.005) { const v = M.collapse(t); if (v < prev - 1e-12) mono = false; prev = v }
    ok(mono, "after the breath, collapse only ever moves inward")
    ok(M.leaveDecor(0) === 0 && M.leaveDecor(1) === 1 && M.leaveStroke(0) === 0 && M.leaveStroke(1) === 1, "the sparkles and the stroke leave exactly from 0 to 1")
    ok(M.leaveStroke(0.25) < 0.1 && M.leaveDecor(0.25) > 0.5, "the sparkles go first and the stroke lets go later")
    ok(M.leaveFlash(0) === 0 && M.leaveFlash(1) === 0 && M.leaveFlash(0.3) === 0 && M.leaveFlash(0.85) > 0.9, "the small flash where everything meets comes at the very end and is 0 at both ends")
    ok(S.leaveMs("logo") === M.LOGO_LEAVE_MS && S.leaveMs("glyph") === 180 && S.leaveMs("units") === 180 && S.leaveMs("nope") === 180, "the page leaves the logo for as long as its collapse takes and the other heroes quickly")
}
{
    ok(M.springEx(0, 0.5, 16, 0.7) === 0 && M.springEx(1, 0.5, 16, 0.7) === 1 && M.springEx(-1, 0.5, 16, 0.7) === 0 && M.springEx(2, 0.5, 16, 0.7) === 1, "springEx: exactly 0 at the start and exactly 1 at the end")
    let a = 0, b = 0
    for (let p = 0; p <= 1; p += 0.002) { a = Math.max(a, M.springEx(p, 0.35, 16, 0.7)); b = Math.max(b, M.springEx(p, 0.6, 16, 0.7)) }
    ok(a > b && b > 1.05, "springEx: less damping hops further past the size (" + a.toFixed(2) + " vs " + b.toFixed(2) + ")")
    ok(M.popSpring(0.4) === M.springEx(0.4, M.POP_ZETA, M.POP_OMEGA, M.POP_SECONDS), "popSpring is springEx with the logo's own numbers")
    ok(M.popSpring(0) === 0 && M.popSpring(1) === 1 && M.popSpring(-1) === 0 && M.popSpring(2) === 1, "popSpring: exactly 0 at the start and exactly 1 at the end")
    let peak = 0, at = 0, tail = true
    for (let i = 0; i <= 1000; i++) { const p = i / 1000, v = M.popSpring(p); if (v > peak) { peak = v; at = p } if (p > 0.9 && Math.abs(v - 1) > 0.03) tail = false }
    ok(peak > 1.15 && peak < 1.35, "popSpring hops about a fifth past its size (" + peak.toFixed(3) + ")")
    ok(at > 0.15 && at < 0.4, "popSpring: the hop is at the front of the pop (" + at.toFixed(2) + ")")
    ok(tail, "popSpring: settled to within 3% by 90% of the pop")
    let under = false
    for (let i = 300; i <= 700; i++) if (M.popSpring(i / 1000) < 0.97) under = true
    ok(under, "popSpring swings back under its size once before it settles (a spring, not an ease)")
    ok(M.layerRun(0, 0.3, 0.4) === 0 && M.layerRun(1, 0.3, 0.4) === 1 && M.layerRun(0.3, 0.3, 0.4) === 0 && near(M.layerRun(0.5, 0.3, 0.4), 0.5) && M.layerRun(0.9, 0.3, 0.4) === 1, "layerRun: a layer starts at its delay and takes its span")
    ok(M.layerRun(0.2, 0.5, 0) === 0 && M.layerRun(0.6, 0.5, 0) === 1, "layerRun: a span of 0 is a switch")
    // the layers come in one on top of the other (rim, shadow, wave, halftone, shine)
    const starts = [0.04, 0.16, 0.3, 0.45, 0.6]
    ok(starts.every((v, i) => i === 0 || v > starts[i - 1]), "the layers of a letter start one after the other")
}
ok(near(M.squash(0), 0) && near(M.squash(1), 0) && near(M.squash(0.5), 1) && near(M.squash(-1), 0) && near(M.squash(2), 0), "squash is 0 at both ends of a pop and 1 in the middle")
ok(M.LETTER_REST.length === 11 && M.LETTER_REST.every(r => Math.abs(r[0]) <= 8 && Math.abs(r[1]) <= 0.06), "every letter rests a little crooked, within a few degrees")
ok(new Set(M.LETTER_REST.map(r => r[0] + "/" + r[1])).size === 11, "no two letters rest the same way (randomized placement)")
ok(M.letterRest(99)[0] === 0 && M.letterRest(99)[1] === 0 && M.letterRest(2) === M.LETTER_REST[2], "letterRest: an unknown slot sits straight")
ok([ "logo", "glyph", "units", "frame", "credits" ].every(k => { const q = S.heroPose(k); return q.scale > 0 && q.scale <= 1 && q.openY > 0 && q.openY <= 1 && q.rise >= 0 && q.rate > 0 && q.rate <= 1 }), "every hero has a starting pose")
ok(S.heroPose("nope") === S.HERO_POSE.glyph, "an unknown hero lands like an icon")
ok(S.heroPose("units").openY < 0.2 && S.heroPose("frame").openY < 0.2 && S.heroPose("units").scale === 1, "the band and the picture open up from a thin line, at full width")

// ---- the QML, as text (Quickshell can't run here) ----
const read = rel => fs.readFileSync(path.join(top, rel), "utf8")
const dir = path.join(top, "modules", "sekai", "welcome")
const files = fs.readdirSync(dir).filter(f => f.endsWith(".qml"))
const types = new Set(files.map(f => f.replace(".qml", "")))
ok(files.length === 14, "the welcome folder has its 14 components (" + files.length + ")")
for (const f of files.concat(["../../../services/WelcomeService.qml"])) {
    const src = fs.readFileSync(path.join(dir, f), "utf8")
    // strings first (a "file://" would otherwise look like the start of a comment), then comments
    const code = src.replace(/"(?:[^"\\]|\\.)*"/g, '""').replace(/\/\/.*$/gm, "")
    const count = c => code.split(c).length - 1
    ok(count("{") === count("}") && count("(") === count(")") && count("[") === count("]"), f + ": brackets balance")
    // a Welcome* type used somewhere must be a file that exists (catches a typo or a deleted file)
    const used = new Set((code.match(/\bWelcome[A-Z][A-Za-z]*(?=\s*\{)/g) || []))
    const missing = [...used].filter(t => !types.has(t))
    ok(missing.length === 0, f + ": every Welcome* type it uses exists" + (missing.length ? " (missing: " + missing.join(", ") + ")" : ""))
}
const shellQml = read("shell.qml")
ok(/^import qs\.modules\.sekai\.welcome$/m.test(shellQml) && /^\s*WelcomeScreen \{\}$/m.test(shellQml), "shell.qml imports the welcome folder and creates WelcomeScreen")
const svc = read("services/WelcomeService.qml")
ok(["show", "hide", "toggle", "reset", "dismiss", "status"].every(f => new RegExp("function " + f + "\\(").test(svc)) && /target: "welcome"/.test(svc), "the service answers `ipc call welcome` show / hide / toggle / reset / dismiss / status")
const svcCode = svc.replace(/\/\/.*$/gm, "")
ok(/GameModeService\.loaded/.test(svcCode) && /GameModeService\.enabled/.test(svcCode), "the service waits for Game Mode's state and looks at it")
ok(/function open\(\) \{\s*if \(root\.active \|\| GameModeService\.enabled\)/.test(svcCode), "open() (so `ipc call welcome show` too) does nothing while Game Mode is on")
ok(/target: GameModeService[\s\S]*onEnabledChanged[\s\S]*beginClose\(\)/.test(svcCode), "the screen closes itself when Game Mode comes on")
// the first-run check counts a try, so it must not even be asked while Game Mode is on
const delayBlock = svcCode.split("id: startDelay")[1].split("Process {")[0]
ok(/GameModeService\.enabled/.test(delayBlock) && /checker\.running = true/.test(delayBlock) && delayBlock.indexOf("GameModeService.enabled") < delayBlock.indexOf("checker.running = true"), "the first-run check is not run (no try is spent) while Game Mode is on")
ok(/state\/welcome-state\.sh/.test(svc) && fs.existsSync(path.join(top, "scripts", "state", "welcome-state.sh")), "the service points at a script that exists")
const page = read("modules/sekai/welcome/WelcomePage.qml")
ok(!/import Quickshell/.test(page) && !/import qs\.services/.test(page), "WelcomePage knows nothing about Quickshell or services (so it can be drawn and tested on its own)")
ok(/signal leaveRequested/.test(page) && /signal exited/.test(page), "WelcomePage reports leaveRequested and exited")
const swapBlock = page.replace(/\/\/.*$/gm, "").split("id: swapAnim")[1].split("id: exitAnim")[0]
ok(swapBlock.length > 200 && !/root\.slide\b/.test(swapBlock), "the slide-swap animation never reads root.slide for a `to` or a `duration` (a NumberAnimation reads them when the whole sequence starts, so they would describe the slide being left; go() sets ghostDuring / ghostAfter / heroMsAfter first)")


const codeOf = f => read(f).replace(/\/\/.*$/gm, "")
ok(/property bool leaving: false/.test(page) && /root\.leaving \? 1 : root\.heroIn/.test(page), "leaving: the hero stays built while it goes (nothing unbuilds backwards)")
ok(/together: root\.leaving/.test(page), "leaving: the caption goes out as one block")
ok(/WM\.spring\(root\.heroIn, heroBox\.pose\.rate\)/.test(page) && /heroPose\(root\.slide\.kind\)/.test(page), "the hero lands on the spring, from its own starting pose")
ok(/root\.textMsAfter/.test(swapBlock) && /root\.heroMsAfter/.test(swapBlock) && /textMsAfter = WM\.captionMs/.test(page), "the slide swap uses the caption length of the slide it is going to (go() sets textMsAfter first)")
const intro = page.replace(/\/\/.*$/gm, "").split("id: introAnim")[1].split("id: swapAnim")[0]
ok(/duration: root\.textMs/.test(intro), "the intro runs the caption at its own word pace")
ok(/timed: true/.test(codeOf("modules/sekai/welcome/WelcomeCaption.qml")) && /WM\.captionMs/.test(codeOf("modules/sekai/welcome/WelcomeCaption.qml")), "the caption words come in on the video's timings")

// ---- the logo's structure: one set of textures for the word, not one per letter ----
{
    const logo = codeOf("modules/sekai/welcome/WelcomeLogo.qml")
    const letter = codeOf("modules/sekai/welcome/WelcomeLetter.qml")
    const pop = codeOf("modules/sekai/welcome/WelcomePopLetter.qml")
    ok((logo.match(/part: "back"/g) || []).length >= 2 && (logo.match(/part: "face"/g) || []).length >= 2, "the logo builds every letter of both lines twice, a back (rim and extrusion) and a face")
    ok(/id: fxGroup/.test(logo) && (logo.match(/id: fxGroup/g) || []).length === 1 && /id: wordDots/.test(logo) && /id: wordShine/.test(logo), "the logo has ONE texture group: one halftone and one shine for the whole word")
    ok(/maskSource: faces1Tex/.test(logo) && /maskSource: faces2Tex/.test(logo) && /source: fxTex/.test(logo), "the textures are shown through the faces of each line (a track matte), and a line's outlines sit behind that line's faces")
    ok(/z: 4/.test(logo) && /z: 1/.test(logo), "the second line's backs are above the first line's textures (Pop is in front of Sekai)")
    ok(!/halftone: cell\.dots[\s\S]{0,40}part/.test(logo) || /part: cell\.part/.test(logo), "each cell passes its half to its letter")
    ok(/readonly property bool localFx: root\.part === "all"/.test(letter) && /visible: root\.localFx/.test(letter), "a letter's own halftone, waves and shine exist only as a whole letter (the icon of the second slide), never in the logo's halves")
    ok(!/sourceItem: root\.show/.test(letter), "a part that is off is emptied, never unhooked (a ShaderEffectSource with no source un-hides the raw item)")
    ok(!/root\.slot \* 0\.8|root\.slot \* 1\.1/.test(pop) && /idleSkew/.test(pop) && /idleSkew/.test(logo), "the letters float on one wave through the word, not each on a phase of its own")
    ok(/fxPhase/.test(logo) && /wavePoly/.test(logo) && !/waveBand/.test(logo), "the wave texture is one set of bands with one phase in the logo's coordinates")
}
// ---- the combined stroke: an even outline that is never cut off ----
{
    const logo = codeOf("modules/sekai/welcome/WelcomeLogo.qml")
    ok(/model: 28/.test(logo) && /id: dilGroup/.test(logo) && /id: dilTex/.test(logo) && /root\.strokeR \* Math\.cos\(angle\)/.test(logo), "the stroke is the logo's silhouette drawn 28 times round a circle: the same width all the way round every curve")
    ok(!/maskThresholdMin/.test(logo), "the stroke is no longer a blur cut at a level (that made a blob that bridged the letters)")
    ok((logo.match(/maskSource: dilTex/g) || []).length === 3, "the stroke, its shadow and its halftone are all cut to the same outline, so the dots stay inside the stroke")
    ok(/readonly property real strokeR: root\.strokeFull \* root\.strokeK/.test(logo) && !/scale: root\.leaving \? 0\.35/.test(logo), "the stroke grows and shrinks by its width, not by scaling, so it hugs the letters the whole time")
    const pad = +/readonly property real pad: (\d+) \* root\.unit/.exec(logo)[1]
    const full = +/readonly property real strokeFull: (\d+) \* root\.unit/.exec(logo)[1]
    const shadow = +/id: haloShade[\s\S]*?y: (\d+) \* root\.unit/.exec(logo)[1]
    // the kana stand 0.30 of the letter size above the first line's top, the highest thing in the logo
    ok(pad - 0.30 * 114 >= full + shadow + 10, "the margin (" + pad + ") is wider than the stroke (" + full + ") and its shadow (" + shadow + ") even above the kana: nothing reaches the edge, where it would be cut off flat")
    ok(/welcome_halo\.frag\.qsb/.test(logo) && fs.existsSync(path.join(top, "shaders", "welcome_halo.frag")) && fs.existsSync(path.join(top, "shaders", "welcome_halo.frag.qsb")), "the stroke's halftone shader and its compiled file are there")
    ok(/onIdlingChanged: if \(!root\.idling\) root\.glint = 0/.test(logo), "a glint is reset when the idling stops, so it cannot hang over the letters while they collapse")
}
// ---- the ink measurement and the wave texture ----
{
    const logo = codeOf("modules/sekai/welcome/WelcomeLogo.qml")
    const letter = codeOf("modules/sekai/welcome/WelcomeLetter.qml")
    // tightBoundingRect() is a plain method: a binding that calls it is not run again when the font or the size
    // changes later, and the measurement stays that of the default 9 px font. Every call must read the
    // metrics' ascent first (those do announce the change), and so is run again with the real font.
    const calls = (logo + "\n" + letter).split("\n").filter(l => /tightBoundingRect\(/.test(l))
    ok(calls.length === 3 && calls.every(l => /\.ascent \+ \w+\.descent > 0/.test(l)), "every tightBoundingRect() call reads the metrics' ascent and descent first, so it is measured again when the font or the size arrives (" + calls.length + " calls)")
    ok(/waveSheet/.test(logo) && /waveLine\(/.test(logo) && (logo.match(/ShapePath \{/g) || []).length >= 6, "the wave texture has a body and a second wave for each line and a crest line on each")
    ok(/readonly property color waveDeep: Qt\.darker\(root\.fill/.test(logo) && /readonly property color waveMid: Qt\.darker\(root\.fill/.test(logo) && /readonly property color waveCrest: Qt\.tint\(root\.fill/.test(logo) && !/waveDeep: Qt\.tint/.test(logo), "the wave's tones are shades of the letter's own colour (the dark ink pulled them toward grey)")
    ok(/root\.idleAmp \* root\.idle \/ \(2 \* Math\.PI\) \* 2/.test(logo), "the ripple travels two whole wavelengths per turn of the idle phase (visibly, and the loop is seamless)")
    const amps = [...logo.matchAll(/h \* (0\.\d+) \* waveSheet\.swell/g)].map(m => +m[1])
    const amp = Math.max(...amps)
    ok(amps.length >= 4 && amp >= 0.1 && amp <= 0.2, "the main wave's ripple is clearly a ripple (" + amp + " of the letters' height), not a flat band")
}
// ---- welcome-state.sh, the real script, in a throwaway state folder ----
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "welcome-test-"))
const script = path.join(top, "scripts", "state", "welcome-state.sh")
const run = a => execFileSync("sh", [script, a], { env: { ...process.env, XDG_STATE_HOME: tmp, HOME: tmp }, encoding: "utf8" }).trim()
ok(run("status") === "none", "state: nothing remembered at first")
ok(run("check") === "SHOW" && run("status") === "1", "state: the first check shows it and counts try 1")
ok(run("check") === "SHOW" && run("check") === "SHOW" && run("status") === "3", "state: three tries in all")
ok(run("check") === "SKIP" && run("status") === "3", "state: after three tries without finishing it stays away (no start-up loop)")
run("reset")
ok(run("status") === "none" && run("check") === "SHOW", "state: reset starts over")
run("done")
ok(run("status") === "done" && run("check") === "SKIP", "state: done means never again by itself")
ok(fs.existsSync(path.join(tmp, "sekaipop", "welcome")) && !fs.existsSync(path.join(tmp, "sekaipop", "welcome.tmp")), "state: one file, no temp file left behind")
fs.writeFileSync(path.join(tmp, "sekaipop", "welcome"), "garbage!\n")
ok(run("check") === "SHOW", "state: a damaged file counts as no tries instead of breaking")
let bad = false
try { execFileSync("sh", [script, "nonsense"], { env: { ...process.env, XDG_STATE_HOME: tmp }, stdio: "pipe" }) } catch (e) { bad = e.status === 2 }
ok(bad, "state: an unknown word exits with 2")
fs.rmSync(tmp, { recursive: true, force: true })

console.log(fails === 0 ? "\nall passed" : "\n" + fails + " FAILED")
process.exit(fails === 0 ? 0 : 1)
