// Feeds the analyzer's output for the made-up song through ChartMath.stepLive
// (as VisualizerEngine.qml does) and prints what the chart would show.
//   node chart_test.js frames.jsonl
const fs = require('fs')
const src = fs.readFileSync(__dirname + '/../../modules/sekai/visualizer/ChartMath.js', 'utf8').replace('.pragma library', '')
const M = {}
new Function('M', src + ';M.create=create;M.stepLive=stepLive;')(M)
const frames = fs.readFileSync(process.argv[2], 'utf8').trim().split('\n').map(JSON.parse)
const HOP = 735 / 44100
const s = M.create()
const notes = { 0: [], 1: [], 2: [], 3: [] }
const kinds = []
const slides = []
let on = false, start = 0
let t = 0
for (const f of frames) {
    t += HOP
    const lanes = new Array(12).fill(0)
    for (let i = 0; i < 12; i++) lanes[i] = (f.b[2 * i] + f.b[2 * i + 1]) / 2000
    const out = M.stepLive(s, HOP, lanes, { o: f.o, e: f.e, v: f.v || null, t: f.t || null }, true, 1)
    for (const n of out.notes) kinds.push({ t, lane: n.lane, type: n.type })
    if (out.ribbon) {
        if (out.ribbon.on && !on) { on = true; start = t }
        if (!out.ribbon.on && on) { on = false; slides.push([start, t]) }
    }
}
if (on) slides.push([start, t])
const per = {}
for (const n of kinds) {
    const k = n.lane < 3.5 && n.lane > 1.0 ? 'low' : n.lane > 9.5 ? 'high' : n.lane > 4 && n.lane < 8 ? 'mid' : 'other'
    per[k + '/type' + n.type] = (per[k + '/type' + n.type] || 0) + 1
}
console.log('notes by lane group / type:', JSON.stringify(per))
console.log('notes in total:', kinds.length, 'in', t.toFixed(1), 's (' + (kinds.length / t).toFixed(1) + '/s)')
console.log('slides:', slides.map(([a, b]) => a.toFixed(1) + '-' + b.toFixed(1)).join('  '))
console.log('beat period:', s.period.toFixed(3), 's (true 0.500), conf', s.conf.toFixed(2))
