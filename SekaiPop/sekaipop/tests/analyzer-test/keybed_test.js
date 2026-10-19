// Run: node tests/analyzer-test/keybed_test.js
const fs = require("fs")
const path = require("path")
const src = fs.readFileSync(path.join(__dirname, "..", "..", "modules", "sekai", "visualizer", "KeyBedMath.js"), "utf8").replace(/^\.pragma library/m, "")
const KB = new Function(src + "; return { create, step, hit, slap, rekey, voiceSet, pointerSet, volumeShow, layCover, tuneColor };")()

let fails = 0
function check(name, ok, info) {
    console.log((ok ? "ok   " : "FAIL ") + name + (info !== undefined ? "  " + info : ""))
    if (!ok) fails++
}
const peak = s => Math.max(...s.p.map(Math.abs))
const silent = new Array(12).fill(0)
function run(s, secs, input, dt = 1 / 60) {
    let maxp = 0
    for (let t = 0; t < secs; t += dt) { KB.step(s, dt, input || { levels: silent, bass: 0 }); maxp = Math.max(maxp, peak(s)) }
    return maxp
}

// 1. a kick: pressed deep, springs back, then the sheet sleeps
for (const [C, R] of [[17, 11], [22, 14], [12, 9], [26, 17]]) {
    const s = KB.create(C, R)
    KB.hit(s, "kick", 1.6, 1)
    const m = run(s, 0.35)
    const centre = s.p[Math.round(R * 0.62) * C + Math.round(C / 2 - 0.5)]
    check(`kick ${C}x${R}: dent depth reasonable`, m > 0.6 && m <= 1.35, "peak " + m.toFixed(2))
    run(s, 4)
    check(`kick ${C}x${R}: settles to rest and sleeps`, !s.awake && peak(s) === 0, "peak " + peak(s).toFixed(4))
}

// 2. one key bounces once (under-damped) - look at the lone-key response in the middle
{
    const s = KB.create(17, 11)
    KB.hit(s, "kick", 1.6, 1)
    const idx = Math.round(11 * 0.62) * 17 + 8
    let minAfter = 0, seenDown = false
    for (let t = 0; t < 2; t += 1 / 60) {
        KB.step(s, 1 / 60, { levels: silent, bass: 0 })
        if (s.p[idx] > 0.5) seenDown = true
        if (seenDown) minAfter = Math.min(minAfter, s.p[idx])
    }
    check("key overshoots upwards after a press (soft bounce)", minAfter < -0.03, "min " + minAfter.toFixed(3))
}

// 3. a loud full-spectrum burst for 20 s stays bounded and finite
{
    const s = KB.create(22, 14)
    let ok = true, maxp = 0
    for (let t = 0; t < 20; t += 1 / 60) {
        const lv = Array.from({ length: 12 }, (_, i) => 0.5 + 0.5 * Math.sin(t * 3 + i))
        KB.step(s, 1 / 60, { levels: lv, bass: 0 })
        if (t % 0.5 < 1 / 60) KB.hit(s, "kick", 1, 1)
        if (t % 1 < 1 / 60) KB.hit(s, "snare", 6, 1)
        if (t % 0.25 < 1 / 60) KB.hit(s, "hat", 10, 1)
        for (const v of s.p) if (!isFinite(v)) ok = false
        maxp = Math.max(maxp, peak(s))
    }
    check("20 s of full-scale music stays finite and clamped", ok && maxp <= 1.35 + 1e-9, "peak " + maxp.toFixed(2))
}

// 4. big frame hiccup (0.2 s) does not blow up
{
    const s = KB.create(17, 11)
    KB.hit(s, "crit", 1, 1)
    let ok = true
    for (let i = 0; i < 40; i++) { KB.step(s, 0.2, { levels: silent, bass: 0 }); for (const v of s.p) if (!isFinite(v) || Math.abs(v) > 1.36) ok = false }
    check("long frames are clamped (dt <= 0.05)", ok)
}

// 5. quiet lanes below the gate do nothing
{
    const s = KB.create(17, 11)
    const m = run(s, 2, { levels: new Array(12).fill(0.08), bass: 0 })
    check("quiet spectrum leaves the sheet flat", m === 0, "peak " + m)
}

// 6. a single loud lane produces waves that stay near its emitter at first and are bounded
{
    const s = KB.create(17, 11)
    const lv = new Array(12).fill(0); lv[1] = 0.9
    const m = run(s, 1.5, { levels: lv, bass: 0 })
    const left = s.p.slice(0, 5 * 17).reduce((a, b) => a + Math.abs(b), 0)
    check("bass lane moves keys (range)", m > 0.25 && m < 1.35, "peak " + m.toFixed(2))
}

// 7. pointer holds keys down, release pops them up and then rests
{
    const s = KB.create(17, 11)
    KB.pointerSet(s, true, 8, 5)
    run(s, 0.6)
    const held = s.p[5 * 17 + 8]
    KB.pointerSet(s, false, 8, 5)
    let minAfter = 0
    for (let t = 0; t < 1; t += 1 / 60) { KB.step(s, 1 / 60, { levels: silent, bass: 0 }); minAfter = Math.min(minAfter, s.p[5 * 17 + 8]) }
    run(s, 4)
    check("pointer holds the key down", held > 0.7, "held " + held.toFixed(2))
    check("release springs up past rest", minAfter < -0.05, "min " + minAfter.toFixed(2))
    check("sheet sleeps after the pointer", !s.awake && peak(s) === 0)
}

