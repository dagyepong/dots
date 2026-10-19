.pragma library

// Pure logic for the welcome screen (no Quickshell or QtQuick imports, so
// tests/welcome-test/welcome_unit.js can run it under node).
//
// The whole screen is driven by a few "progress" numbers that run 0 -> 1 (the
// hero coming in, the caption coming in, ...). Nothing here knows about time:
// the QML animates the numbers, and these functions turn one number into the
// look of each part (which word is how far in, how big a letter has sprung).
// That is also what makes it testable: feed a number, check the result.
//
// Top-level values use `var` on purpose: QML JS libraries don't reliably
// export top-level const/let.

// The page everything is laid out on: 576 x 768 design units (3:4), the
// proportions of the page in the reference video. One "unit" is 1/768 of the
// screen's height, so the composition keeps its shape on any monitor.
var DESIGN_W = 576;
var DESIGN_H = 768;

function unitFor(width, height) {
    var u = Math.min(height / DESIGN_H, width / DESIGN_W);
    return (isFinite(u) && u > 0.2) ? u : 1;
}

function clamp01(v) {
    return v < 0 ? 0 : (v > 1 ? 1 : v);
}

// Local progress of the i-th of n staggered parts when the whole run is `reveal`
// (0..1). Every part takes `span` of the run; the first starts at 0 and the last
// ends at 1, the others are spread evenly in between. span 1 = they all move
// together; a small span = a clear one-after-the-other.
function stagger(reveal, i, n, span) {
    // The ends are exact on purpose: a part that sits at 0.9999999 instead of 1
    // would never count as "arrived", and the QML switches its blur layer off
    // only once it has.
    if (reveal <= 0)
        return 0;
    if (reveal >= 1)
        return 1;
    var s = clamp01(span);
    if (s <= 0)
        return 0;
    var start = n > 1 ? i * (1 - s) / (n - 1) : 0;
    return clamp01((reveal - start) / s);
}

// The springy overshoot the letters of the logo pop in with (CSS "easeOutBack"):
// 0 -> 1 with a little hop past 1 on the way. `overshoot` 1.7 is the usual feel.
function easeOutBack(t, overshoot) {
    var c1 = (overshoot === undefined) ? 1.9 : overshoot;
    var c3 = c1 + 1;
    var x = clamp01(t) - 1;
    return 1 + c3 * x * x * x + c1 * x * x;
}

function easeOutCubic(t) {
    var x = 1 - clamp01(t);
    return 1 - x * x * x;
}

// "Welcome to SekaiPop,\nyour desktop" -> [["Welcome","to","SekaiPop,"],["your","desktop"]]
// Lines come from "\n"; words from spaces. Empty text gives no lines.
function splitLines(text) {
    var out = [];
    var lines = String(text === undefined || text === null ? "" : text).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var words = lines[i].split(" ").filter(function (w) { return w.length > 0; });
        if (words.length > 0)
            out.push(words);
    }
    return out;
}

// How many words in all (the n for stagger()).
function wordCount(lines) {
    var n = 0;
    for (var i = 0; i < lines.length; i++)
        n += lines[i].length;
    return n;
}

// Index of the first word of line `line` among all the words.
function firstWordOf(lines, line) {
    var n = 0;
    for (var i = 0; i < line && i < lines.length; i++)
        n += lines[i].length;
    return n;
}

// "1/5": what the bottom-left corner shows. `index` counts from 0.
function pageLabel(index, count) {
    return (index + 1) + "/" + count;
}

// What a "next" (+1) or "back" (-1) does on slide `index` of `count`:
//   { index, finish }   finish: true means "next" was pressed on the last slide
//   { index, stay: true } means nothing to do (back on the first slide)
function step(index, count, dir) {
    var last = count - 1;
    if (dir > 0) {
        if (index >= last)
            return { index: last, finish: true, stay: false };
        return { index: index + 1, finish: false, stay: false };
    }
    if (index <= 0)
        return { index: 0, finish: false, stay: true };
    return { index: index - 1, finish: false, stay: false };
}

