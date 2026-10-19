// Unit test for modules/common/functions/LockCrop.js (the Calendar lockscreen's
// frame cropping). Pure maths, no QML. Run:  node tests/lock-calendar-test/crop_unit.js
const fs = require("fs");
const path = require("path");
const assert = require("assert");
const vm = require("vm");

// .pragma library files are plain JS; load it into a sandbox and read its functions.
const file = path.join(__dirname, "..", "..", "modules", "common", "functions", "LockCrop.js");
const sandbox = {};
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(file, "utf8").replace(/^\.pragma library/m, ""), sandbox);
const LC = sandbox;

function ppm(w, h, fn) {
    const px = [];
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) px.push(fn(x, y).join(" "));
    return "P3\n# made by the test\n" + w + " " + h + "\n255\n" + px.join("\n") + "\n";
}
// A dark picture with a bright disc at (cx, cy) in 0..1.
function disc(w, h, cx, cy, rad) {
    return LC.parsePpm(ppm(w, h, (x, y) => {
        const dx = x / w - cx, dy = (y / h - cy) * (h / w);
        return dx * dx + dy * dy < rad * rad ? [240, 60, 90] : [20 + x % 3, 24, 30];
    }));
}
const specs = LC.specsFor([2.74, 0.62, 1.8]);
const inside = win => win.x >= -1e-9 && win.y >= -1e-9 && win.x + win.w <= 1 + 1e-9 && win.y + win.h <= 1 + 1e-9;
const area = win => win.w * win.h;
function inter(a, b) {
    const ox = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x);
    const oy = Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y);
    return ox > 0 && oy > 0 ? ox * oy : 0;
}

// ---- parsePpm
assert.strictEqual(LC.parsePpm(""), null);
assert.strictEqual(LC.parsePpm("P6\n4 4\n255\n"), null, "binary PPM is not accepted");
assert.strictEqual(LC.parsePpm("P3\n4 4\n255\n1 2 3"), null, "too few numbers");
assert.strictEqual(LC.parsePpm("P3\n2 2\n255\n" + "0 ".repeat(12)), null, "too small");
assert.strictEqual(LC.parsePpm("P3\n9999 9999\n255\n0"), null, "too big");
{
    const img = LC.parsePpm("P3\n# c\n4 4 # c\n15\n" + "15 0 7 ".repeat(16));
    assert.ok(img && img.w === 4 && img.h === 4 && img.rgb.length === 48);
    assert.strictEqual(JSON.stringify(img.rgb.slice(0, 3)), "[255,0,119]", "scaled to 0..255 from maxval 15");
}

// ---- saliency: values stay in 0..1, the disc is the most interesting spot
{
    const img = disc(96, 54, 0.75, 0.30, 0.10);
    const g = LC.saliency(img);
    assert.strictEqual(g.sal.length, 96 * 54);
    assert.ok(g.sal.every(v => v >= 0 && v <= 1.0001), "saliency within 0..1");
    const at = (x, y) => g.sal[Math.round(y * 53) * 96 + Math.round(x * 95)];
    assert.ok(at(0.75, 0.30) > at(0.12, 0.85) + 0.2, "disc beats an empty corner");
}

// ---- plan: windows are valid, keep their frame's aspect, and follow the subject
for (const [cx, cy] of [[0.75, 0.30], [0.25, 0.70], [0.50, 0.50]]) {
    const img = disc(96, 54, cx, cy, 0.10);
    const wins = LC.plan(LC.saliency(img), specs);
    assert.strictEqual(wins.length, 3);
    wins.forEach((w, i) => {
        assert.ok(inside(w), "window " + i + " inside the picture: " + JSON.stringify(w));
        const aspect = (w.w * 96) / (w.h * 54);          // in cells (square), a 16:9 picture
        assert.ok(Math.abs(aspect - specs[i].aspect) / specs[i].aspect < 0.02, "window " + i + " keeps the frame's aspect (" + aspect.toFixed(3) + ")");
    });
    const first = wins[0];
    assert.ok(cx >= first.x && cx <= first.x + first.w && cy >= first.y && cy <= first.y + first.h,
        "the first frame shows the subject at " + cx + "," + cy);
    // The later frames do not just repeat the first.
    assert.ok(inter(wins[0], wins[1]) / area(wins[1]) < 0.85, "second frame is mostly a different part");
    assert.ok(inter(wins[0], wins[2]) / area(wins[2]) < 0.85, "third frame is mostly a different part");
}

