.pragma library

// Pure helpers for BatteryPopup.qml — no QML, so they can be checked on their
// own (see the notes at the bottom of BatteryPopup.qml).

// "1h 42m" / "38m" (what BatterySource.timeRemaining says) -> minutes. 0 when
// there is nothing to read.
function parseMins(text) {
    var m = /^(?:(\d+)h\s*)?(\d+)m$/.exec(String(text || "").trim());
    if (!m)
        return 0;
    return parseInt(m[1] || "0", 10) * 60 + parseInt(m[2], 10);
}

// Minutes -> "1h 05m" / "38m".
function fmtMins(n) {
    n = Math.max(0, Math.round(n));
    var h = Math.floor(n / 60);
    var m = n % 60;
    if (h > 0)
        return h + "h " + (m < 10 ? "0" : "") + m + "m";
    return m + "m";
}

// When will the battery read `target` percent, at the pace it has now?
// `minutes` is what UPower says is left to empty (on battery) or to full
// (charging) from `pct`, so the pace is taken as constant: a straight line.
// Returns { kind, mins }:
//   "eta"    it gets there in `mins`
//   "past"   charging and already at or above that level
//   "above"  on battery, so it can only go down: needs a charger to get there
//   "none"   no pace to go on yet
function eta(pct, target, charging, minutes) {
    if (!(minutes > 0))
        return { kind: "none", mins: 0 };
    if (charging) {
        if (target <= pct)
            return { kind: "past", mins: 0 };
        if (pct >= 100)
            return { kind: "none", mins: 0 };
        return { kind: "eta", mins: minutes * (target - pct) / (100 - pct) };
    }
    if (target >= pct)
        return { kind: "above", mins: 0 };
    if (pct <= 0)
        return { kind: "none", mins: 0 };
    return { kind: "eta", mins: minutes * (pct - target) / pct };
}

// Which judgement the level earns, 0 (best) .. 5:
//   0 ALL PERFECT (full and plugged in)  1 PERFECT  2 GREAT  3 GOOD  4 BAD  5 MISS
function tier(pct, plugged) {
    if (pct >= 100 && plugged)
        return 0;
    if (pct >= 85)
        return 1;
    if (pct >= 60)
        return 2;
    if (pct >= 35)
        return 3;
    if (pct >= 20)
        return 4;
    return 5;
}

var WORDS = ["ALL PERFECT", "PERFECT", "GREAT", "GOOD", "BAD", "MISS"];

function word(t) {
    return WORDS[Math.max(0, Math.min(5, t))];
}

// How lit gauge segment `i` of `n` is for a charge of `pct`: 0 (dark) .. 1 (full).
function segmentFill(pct, i, n) {
    var level = Math.max(0, Math.min(100, pct)) / 100 * n;
    return Math.max(0, Math.min(1, level - i));
}

function clamp01(t) {
    return t < 0 ? 0 : (t > 1 ? 1 : t);
}

// The "out-back" easing curve (a little overshoot), t in 0..1.
function outBack(t, s) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    var c = (s === undefined ? 1.8 : s);
    var u = t - 1;
    return 1 + (c + 1) * u * u * u + c * u * u;
}

// The Material Symbols glyph for the level, the same pick BatteryIndicator.qml makes.
function glyph(pct, charging) {
    if (charging)
        return "battery_android_frame_bolt";
    if (pct >= 100)
        return "battery_android_frame_full";
    var bucket = Math.ceil(pct / (100 / 6));
    return "battery_android_frame_" + Math.max(1, Math.min(6, bucket));
}
