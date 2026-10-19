// Rules of the slide, one by one. Run: node chart_unit.js
const fs = require('fs'), assert = require('assert')
const src = fs.readFileSync(__dirname + '/../../modules/sekai/visualizer/ChartMath.js', 'utf8').replace('.pragma library', '')
const M = {}
new Function('M', src + ';M.create=create;M.stepLive=stepLive;')(M)
const DT = 1 / 60
const lanes = new Array(12).fill(0.3)

// tone(on) -> list of {t, kind:'start'|'end'|'flick'} while feeding tone windows
function run(toneAt, seconds, extraEvents) {
    const s = M.create()
    const log = []
    let on = false
    for (let i = 0; i < seconds * 60; i++) {
        const t = i * DT
        const v = toneAt(t) ? [0.5, 0.95] : null
        const out = M.stepLive(s, DT, lanes, { o: 0, e: (extraEvents && extraEvents(t)) || [], v }, true, 1)
        for (const h of out.heads) log.push({ t, kind: 'head' })
        for (const n of out.notes) if (n.type === 1 && n.width === 1.6) log.push({ t, kind: 'flick' })
        if (out.ribbon && out.ribbon.on !== on) { on = out.ribbon.on; log.push({ t, kind: on ? 'on' : 'off' }) }
    }
    return log
}
const kinds = l => l.map(x => x.kind).join(',')

// 1. a blip shorter than the hold time makes no slide
let l = run(t => t > 1 && t < 1.15, 3)
assert.strictEqual(kinds(l), '', 'a 150 ms blip must not start a slide'); console.log('ok  blip makes no slide')

// 2. a held tone: starts after the hold, has a head, ends with a flick
l = run(t => t > 1 && t < 2.5, 4)
assert.strictEqual(kinds(l), 'head,on,flick,off', kinds(l))
const st = l.find(x => x.kind === 'on').t, en = l.find(x => x.kind === 'flick').t
assert(st - 1 >= 0.2 && st - 1 < 0.45, 'start delay ' + (st - 1))
assert(en - 2.5 >= 0.1 && en - 2.5 < 0.4, 'end delay ' + (en - 2.5))
console.log('ok  held tone: slide at +' + (st - 1).toFixed(2) + ' s, flick ' + (en - 2.5).toFixed(2) + ' s after the tone stopped')

// 3. a short gap inside a tone (a consonant) does not end it
l = run(t => (t > 1 && t < 2) || (t > 2.08 && t < 3), 4)
assert.strictEqual(kinds(l), 'head,on,flick,off'); console.log('ok  an 80 ms dropout does not split the slide')

// 4. two tones 0.2 s apart: the second one waits for the rest
l = run(t => (t > 1 && t < 2) || (t > 2.2 && t < 3.5), 5)
const ons = l.filter(x => x.kind === 'on').map(x => x.t)
assert.strictEqual(ons.length, 2); assert(ons[1] - l.find(x => x.kind === 'off').t >= 0.3, 'rest')
console.log('ok  rest between slides: second starts ' + (ons[1] - l.find(x => x.kind === 'off').t).toFixed(2) + ' s after the first ended')

// 5. a drone is cut, then rests longer
l = run(t => t > 0.5, 10)
const on1 = l.filter(x => x.kind === 'on').map(x => x.t), off1 = l.filter(x => x.kind === 'off').map(x => x.t)
assert(off1[0] - on1[0] <= 3.8 && off1[0] - on1[0] >= 3.4, 'cut at ' + (off1[0] - on1[0]))
assert(on1[1] - off1[0] >= 0.85, 'long rest ' + (on1[1] - off1[0]))
console.log('ok  a drone is cut at ' + (off1[0] - on1[0]).toFixed(1) + ' s and rests ' + (on1[1] - off1[0]).toFixed(1) + ' s')

// 6. a tone that jumps around (chatter) does not start a slide
l = run(t => t > 1 && t < 3, 4)   // control
assert(l.length > 0)
{
    const s = M.create(); let started = false
    for (let i = 0; i < 240; i++) {
        const t = i * DT
        const v = t > 1 ? [(Math.floor(t * 12) % 2) ? 0.15 : 0.85, 0.9] : null
        const out = M.stepLive(s, DT, lanes, { o: 0, e: [], v }, true, 1)
        if (out.heads.length) started = true
    }
    assert(!started, 'jumping pitch should not make a slide'); console.log('ok  a tone jumping between two registers makes no slide')
}

// 7. hits by role: lanes, types, budgets
{
    const s = M.create(); const seen = []
    const evAt = t => (Math.abs(t % 0.5) < DT / 2 ? [['k', 0.8], ['h', 0.5]] : []).concat(Math.abs((t + 0.5) % 1) < DT / 2 ? [['s', 0.7]] : [])
    for (let i = 0; i < 60 * 8; i++) {
        const t = i * DT
        const out = M.stepLive(s, DT, lanes, { o: 1, e: evAt(t), v: null }, true, 1)
        for (const n of out.notes) seen.push(n)
    }
    const low = seen.filter(n => n.lane < 3), mid = seen.filter(n => n.lane > 4.5 && n.lane < 7.5), hi = seen.filter(n => n.lane > 9)
    assert(low.length >= 10 && mid.length >= 3 && hi.length >= 4, `${low.length} ${mid.length} ${hi.length}`)
    assert(hi.every(n => n.type === 1) && mid.every(n => n.type === 0))
    const crit = low.filter(n => n.type === 2).length
    assert(crit >= 1 && crit < low.length / 2, 'gold kicks are accents: ' + crit + ' of ' + low.length)
    console.log(`ok  roles: ${low.length} kick (${crit} gold), ${mid.length} snare, ${hi.length} hat flicks`)
}
console.log('all passed')
