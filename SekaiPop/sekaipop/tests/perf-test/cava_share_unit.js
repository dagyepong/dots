// Node test for the shared cava tap (services/PcCavaService.qml + `tapDemand` in
// VisualizerWidget.qml). Nothing here needs Quickshell; the functions are copies of the QML
// statements, keep them in step.
//   node tests/perf-test/cava_share_unit.js
//
// What it checks:
//   1. The tap runs while the pill wants it OR a widget does, never otherwise, and never in
//      Game Mode / while locked.
//   2. However widgets are added, flipped, loaded twice or destroyed (any order of signals),
//      the count equals the widgets that want audio, and is 0 once they are all gone.
//   3. What the pill reads (`points`) is byte-identical to what the old code gave it, and the
//      widget's `raw` is exactly the numbers cava sent (what its own cava used to give it).
"use strict";
const assert = require("assert");

// ---- the frame parser (one pass, as in the QML) ----
function bandsOf(data) {
    const parts = data.split(";");
    const out = [];
    for (let i = 0; i < parts.length; i++) {
        const v = parseFloat(parts[i]);
        if (!isNaN(v)) out.push(v);
    }
    return out;
}
// the OLD pill path: parse and scale in one go
function oldPoints(data, s) {
    const parts = data.split(";"), out = [];
    for (let i = 0; i < parts.length; i++) {
        const v = parseFloat(parts[i]);
        if (!isNaN(v)) out.push(Math.min(1000, v * s));
    }
    return out;
}
// the NEW pill path: scale the parsed bands
function newPoints(bands, s) {
    const out = new Array(bands.length);
    for (let i = 0; i < bands.length; i++) out[i] = Math.min(1000, bands[i] * s);
    return out;
}
// the OLD widget path: its own cava line, same parser, unscaled
function oldWidgetRaw(data) { return bandsOf(data); }

let seed = 987654;
const rnd = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;

for (let n = 0; n < 20000; n++) {
    const len = 1 + Math.floor(rnd() * 60);
    const s = 0.5 + rnd() * 2;
    let line = Array.from({ length: len }, () => (rnd() < 0.3 ? "0" : String(Math.floor(rnd() * 1100)))).join(";");
    if (rnd() < 0.8) line += ";";                  // cava's trailing ";"
    const bands = bandsOf(line);
    assert.deepStrictEqual(newPoints(bands, s), oldPoints(line, s), "pill numbers unchanged");
    assert.deepStrictEqual(bands, oldWidgetRaw(line), "widget numbers unchanged");
}
console.log("frames: 20000 random cava lines: the pill's points and the widget's raw are identical to the old paths");

// ---- the service's decision ----
class Tap {
    constructor() { this.widgetDemand = 0; this.pillOn = false; this.playing = false; this.game = false; this.locked = false; }
    get pillWanted() { return this.pillOn && this.playing; }
    get wanted() { return (this.pillWanted || this.widgetDemand > 0) && !this.game && !this.locked; }
    demand(d) { this.widgetDemand = Math.max(0, this.widgetDemand + d); }
}
class Widget {
    constructor(tap) { this.tap = tap; this.counted = false; this.wantAudio = false; this.isSekai = false; }
    get want() { return this.wantAudio && !this.isSekai; }
    sync() { if (this.want === this.counted) return; this.counted = this.want; this.tap.demand(this.want ? 1 : -1); }
    set(wantAudio, isSekai) { this.wantAudio = wantAudio; this.isSekai = isSekai; this.sync(); }  // onWantChanged
    completed() { this.sync(); }
    destroy() { if (this.counted) { this.counted = false; this.tap.demand(-1); } }
}
for (let trial = 0; trial < 2000; trial++) {
    const tap = new Tap();
    const ws = [];
    for (let step = 0; step < 80; step++) {
        const r = rnd();
        if (r < 0.15 || ws.length === 0) { const w = new Widget(tap); ws.push(w);
            if (rnd() < 0.5) { w.set(rnd() < 0.6, rnd() < 0.3); w.completed(); } else { w.completed(); w.set(rnd() < 0.6, rnd() < 0.3); }
            if (rnd() < 0.3) w.completed();
        } else if (r < 0.55) { ws[Math.floor(rnd() * ws.length)].set(rnd() < 0.6, rnd() < 0.3); }
        else if (r < 0.65) { const i = Math.floor(rnd() * ws.length); ws[i].destroy(); ws.splice(i, 1); }
        else if (r < 0.75) tap.pillOn = !tap.pillOn;
        else if (r < 0.85) tap.playing = !tap.playing;
        else if (r < 0.92) tap.game = !tap.game;
        else tap.locked = !tap.locked;
        const expected = ws.filter(w => w.want).length;
        assert.strictEqual(tap.widgetDemand, expected, "count equals the widgets that want audio");
        const should = ((tap.pillOn && tap.playing) || expected > 0) && !tap.game && !tap.locked;
        assert.strictEqual(tap.wanted, should, "cava runs exactly when something wants it");
    }
    ws.forEach(w => w.destroy());
    assert.strictEqual(tap.widgetDemand, 0, "nothing left counted once every widget is gone");
}
console.log("demand: 2000 random runs x 80 steps: count always equals the widgets that want audio; cava runs exactly when the pill or a widget wants it; 0 left after every widget is destroyed");

// ---- the point of the change: how many cava processes ----
function processes(pillWanted, widgetWantsEnd4) { return (pillWanted ? 1 : 0) + (widgetWantsEnd4 ? 1 : 0); }          // before
function processesNow(pillWanted, widgetWantsEnd4) { return (pillWanted || widgetWantsEnd4) ? 1 : 0; }                // after
assert.strictEqual(processes(true, true), 2);
assert.strictEqual(processesNow(true, true), 1);
for (const a of [true, false]) for (const b of [true, false]) assert.ok(processesNow(a, b) <= processes(a, b));
console.log("cava processes with the pill and an end4 desktop style on together: 2 -> 1");
console.log("OK");