// Which way a key moves the slides: +1 forward, -1 back, 0 for "skip" (Esc),
// null when the key does nothing here. `key` is a Qt.Key_* number; the QML
// passes the few it knows by name.
function keyDirection(key, keys) {
    if (key === keys.Escape)
        return 0;
    if (key === keys.Right || key === keys.Down || key === keys.Space
            || key === keys.Return || key === keys.Enter || key === keys.PageDown)
        return 1;
    if (key === keys.Left || key === keys.Up || key === keys.Backspace || key === keys.PageUp)
        return -1;
    return null;
}

// A small, fixed wobble for item `i` (-1..1), so the letters of the logo each
// tilt a different way and the same way every time (no random numbers: the
// screen looks the same on every start, and tests can check it).
function wobble(i) {
    var v = Math.sin((i + 1) * 12.9898) * 43758.5453;
    return (v - Math.floor(v)) * 2 - 1;
}

// The small line at the bottom centre that says how to move on. The last slide
// asks for a finish instead of a "next".
function hintFor(index, count) {
    var last = index >= count - 1;
    return (last ? "CLICK OR PRESS ENTER TO FINISH" : "CLICK OR PRESS \u2192 TO CONTINUE") + "   \u00b7   ESC TO SKIP";
}

// ---- the pace of the reference video, measured at 30 fps ----
//
// A word of a caption starts to sharpen every 70 ms and takes 160 ms to do it;
// the grey line under a title starts 150 ms after the title does and runs a
// little quicker. So a caption takes as long as its words need (a short title
// is quick, a long sentence is not slowed down or sped up to fit one fixed
// time), and the page runs a 0..1 number over captionMs() to drive it.
var CAPTION = { stepMs: 70, wordMs: 160, subDelayMs: 150, subWordMs: 160, subStepMaxMs: 40, subBudgetMs: 600 };

// Gap between the starts of two words of the grey line: 40 ms, squeezed when
// there are so many words that the whole line would take longer than 600 ms.
function subStepMs(nSub) {
    return nSub > 1 ? Math.min(CAPTION.subStepMaxMs, CAPTION.subBudgetMs / (nSub - 1)) : 0;
}

// How long a caption of `nTitle` and `nSub` words takes to come in, in ms.
function captionMs(nTitle, nSub) {
    var t = nTitle > 0 ? (nTitle - 1) * CAPTION.stepMs + CAPTION.wordMs : 0;
    var s = nSub > 0 ? CAPTION.subDelayMs + (nSub - 1) * subStepMs(nSub) + CAPTION.subWordMs : 0;
    return Math.max(1, t, s);
}

// Progress of one word that starts `startMs` into a run of `totalMs` and takes
// `wordMs` to arrive, when the run is at `reveal` (0..1). Exactly 0 at 0 and
// exactly 1 at 1 (the QML switches a word's blur layer off only on arrival).
function wordProgress(reveal, totalMs, startMs, wordMs) {
    if (reveal <= 0)
        return 0;
    if (reveal >= 1)
        return 1;
    if (wordMs <= 0)
        return 0;
    return clamp01((reveal * totalMs - startMs) / wordMs);
}

// How a hero lands: a damped spring (the video's logo and icons reach about 90%
// of their size in 6 frames, hop about 8% past it and settle in half a second).
// `p` runs 0 -> 1 over SPRING_SECONDS; the result runs 0 -> about 1.08 -> 1.
// `rate` (default 1) slows it down: 0.6 plays only the first 60% of those
// seconds, so the hop comes later and the landing is gentler (the video's logo
// grows over most of a second while it is being built).
var SPRING_ZETA = 0.62;
var SPRING_OMEGA = 14.5;
var SPRING_SECONDS = 0.62;

function spring(p, rate) {
    if (p <= 0)
        return 0;
    if (p >= 1)
        return 1;
    var t = p * SPRING_SECONDS * ((rate === undefined || rate <= 0) ? 1 : rate);
    var zw = SPRING_ZETA * SPRING_OMEGA;
    var wd = SPRING_OMEGA * Math.sqrt(1 - SPRING_ZETA * SPRING_ZETA);
    var x = 1 - Math.exp(-zw * t) * (Math.cos(wd * t) + (zw / wd) * Math.sin(wd * t));
    // the last stretch is blended into exactly 1, so the end never snaps
    var k = clamp01((p - 0.85) / 0.15);
    return x + (1 - x) * k * k * (3 - 2 * k);
}

