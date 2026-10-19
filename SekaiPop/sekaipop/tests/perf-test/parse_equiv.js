// Checks that the one-pass cava line parser (VisualizerWidget.parseBands and the loop in
// PcCavaService.qml) returns exactly what the old split / map / filter chain did.
// Run: node tests/perf-test/parse_equiv.js
function oldParse(d) { return d.split(";").map(v => parseFloat(v.trim())).filter(v => !isNaN(v)) }
function newParse(d) {
    const p = d.split(";"), o = []
    for (let i = 0; i < p.length; i++) { const v = parseFloat(p[i]); if (!isNaN(v)) o.push(v) }
    return o
}
function oldPoints(d, s) { return oldParse(d).map(v => Math.min(1000, v * s)) }
function newPoints(d, s) {
    const p = d.split(";"), o = []
    for (let i = 0; i < p.length; i++) { const v = parseFloat(p[i]); if (!isNaN(v)) o.push(Math.min(1000, v * s)) }
    return o
}
let bad = 0
const fixed = ["1;2;3;", "0;0;0;0;", "  12 ; 3.5;;x; 7 ;", "", "abc", ";;;", "1000;999.5;0;"]
for (const c of fixed)
    if (JSON.stringify(oldParse(c)) !== JSON.stringify(newParse(c))) { bad++; console.log("MISMATCH", JSON.stringify(c)) }
for (let i = 0; i < 20000; i++) {
    let s = ""
    const n = Math.floor(Math.random() * 60)
    for (let j = 0; j < n; j++)
        s += (Math.random() < .05 ? " " : "") + Math.floor(Math.random() * 1000) + (Math.random() < .1 ? ".5" : "") + ";"
    const k = 0.5 + Math.random() * 2
    if (JSON.stringify(oldParse(s)) !== JSON.stringify(newParse(s))
        || JSON.stringify(oldPoints(s, k)) !== JSON.stringify(newPoints(s, k))) { bad++; console.log("MISMATCH", s); break }
}
console.log(bad === 0 ? "ok: same output" : "FAILED")
process.exit(bad === 0 ? 0 : 1)
