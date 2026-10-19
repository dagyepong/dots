// Node test for the two logic changes of the "idle work" pass (nothing here needs Quickshell):
//   1. PcCavaService: a cava frame equal to the last one is not assigned again.
//   2. StatusIconsService / Bar.qml (`statusDemand`): each bar adds itself to a count while its
//      status pill is on; the poll runs while the count is above 0. The per-bar `counted` flag
//      makes the add / remove idempotent in any order of signals.
// The functions below are copies of the QML bodies (same statements); keep them in step.
//   node tests/perf-test/demand_unit.js
"use strict";
const assert = require("assert");

// ---------- 1. cava frames ----------
function parseFrame(data, s) {
    const parts = data.split(";");
    const out = [];
    for (let i = 0; i < parts.length; i++) {
        const v = parseFloat(parts[i]);
        if (!isNaN(v)) out.push(Math.min(1000, v * s));
    }
    return out;
}
function sameAsLast(last, out) {
    let same = last.length === out.length;
    for (let i = 0; same && i < out.length; i++) {
        if (last[i] !== out[i]) same = false;
    }
    return same;
}
// What a consumer sees after the stream, with and without the dedup: the sequence of DISTINCT
// states must be identical; only the number of assignments (= repaints) differs.
function run(frames, dedup) {
    let points = [], assigned = 0;
    const seen = [];
    for (const f of frames) {
        const out = parseFrame(f, 1.3);
        if (!dedup || !sameAsLast(points, out)) { points = out; assigned++; }
        seen.push(JSON.stringify(points));
    }
    return { assigned, seen };
}
let seed = 12345;
const rnd = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
const frames = [];
for (let i = 0; i < 20000; i++) {
    const r = rnd();
    if (r < 0.6) frames.push(Array(50).fill("0").join(";") + ";");           // silence
    else if (r < 0.7 && frames.length) frames.push(frames[frames.length - 1]); // repeat of the last
    else frames.push(Array.from({ length: 50 }, () => Math.floor(rnd() * 1100)).join(";") + ";");
}
const a = run(frames, false), b = run(frames, true);
assert.deepStrictEqual(b.seen, a.seen, "what a reader sees must be identical");
assert.ok(b.assigned < a.assigned, "fewer assignments");
console.log(`cava: ${a.assigned} assignments -> ${b.assigned} (${(100 * (1 - b.assigned / a.assigned)).toFixed(1)}% fewer), reader view identical over ${frames.length} frames`);
assert.strictEqual(sameAsLast([], []), true);
assert.strictEqual(sameAsLast([], [0]), false);
assert.strictEqual(sameAsLast([0, 1], [0, 1.0000001]), false);

// ---------- 2. status-poll demand ----------
class Service { constructor() { this.watchers = 0; } get wanted() { return this.watchers > 0; }
    watch(d) { this.watchers = Math.max(0, this.watchers + d); } }
class Bar {
    constructor(svc) { this.svc = svc; this.counted = false; this.want = false; this.alive = true; }
    sync() { if (this.want === this.counted) return; this.counted = this.want; this.svc.watch(this.want ? 1 : -1); }
    setWant(v) { this.want = v; this.sync(); }        // onWantChanged
    completed() { this.sync(); }                      // Component.onCompleted
    destroy() { if (this.counted) { this.counted = false; this.svc.watch(-1); } this.alive = false; }
}
for (let trial = 0; trial < 2000; trial++) {
    const svc = new Service();
    const bars = [];
    for (let step = 0; step < 60; step++) {
        const r = rnd();
        if (r < 0.2 || bars.length === 0) { const b = new Bar(svc); bars.push(b);
            if (rnd() < 0.5) { b.setWant(rnd() < 0.7); b.completed(); } else { b.completed(); b.setWant(rnd() < 0.7); } // either order
            if (rnd() < 0.3) b.completed(); // a repeated call is harmless
        } else if (r < 0.65) { bars[Math.floor(rnd() * bars.length)].setWant(rnd() < 0.5); }
        else if (r < 0.8) { const i = Math.floor(rnd() * bars.length); bars[i].destroy(); bars.splice(i, 1); }
        const expected = bars.filter(b => b.want).length;
        assert.strictEqual(svc.watchers, expected, "count equals the bars whose pill is on");
        assert.strictEqual(svc.wanted, expected > 0);
    }
    bars.forEach(b => b.destroy());
    assert.strictEqual(svc.watchers, 0, "nothing left counted once every bar is gone");
    assert.strictEqual(svc.wanted, false);
}
console.log("status demand: 2000 random runs x 60 steps: count always equals the bars with the pill on; 0 after every bar is destroyed");
console.log("OK");