// ---- the logo: one run, laid out in milliseconds ----
//
// The logo is a composition of separately animated layers, not one image that
// scales. Its run is a number `reveal` (0..1) that the page animates over
// LOGO_RUN_MS; every layer owns a stretch of that run (seg()), so the whole
// choreography is read from this one table and nothing is timed by hand in QML.
//
//     0 ms   central ignition: a flash, a ring and a soft glow at the middle
//     0..520 the letters start to burst out of the middle, in a scattered order
//            (not left to right), each on its own spring (BURST)
//   820..    the kana come in on arcs, overlapping the last letters
//   700..    the light outer stroke grows round the word
//   950..    the stroke's halftone comes up
//  1000..    the word's own textures, ONE field over all the letters (not one per
//            letter): the wave texture rises, the halftone's shading comes up, a
//            single matte band crosses the whole word, a single hard shine
//            crosses it. The letters are only the matte they are seen through,
//            so a letter that lands late is already inside the running texture
//  1250..    the sparkles and the squiggle
//  2000..    a wave travels through the whole word while a light sweep crosses it
//  ~3000     everything is still; the last 200 ms are margin
//
// Every function here is exactly 0 at reveal 0 and exactly 1 at reveal 1, so a
// layer is never left at 0.9999 (the QML drops a layer's blur and effect only
// when it has arrived).
var LOGO_RUN_MS = 3200;
// The exit: everything collapses into the middle in this long.
var LOGO_LEAVE_MS = 560;

function seg(reveal, startMs, durMs) {
    if (reveal <= 0)
        return 0;
    if (reveal >= 1)
        return 1;
    if (durMs <= 0)
        return reveal * LOGO_RUN_MS >= startMs ? 1 : 0;
    return clamp01((reveal * LOGO_RUN_MS - startMs) / durMs);
}

// How a spring with its own damping (zeta) and speed (omega) runs 0 -> past 1 ->
// 1, over `seconds` of spring time as `p` runs 0 -> 1. The page's `spring` and
// the logo's `popSpring` are this with fixed numbers. Overshoot is
// exp(-pi * zeta / sqrt(1 - zeta^2)): zeta 0.5 hops about 16% past the size.
function springEx(p, zeta, omega, seconds) {
    if (p <= 0)
        return 0;
    if (p >= 1)
        return 1;
    var t = p * seconds;
    var zw = zeta * omega;
    var wd = omega * Math.sqrt(1 - zeta * zeta);
    var x = 1 - Math.exp(-zw * t) * (Math.cos(wd * t) + (zw / wd) * Math.sin(wd * t));
    // the last stretch is blended into exactly 1, so the end never snaps
    var k = clamp01((p - 0.8) / 0.2);
    return x + (1 - x) * k * k * (3 - 2 * k);
}

var POP_ZETA = 0.42;
var POP_OMEGA = 17;
var POP_SECONDS = 0.72;

function popSpring(p) {
    return springEx(p, POP_ZETA, POP_OMEGA, POP_SECONDS);
}

// The layers of one letter do not come in together (the video's breakdown
// builds them one on top of the other: base, outline, extrusion, halftone,
// wave texture, shine). `layerRun` is the part of a letter's pop (0..1) that
// one layer owns: it starts `delay` into the pop and takes `span` of it. Exactly
// 0 at p = 0 and exactly 1 at p = 1.
function layerRun(p, delay, span) {
    if (p <= 0)
        return 0;
    if (p >= 1)
        return 1;
    if (span <= 0)
        return p >= delay ? 1 : 0;
    return clamp01((p - delay) / span);
}

