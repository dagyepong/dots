// node tests/media-test/media_unit.js   (run from the sekaipop folder)
// The maths behind the media card's scrubber and player tabs (MediaMath.js).
const fs = require("fs")
const locate = require("../lib/locate.js")
const src = fs.readFileSync(locate("modules/sekai/mediaControls/MediaMath.js"), "utf8").replace(".pragma library", "")
const M = new Function(src + "; return { wave, barLit, ratioAt, prevPlayer, nextPlayer, current, fmt, left, ratio, bannerWord, fullCombo }")()

let fails = 0
const eq = (a, b, m) => { const x = JSON.stringify(a), y = JSON.stringify(b); if (x !== y) { fails++; console.log("FAIL " + m + "\n   got  " + x + "\n   want " + y) } }
const ok = (c, m) => { if (!c) { fails++; console.log("FAIL " + m) } }

// wave: n bars, 0.2..1, the tallest reaches the top, same song = same bars
for (const seed of ["a", "Song|Artist", "日本語|歌手", "x".repeat(300)]) {
    for (const n of [1, 2, 36, 80]) {
        const w = M.wave(seed, n)
        eq(w.length, n, "wave length " + n)
        ok(w.every(v => v >= 0.2 && v <= 1), "wave in range for " + seed.slice(0, 8))
        if (n > 1) ok(Math.max(...w) > 0.999, "tallest bar reaches 1")
    }
    eq(M.wave(seed, 36), M.wave(seed, 36), "wave repeatable")
}
ok(JSON.stringify(M.wave("one|x", 36)) !== JSON.stringify(M.wave("two|x", 36)), "another song, other bars")
eq(M.wave("", 5), [0.3, 0.3, 0.3, 0.3, 0.3], "nothing playing = flat low line")
eq(M.wave(null, 3), [0.3, 0.3, 0.3], "null seed = flat")
eq(M.wave("a", 0).length, 1, "n of 0 still gives a bar")

// barLit / ratioAt
eq([0, 1, 2, 3].map(i => M.barLit(i, 4, 0.5)), [true, true, false, false], "bars lit up to the middle")
eq(M.barLit(0, 0, 1), false, "no bars, nothing lit")
eq(M.ratioAt(50, 0, 100), 0.5, "ratioAt middle"); eq(M.ratioAt(-5, 0, 100), 0, "clamped low"); eq(M.ratioAt(500, 0, 100), 1, "clamped high")
eq(M.ratioAt(5, 0, 0), 0, "no width")

// players: prev / next wrap round
const ps = ["a", "b", "c"]
eq(M.prevPlayer(ps, "a"), "c", "prev wraps"); eq(M.prevPlayer(ps, "c"), "b", "prev"); eq(M.nextPlayer(ps, "c"), "a", "next wraps")
eq(M.prevPlayer([], "a"), null, "prev of none"); eq(M.prevPlayer(ps, "zzz"), "c", "unknown player goes to the last")
eq(M.current(ps, "b"), "b", "picked kept"); eq(M.current(ps, "gone"), "a", "a vanished pick falls back to the first")

// the stamp
eq(M.bannerWord(true, true), "NOW PLAYING", "playing"); eq(M.bannerWord(false, true), "PAUSED", "paused"); eq(M.bannerWord(false, false), "STANDBY", "nothing")
ok(M.fullCombo(0.97) && !M.fullCombo(0.96), "full combo from 97%")
eq(M.fmt(65), "1:05", "fmt"); eq(M.left(65, 200), "-2:15", "time left")

if (fails) { console.log(fails + " failed"); process.exit(1) }
console.log("media_unit: all passed")