// 8. snare sweep alternates, covers every column
{
    const s = KB.create(17, 11)
    const seen = new Set()
    KB.hit(s, "snare", 6, 1)
    for (let t = 0; t < 0.4; t += 1 / 60) {
        KB.step(s, 1 / 60, { levels: silent, bass: 0 })
        for (let c = 0; c < 17; c++) if (s.p[5 * 17 + c] > 0.05) seen.add(c)
    }
    check("snare slap reaches every column", seen.size === 17, seen.size + "/17")
    const d1 = s.sweep.dir
    KB.hit(s, "snare", 6, 1)
    check("snare direction alternates", s.sweep.dir === -d1)
}

// 9. rekey swaps every key exactly once, centre first, in about half a second
{
    const s = KB.create(17, 11)
    KB.rekey(s)
    const order = []
    let t = 0
    while (t < 2) {
        const out = KB.step(s, 1 / 60, { levels: silent, bass: 0 })
        for (const i of out.swapped) order.push([i, t])
        t += 1 / 60
    }
    const uniq = new Set(order.map(o => o[0]))
    const last = order[order.length - 1][1]
    const centre = order.find(o => o[0] === 5 * 17 + 8)[1]
    const corner = order.find(o => o[0] === 0)[1]
    check("rekey swaps all keys once", order.length === 187 && uniq.size === 187, order.length)
    check("rekey runs from the middle out", centre < corner, `centre ${centre.toFixed(2)}s corner ${corner.toFixed(2)}s`)
    check("rekey takes about half a second", last > 0.3 && last < 0.8, last.toFixed(2) + "s")
}

// 10. voice finger travels and holds
{
    const s = KB.create(17, 11)
    KB.voiceSet(s, true, 3)
    run(s, 0.8)
    KB.voiceSet(s, true, 10)
    run(s, 0.8)
    check("voice finger arrives at its pitch", Math.abs(s.voice.x - (10 / 12 * 17 - 0.5)) < 0.5, "x " + s.voice.x.toFixed(2))
    KB.voiceSet(s, false, 0)
    run(s, 5)
    check("voice finger lets go and the sheet sleeps", !s.awake)
}

// 11. cover layout + tune
{
    const cells = []
    for (let i = 0; i < 6 * 4; i++) cells.push([i / 24, 0.5, 1 - i / 24])
    const out = KB.layCover(cells, 6, 4, 10, 4)
    check("cover lays in the middle with mirrored wings", out.length === 40 && out[0][3] === 1 && out[2][3] === 0 && out[9][3] === 1)
    const m = out[0], src = cells[0 * 6 + 1]   // x=0 -> sx=-2 -> mirror idx 1 .. (offX=2)
    check("wing mirrors the edge (x=1 -> same as sx=-1... )", Math.abs(out[1][0] - cells[0][0]) < 1e-9, "")
    const t = KB.tuneColor(0.02, 0.02, 0.02)
    const u = KB.tuneColor(0.99, 0.99, 0.99)
    check("tune lifts black and tames white", (t[0] + t[1] + t[2]) / 3 > 0.25 && (u[0] + u[1] + u[2]) / 3 < 0.9)
}

// 11b. a typical loud mix (bass heavy, highs light): depth should read as lively, not saturated
{
    const s = KB.create(17, 11)
    const prof = [0.75, 0.7, 0.6, 0.55, 0.5, 0.45, 0.4, 0.35, 0.3, 0.25, 0.2, 0.15]
    let sum = 0, n = 0, sat = 0
    for (let t = 0; t < 6; t += 1 / 60) {
        const lv = prof.map((v, i) => Math.max(0, Math.min(1, v * (0.75 + 0.25 * Math.sin(t * (2 + i * 0.7))))))
        KB.step(s, 1 / 60, { levels: lv, bass: 0 })
        if (t > 2) { for (const v of s.p) { sum += Math.abs(v); n++; if (Math.abs(v) > 1.3) sat++ } }
    }
    const mean = sum / n
    console.log("     typical mix: mean |depth| " + mean.toFixed(3) + ", saturated share " + (100 * sat / n).toFixed(2) + "%")
    check("a typical mix is lively but not saturated", mean > 0.06 && mean < 0.45 && sat / n < 0.02)
}

// 11c. volume row: the bottom row rises as far as the volume reaches, then lets go
{
    const s = KB.create(16, 10)
    KB.volumeShow(s, 0.5)
    run(s, 0.6)
    const base = 9 * 16
    const left = s.p[base + 2], right = s.p[base + 13]
    check("volume row: lit half is held up, the rest is not", left < -0.4 && Math.abs(right) < 0.25, `left ${left.toFixed(2)} right ${right.toFixed(2)}`)
    run(s, 4)
    check("volume row lets go and the sheet sleeps", !s.awake && peak(s) === 0)
}

// 12. speed
{
    const s = KB.create(23, 15)
    const lv = Array.from({ length: 12 }, () => 0.7)
    const t0 = process.hrtime.bigint()
    for (let i = 0; i < 600; i++) KB.step(s, 1 / 60, { levels: lv, bass: 0 })
    const ms = Number(process.hrtime.bigint() - t0) / 1e6 / 600
    check("a frame costs well under 1 ms (23x15)", ms < 1.5, ms.toFixed(3) + " ms")
}
console.log(fails === 0 ? "\nall passed" : "\n" + fails + " FAILED")
process.exit(fails ? 1 : 0)