// Slots 0..4 are "Sekai", 5..7 "Pop", 8..10 the three kana.
//
// Each slot has its own character, so no two letters pop alike:
//   at, dur   when its pop starts and how long it runs (ms into the logo's run)
//   zeta,omega  its own spring: how far it hops past its size, how fast it swings
//   tilt      the angle it starts at, in degrees (it swings through upright)
//   swirl     how far its flight bends sideways (fraction of its distance from
//             the middle; the kana bend a lot more, they arrive on arcs)
// The order is k, e, a, S, o, i, P, p: it starts in the middle of the word and
// jumps about, which reads as a burst, not as typing.
var BURST = [
    { at: 250, dur: 720, zeta: 0.50, omega: 16.5, tilt: -36, swirl:  0.10 },
    { at:  90, dur: 760, zeta: 0.46, omega: 17.5, tilt:  30, swirl: -0.08 },
    { at:   0, dur: 780, zeta: 0.52, omega: 16.0, tilt: -24, swirl:  0.06 },
    { at: 170, dur: 740, zeta: 0.48, omega: 18.0, tilt:  40, swirl: -0.12 },
    { at: 350, dur: 700, zeta: 0.54, omega: 17.0, tilt: -30, swirl:  0.09 },
    { at: 430, dur: 760, zeta: 0.47, omega: 16.8, tilt:  34, swirl: -0.07 },
    { at: 300, dur: 720, zeta: 0.51, omega: 17.2, tilt: -42, swirl:  0.11 },
    { at: 520, dur: 740, zeta: 0.49, omega: 17.8, tilt:  28, swirl: -0.10 },
    { at: 820, dur: 620, zeta: 0.50, omega: 17.0, tilt: -52, swirl:  0.38 },
    { at: 910, dur: 620, zeta: 0.46, omega: 16.2, tilt:  46, swirl: -0.34 },
    { at: 1000, dur: 620, zeta: 0.52, omega: 17.6, tilt: -38, swirl:  0.30 }
];

function burstOf(slot) {
    return BURST[slot] !== undefined ? BURST[slot] : BURST[0];
}

// Local progress (0..1) of slot `i` when the logo's run is at `reveal`.
function letterProgress(reveal, i) {
    var b = burstOf(i);
    return seg(reveal, b.at, b.dur);
}

// The slot's own spring of that progress: 0 -> hop past 1 -> 1.
function burstSpring(p, i) {
    var b = burstOf(i);
    return springEx(p, b.zeta, b.omega, b.dur / 1000);
}

// Where each letter ends up: [tilt in degrees, drop in letter-heights]. Fixed
// numbers, so the logo is crooked the same way on every start. Slots 0..4 are
// "Sekai", 5..7 "Pop", 8..10 the three kana.
var LETTER_REST = [
    [-5.5,  0.005], [4.0, -0.030], [-3.0, 0.020], [6.0, -0.025], [-4.5, 0.015],
    [ 3.5,  0.000], [-5.0, 0.030], [5.0, -0.020],
    [-7.0,  0.000], [-2.0, -0.060], [-6.0, 0.030]
];

function letterRest(i) {
    return LETTER_REST[i] !== undefined ? LETTER_REST[i] : [0, 0];
}

// 0 at both ends of a pop, 1 in the middle: how much a letter is squashed and
// stretched on its way (taller and thinner while it flies, so it pops).
function squash(p) {
    return Math.sin(Math.PI * clamp01(p));
}

// ---- the combined pass (everything the word has as one piece) ----
var STROKE_AT = 700, STROKE_MS = 1100;       // the light outer stroke grows
var HALFTONE_AT = 950, HALFTONE_MS = 900;    // its halftone comes up
var DECOR_AT = 1250, DECOR_GAP = 110, DECOR_MS = 560;   // sparkles
var SQUIGGLE_AT = 1350, SQUIGGLE_MS = 620;
var WARP_AT = 2000, WARP_MS = 1000;          // the wave travels through the word
var SWEEP_AT = 2150, SWEEP_MS = 800;         // and a light sweep crosses it
// the word's own textures (one set over all the letters, WelcomeLogo.qml)
var FX_WAVE_AT = 1000, FX_WAVE_MS = 700;     // the wave texture rises
var FX_DOTS_AT = 1100, FX_DOTS_MS = 700;     // the halftone's shading comes up
var FX_MATTE_AT = 1250, FX_MATTE_MS = 750;   // one matte band crosses the word
var FX_SHINE_AT = 1500, FX_SHINE_MS = 550;   // one hard shine crosses it
var IGNITION_MS = 700;

