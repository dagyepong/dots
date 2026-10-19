.pragma library

// Pure helpers for WeatherPopup.qml — no QML, so they can be checked on their
// own. WeatherSource.qml (OpenMeteo.js) hands the popup finished strings ("18°C",
// "12 km/h NE", "72%"); these take the numbers back out for the little
// pictures (a water level, a wind arrow, a UV meter, the temperature curve).

// "18°C" -> { num: "18", unit: "°C" }; "-3°F" -> { num: "-3", unit: "°F" }.
function splitTemp(text) {
    var m = /^\s*(-?\d+(?:\.\d+)?)\s*(°\s*[CF])?/.exec(String(text || ""));
    if (!m)
        return { num: "--", unit: "" };
    return { num: m[1], unit: (m[2] || "").replace(/\s/g, "") };
}

// The first number in a string ("72%" -> 72, "12 km/h NE" -> 12), 0 if none.
function firstNumber(text) {
    var m = /-?\d+(?:\.\d+)?/.exec(String(text || ""));
    return m ? parseFloat(m[0]) : 0;
}

var POINTS = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
              "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];

// Degrees clockwise from "up" for an arrow showing where the wind is GOING
// (the weather service names the point it blows FROM, so it is turned half a circle).
// null when the text has no compass point.
function windArrow(text) {
    var m = /\b([NSEW]{1,3})\s*$/.exec(String(text || "").trim());
    if (!m)
        return null;
    var i = POINTS.indexOf(m[1]);
    if (i < 0)
        return null;
    return (i * 22.5 + 180) % 360;
}

// "9 km/h ENE" -> { speed: "9 km/h", dir: "ENE" }. No compass point -> dir "".
// The popup shows the speed big and the point as a small tag, so a long
// reading is never cut off with an ellipsis.
function windParts(text) {
    var s = String(text || "").trim();
    var m = /^(.*?)\s*\b([NSEW]{1,3})$/.exec(s);
    if (!m || POINTS.indexOf(m[2]) < 0 || m[1] === "")
        return { speed: s, dir: "" };
    return { speed: m[1], dir: m[2] };
}

// How many of the UV meter's five diamonds are lit (WHO bands).
function uvLit(uv) {
    var n = Math.round(Number(uv) || 0);
    if (n <= 0) return 0;
    if (n <= 2) return 1;
    if (n <= 5) return 2;
    if (n <= 7) return 3;
    if (n <= 10) return 4;
    return 5;
}

// The temperature "melody": one point per reading, evenly spread between
// `left` and `left + span`, the warmest at `top` and the coldest at `bottom`.
// temps: array of numbers. Returns [{ x, y }].
function curvePoints(temps, left, span, top, bottom) {
    var n = temps.length;
    if (n === 0)
        return [];
    var lo = Math.min.apply(null, temps);
    var hi = Math.max.apply(null, temps);
    var out = [];
    for (var i = 0; i < n; i++) {
        var x = n === 1 ? left + span / 2 : left + span * i / (n - 1);
        var y = hi === lo ? (top + bottom) / 2 : bottom - (temps[i] - lo) / (hi - lo) * (bottom - top);
        out.push({ x: x, y: y });
    }
    return out;
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