// ---- plan: deterministic, and fine on a flat picture, a portrait one and a wide one
{
    const img = disc(96, 54, 0.4, 0.4, 0.12);
    assert.strictEqual(JSON.stringify(LC.plan(LC.saliency(img), specs)), JSON.stringify(LC.plan(LC.saliency(img), specs)), "same picture, same windows");
    const flat = LC.parsePpm(ppm(96, 54, () => [128, 128, 128]));
    const wf = LC.plan(LC.saliency(flat), specs);
    wf.forEach(w => assert.ok(inside(w) && w.w > 0 && w.h > 0));
    const portrait = LC.parsePpm(ppm(54, 96, (x, y) => [x * 4, y * 2, 90]));
    LC.plan(LC.saliency(portrait), specs).forEach(w => assert.ok(inside(w) && w.w > 0 && w.h > 0, "portrait"));
    const wide = LC.parsePpm(ppm(96, 40, (x, y) => [x * 2, 40, y * 5]));
    LC.plan(LC.saliency(wide), specs).forEach(w => assert.ok(inside(w) && w.w > 0 && w.h > 0, "ultrawide"));
}

// ---- fixedPlan: valid for any picture aspect, and nothing like NaN
for (const a of [0.5, 0.75, 1, 16 / 9, 21 / 9, 32 / 9, NaN, -3, 0]) {
    const wins = LC.fixedPlan(a, specs);
    assert.strictEqual(wins.length, 3);
    wins.forEach(w => assert.ok(inside(w) && isFinite(w.x + w.y + w.w + w.h) && w.w > 0 && w.h > 0, "fixed " + a + ": " + JSON.stringify(w)));
}
// More frames than fixed spots / scales still works.
assert.strictEqual(LC.fixedPlan(16 / 9, LC.specsFor([1, 1, 1, 1, 1])).length, 5);

// ---- place(): the window fills the frame, with no gap, for any aspect
for (const [iw, ih, fw, fh, win] of [
    [2880, 1620, 1300, 475, { x: 0.1, y: 0.2, w: 0.5, h: 0.2 }],
    [2880, 1620, 500, 805, { x: 0.6, y: 0.1, w: 0.2, h: 0.7 }],
    [1000, 1600, 525, 291, { x: 0.0, y: 0.0, w: 1.0, h: 0.3 }],
    [3200, 900, 525, 291, { x: 0.9, y: 0.8, w: 0.1, h: 0.2 }],
]) {
    const p = LC.place(win, iw, ih, fw, fh);
    assert.ok(p.width >= fw - 1e-6 && p.height >= fh - 1e-6, "picture covers the frame");
    assert.ok(p.x <= 1e-9 && p.y <= 1e-9 && p.x + p.width >= fw - 1e-6 && p.y + p.height >= fh - 1e-6, "no gap at any edge");
    assert.ok(Math.abs(p.width / p.height - iw / ih) < 1e-6, "the picture is not stretched");
}
{   // A window of exactly the frame's aspect is shown whole and in the right place.
    const win = { x: 0.25, y: 0.25, w: 0.5, h: 0.5 };
    const p = LC.place(win, 1600, 900, 800, 450);
    assert.ok(Math.abs(p.width - 1600) < 1e-6 && Math.abs(p.x + 400) < 1e-6 && Math.abs(p.y + 225) < 1e-6, JSON.stringify(p));
}

console.log("LockCrop: all checks passed");