function strokeRun(reveal)   { return easeOutCubic(seg(reveal, STROKE_AT, STROKE_MS)); }
function halftoneRun(reveal) { return easeOutCubic(seg(reveal, HALFTONE_AT, HALFTONE_MS)); }
function decorRun(reveal, i) { return seg(reveal, DECOR_AT + i * DECOR_GAP, DECOR_MS); }
function squiggleRun(reveal) { return easeOutCubic(seg(reveal, SQUIGGLE_AT, SQUIGGLE_MS)); }
function ignitionRun(reveal) { return seg(reveal, 0, IGNITION_MS); }
function fxWaveRun(reveal)   { return easeOutCubic(seg(reveal, FX_WAVE_AT, FX_WAVE_MS)); }
function fxDotsRun(reveal)   { return easeOutCubic(seg(reveal, FX_DOTS_AT, FX_DOTS_MS)); }
function fxMatteRun(reveal)  { return seg(reveal, FX_MATTE_AT, FX_MATTE_MS); }
function fxShineRun(reveal)  { return seg(reveal, FX_SHINE_AT, FX_SHINE_MS); }

// The wave pass: `u` runs 0 -> 1 over the pass; the wave's strength is a bell
// (nothing at either end, so the word is undistorted before and after), and its
// phase carries the ripple from left to right.
function warpRun(reveal)  { return seg(reveal, WARP_AT, WARP_MS); }
function warpAmount(u) {
    if (u <= 0 || u >= 1)
        return 0;
    var s = Math.sin(Math.PI * u);
    return s * s;
}
function warpPhase(u)     { return clamp01(u) * 2 * Math.PI * 1.6; }
// The sweep: where the band's centre is, across the word (-0.3 .. 1.3, so it
// starts and ends outside the word), and 0 whenever it is not on the word.
function sweepRun(reveal) { return seg(reveal, SWEEP_AT, SWEEP_MS); }
function sweepPos(u)      { var t = clamp01(u); return -0.3 + 1.6 * (0.6 * t + 0.4 * easeOutCubic(t)); }

// ---- the exit: everything collapses into the middle ----
//
// `leave` runs 0 -> 1 over LOGO_LEAVE_MS. The kana and sparkles go first, then
// the letters, outermost last-in first-out (the reverse of how they came), each
// one drawing a short breath outward before it is pulled into the middle.
function leaveStart(slot) {
    if (slot >= 8)
        return (slot - 8) * 30;
    return (520 - burstOf(slot).at) * 0.3;
}
var LEAVE_LETTER_MS = 330;
var LEAVE_KANA_MS = 260;

function leaveProgress(leave, slot) {
    if (leave <= 0)
        return 0;
    if (leave >= 1)
        return 1;
    var dur = slot >= 8 ? LEAVE_KANA_MS : LEAVE_LETTER_MS;
    return clamp01((leave * LOGO_LEAVE_MS - leaveStart(slot)) / dur);
}

// 0 -> 1 with a small step backwards first (easeInBack): the breath before the
// pull. It is slightly negative at the start and exactly 1 at the end.
function easeInBack(t, overshoot) {
    var c1 = (overshoot === undefined) ? 1.7 : overshoot;
    var c3 = c1 + 1;
    var x = clamp01(t);
    return c3 * x * x * x - c1 * x * x;
}

function collapse(l) {
    return easeInBack(l, 1.5);
}

// the sparkles and the stroke leave on their own timing
function leaveDecor(leave) {
    if (leave <= 0)
        return 0;
    if (leave >= 1)
        return 1;
    return clamp01((leave * LOGO_LEAVE_MS) / 240);
}

function leaveStroke(leave) {
    if (leave <= 0)
        return 0;
    if (leave >= 1)
        return 1;
    return clamp01((leave * LOGO_LEAVE_MS - 140) / 380);
}

// the small flash where everything meets, at the very end
function leaveFlash(leave) {
    if (leave <= 0 || leave >= 1)
        return 0;
    var u = clamp01((leave * LOGO_LEAVE_MS - 400) / 160);
    return Math.sin(Math.PI * u);
}
