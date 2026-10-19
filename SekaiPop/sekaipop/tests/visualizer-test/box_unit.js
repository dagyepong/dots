// The small window's box (VisualizerWidget.qml: boxPad, boxX, boxY, boxW, boxH).
// Checks: the card at its biggest pop-in overshoot is inside the box (where the screen allows),
// the stage offset is a whole number of pixels, and the card lands on the same screen pixel
// as it does in a full-screen window.
const sizes = [[264, 236], [320, 276], [420, 350], [520, 430]];
const screens = [[1920, 1080], [2560, 1440], [1366, 768]];
const scales = [0.75, 1, 1.25, 1.5, 2];
const PEAK = 1.1208 * 1.035;          // OutBack overshoot 1.9, times the size bump
let n = 0, bad = 0;

function box(card, k, fullW, fullH) {
    const pad = Math.ceil((0.12 * Math.max(card.w, card.h) + 16) * k);
    const x = Math.max(0, Math.floor(card.x * k - pad));
    const y = Math.max(0, Math.floor(card.y * k - pad));
    const w = Math.max(1, Math.min(fullW, Math.ceil((card.x + card.w) * k + pad)) - x);
    const h = Math.max(1, Math.min(fullH, Math.ceil((card.y + card.h) * k + pad)) - y);
    return { x, y, w, h };
}

for (const [sw, sh] of screens) for (const k of scales) for (const [cw, ch] of sizes) {
    const roomW = sw / k, roomH = sh / k;
    if (roomW < cw || roomH < ch) continue;
    const xs = [0, 1, 17.5, (roomW - cw) / 2, roomW - cw - 3, roomW - cw];
    const ys = [0, 1, 33.25, (roomH - ch) / 2, roomH - ch - 3, roomH - ch];
    for (const cx of xs) for (const cy of ys) {
        n++;
        const b = box({ x: cx, y: cy, w: cw, h: ch }, k, sw, sh);
        // the card at peak scale, about its centre, in screen px, cut to the screen
        const mx = (cx + cw / 2) * k, my = (cy + ch / 2) * k;
        const l = Math.max(0, mx - cw * k * PEAK / 2), r = Math.min(sw, mx + cw * k * PEAK / 2);
        const t = Math.max(0, my - ch * k * PEAK / 2), btm = Math.min(sh, my + ch * k * PEAK / 2);
        const inside = l >= b.x - 1e-6 && r <= b.x + b.w + 1e-6 && t >= b.y - 1e-6 && btm <= b.y + b.h + 1e-6;
        const whole = Number.isInteger(b.x) && Number.isInteger(b.y) && Number.isInteger(b.w) && Number.isInteger(b.h);
        // position of the card inside the window, plus the window's own place, equals the full-screen position
        const same = Math.abs((cx * k - b.x) + b.x - cx * k) < 1e-9;
        const small = b.w * b.h <= sw * sh;   // never bigger than the screen it replaces
        if (!inside || !whole || !same || !small || b.x + b.w > sw || b.y + b.h > sh) {
            bad++;
            if (bad < 6) console.log("FAIL", JSON.stringify({ sw, sh, k, cw, ch, cx, cy, b, inside, whole, same, small }));
        }
    }
}
console.log(n + " cases, " + bad + " failures");
process.exit(bad ? 1 : 0);
