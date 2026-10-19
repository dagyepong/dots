// The Sekai Pad (the equalizer handheld) wears the shell theme: every colour in it comes
// from modules/common/PadPalette.qml, which works its colours out from ThemeService.palette
// (a unit's palette, Monochrome, the custom palette and the matugen wallpaper theme all come
// through there). Node cannot load QML, so this runs the palette's own expressions (read out
// of the .qml file, with a small stand-in for Qt.color / Qt.hsla) for every theme, and reads
// the equalizer's files for hard-coded colours and for a repaint after a theme change.
//
//   node tests/pad-theme-test/pad_palette_test.js
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const root = path.join(__dirname, "..", "..")
const palettePath = path.join(root, "modules", "common", "PadPalette.qml")
const eqDir = path.join(root, "modules", "sekai", "equalizer")
const src = fs.readFileSync(palettePath, "utf8")

// ---------- a stand-in for the bits of Qt the palette uses ----------
function clamp01(v) { return Math.max(0, Math.min(1, v)) }
function fromRgb(r, g, b, a) {
    // (floating point can leave -1e-17 where Qt gives 0)
    r = clamp01(r); g = clamp01(g); b = clamp01(b)
    const mx = Math.max(r, g, b), mn = Math.min(r, g, b)
    const l = (mx + mn) / 2
    let h = -1, s = 0
    const d = mx - mn
    if (d > 0) {
        s = d / (1 - Math.abs(2 * l - 1))
        if (mx === r) h = ((g - b) / d) % 6
        else if (mx === g) h = (b - r) / d + 2
        else h = (r - g) / d + 4
        h /= 6
        if (h < 0) h += 1
    }
    return { r, g, b, a: a === undefined ? 1 : a, hslHue: h, hslSaturation: clamp01(s), hslLightness: l }
}
const Qt = {
    color(v) {
        if (typeof v === "object") return v
        const n = parseInt(String(v).slice(1), 16)
        return fromRgb(((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255, 1)
    },
    rgba: (r, g, b, a) => fromRgb(r, g, b, a),
    hsla(h, s, l, a) {
        h = ((h % 1) + 1) % 1
        const c = (1 - Math.abs(2 * l - 1)) * s
        const x = c * (1 - Math.abs((h * 6) % 2 - 1))
        const m = l - c / 2
        let r = 0, g = 0, b = 0
        const k = Math.floor(h * 6)
        if (k === 0) { r = c; g = x } else if (k === 1) { r = x; g = c } else if (k === 2) { g = c; b = x }
        else if (k === 3) { g = x; b = c } else if (k === 4) { r = x; b = c } else { r = c; b = x }
        return fromRgb(r + m, g + m, b + m, a === undefined ? 1 : a)
    }
}

// Runs every `function` and `readonly property` line of PadPalette.qml, in file order.
function evaluate(palette) {
    const scope = {}
    scope.root = scope
    const ThemeService = { palette }
    const lines = src.split("\n")
    for (let li = 0; li < lines.length; li++) {
        let line = lines[li]
        // a function that spans several lines: up to the closing brace at its own indent
        const open = line.match(/^(\s*)function\s+(\w+)\(([^)]*)\)\s*\{\s*$/)
        if (open) {
            let body = ""
            while (li + 1 < lines.length && lines[li + 1] !== open[1] + "}") body += lines[++li] + "\n"
            li++
            scope[open[2]] = new Function("scope", "Qt", "with (scope) { return function (" + open[3] + ") {" + body + "} }")(scope, Qt)
            continue
        }
        let m = line.match(/^\s*function\s+(\w+)\(([^)]*)\)\s*\{(.*)\}\s*(?:\/\/.*)?$/)
        if (m) {
            scope[m[1]] = new Function("scope", "Qt", "with (scope) { return function (" + m[2] + ") {" + m[3] + "} }")(scope, Qt)
            continue
        }
        m = line.match(/^\s*readonly property (?:color|var|real|bool) (\w+): (.+?)\s*(?:\/\/.*)?$/)
        if (m) {
            scope[m[1]] = new Function("scope", "Qt", "ThemeService", "with (scope) { return (" + m[2] + ") }")(scope, Qt, ThemeService)
        }
    }
    return scope
}

const hex = c => "#" + [c.r, c.g, c.b].map(v => Math.round(v * 255).toString(16).padStart(2, "0")).join("")
const lin = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
const lum = c => 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
const contrast = (a, b) => (Math.max(lum(a), lum(b)) + 0.05) / (Math.min(lum(a), lum(b)) + 0.05)
const dist = (a, b) => Math.hypot(a.r - b.r, a.g - b.g, a.b - b.b) * 255

// ---------- the themes (ThemeService.qml's palettes; the matugen ones follow buildMatugenPalette) ----------
const themes = {
    vs: { border: "#555473", A: "#04feee", B: "#00ffcb" },
    leoneed: { border: "#2d3775", A: "#8ea3ff", B: "#9fd8ff" },
    mmj: { border: "#39662d", A: "#a4ee55", B: "#7fe9a8" },
    vbs: { border: "#561938", A: "#ff5c9a", B: "#ff96c0" },
    wxs: { border: "#6a3c11", A: "#ffa51f", B: "#ffd54a" },
    nightcord: { border: "#43285f", A: "#c08cf2", B: "#e2b5ff" },
    mono: { mono: true, border: "#444444", A: "#f4f4f4", B: "#bdbdbd" },
    // what matugen's tonal-spot gives for a red, a blue, a yellow-green and a nearly grey wallpaper
    matugenRed: { border: "#930010", A: "#ffb3ad", B: "#e7bdb2" },
    matugenBlue: { border: "#00497d", A: "#9fcaff", B: "#d6bdf0" },
    matugenLime: { border: "#3b4d00", A: "#b4d33f", B: "#8cd6b6" },
    matugenGrey: { border: "#464747", A: "#c8c6c6", B: "#c6c6c9" }
}

if (process.env.PAD_DUMP) { for (const [id, pal] of Object.entries(themes)) { const t = evaluate(pal); console.log(id.padEnd(12), "faceMid", hex(t.faceMid), "dark", hex(t.labelDark), contrast(t.labelDark, t.faceMid).toFixed(2), "light", hex(t.labelLight), contrast(t.labelLight, t.faceMid).toFixed(2), "light?", t.labelIsLight) } process.exit(0) }
// ---------- 1. Virtual Singer (the default) keeps the look the console always had ----------
// The old fixed colours, by the property that now makes them.
const original = {
    faceLight: "#79ece2", faceMid: "#3ccbd2", faceDark: "#20a5ba", wallFar: "#2fbac8", wallNear: "#082f46",
    cavityTop: "#0b5e72", cavityBottom: "#1c92aa", cavityEdge: "#74dbea", socketTop: "#0c6074", socketBottom: "#1f9bb3",
    socketEdge: "#64d6e6", dpadSocket: "#15788f", label: "#06485f", ink: "#0a2a3a", litA: "#00ffcb", litB: "#4dd0e1",
    stageTop: "#2b2272", stageMid: "#171a52", stageBottom: "#0a0c2a", bezelTop: "#2a3050", bezelBottom: "#06071a",
    keyTop: "#4a5490", keyHover: "#5560a4", keyBottom: "#1b2048", keyWall: "#0d1030", dishTop: "#5e69a8",
    wheelBase: "#4a5170", wheelRib: "#b8c0da", pearlMid: "#e6ebf8", pearlShade: "#c7d0e8", pearlText: "#2b3560",
    cartLabel: "#f4fafb", cartInk: "#1d2a5a",
    bass: "#ff9ecb", mids: "#8ee3ef", treble: "#b39ddb",
    bassLight: "#ffc2de", midsLight: "#bdf1fa", trebleLight: "#d3c6fb",
    bassDark: "#ff7fb6", midsDark: "#36c2dd", trebleDark: "#8a6fd8",
    domeAutoWall: "#2c9fb8", domeSaveWall: "#c8558d", domeUndo: "#ffe066", domeUndoWall: "#b99416",
    domeSaveAs: "#f4f6ff", domeSaveAsWall: "#8f98c0", ledOn: "#ff5fa8", lineMid: "#ffe9a8", lineEnd: "#7ff5df"
}
const vs = evaluate(themes.vs)
let worst = 0, worstName = ""
for (const [name, want] of Object.entries(original)) {
    assert(vs[name], "PadPalette has no `" + name + "`")
    const w = Qt.color(want)
    const d = Math.max(Math.abs(vs[name].r - w.r), Math.abs(vs[name].g - w.g), Math.abs(vs[name].b - w.b)) * 255
    if (d > worst) { worst = d; worstName = name + " " + hex(vs[name]) + " (was " + want + ")" }
    assert(d <= 14, "Virtual Singer: " + name + " came out " + hex(vs[name]) + ", it was " + want + " (off by " + Math.round(d) + ")")
}
assert(vs.labelIsLight === false, "Virtual Singer should keep its dark print")
console.log("Virtual Singer reproduces the old colours; furthest off: " + worstName + ", " + Math.round(worst) + "/255")

// ---------- 2. every theme gives valid, readable, distinct colours ----------
for (const [id, pal] of Object.entries(themes)) {
    const t = evaluate(pal)
    for (const [k, v] of Object.entries(t)) {
        if (v && typeof v === "object" && "r" in v && "hslHue" in v) {
            assert(isFinite(v.r + v.g + v.b + v.a) && v.r >= 0 && v.r <= 1 && v.g >= 0 && v.g <= 1 && v.b >= 0 && v.b <= 1,
                id + ": " + k + " is not a colour")
            if (pal.mono)
                assert(Math.abs(v.r - v.g) < 1e-9 && Math.abs(v.g - v.b) < 1e-9, id + ": " + k + " " + hex(v) + " has a tint in Monochrome")
        }
    }
    // dark ink on the lit gradient (the AUTO key, the chips, the bar) and the printed labels on the shell
    assert(contrast(t.ink, t.litA) >= 4.5, id + ": ink on litA is " + contrast(t.ink, t.litA).toFixed(2))
    assert(contrast(t.ink, t.litB) >= 4.5, id + ": ink on litB is " + contrast(t.ink, t.litB).toFixed(2))
    assert(contrast(t.label, t.faceMid) >= 3.5, id + ": the printed labels on the shell are " + contrast(t.label, t.faceMid).toFixed(2))
    assert(t.labelWeak ? t.labelOpacity >= 0.9 : t.labelOpacity === 0.65, id + ": the label opacity does not follow how well the print reads")
    // white text on the screen's stage
    assert(contrast(Qt.color("#ffffff"), t.stageMid) >= 8, id + ": white on the stage")
    // the three lane groups can be told apart (the chart and the jewels rely on it), grey themes included
    const g = t.groups
    for (let i = 0; i < 3; i++) for (let j = i + 1; j < 3; j++)
        assert(dist(g[i], g[j]) >= 28, id + ": groups " + i + " and " + j + " are too alike (" + Math.round(dist(g[i], g[j])) + ")")
    // each group's light / dark pair is ordered, so the jewels keep their shading
    for (let i = 0; i < 3; i++)
        assert(t.groupsLight[i].hslLightness > t.groupsDark[i].hslLightness, id + ": group " + i + " light is not lighter than dark")
    // the dome keys are four different colours
    const domes = [t.domeAuto, t.domeSave, t.domeUndo, t.domeSaveAs]
    for (let i = 0; i < 4; i++) for (let j = i + 1; j < 4; j++)
        assert(dist(domes[i], domes[j]) >= 18, id + ": dome keys " + i + " and " + j + " are too alike (" + Math.round(dist(domes[i], domes[j])) + ")")
    // the shell wall runs from lit to dark
    assert(t.wallFar.hslLightness > t.wallNear.hslLightness + 0.2, id + ": the wall does not darken")
    assert(t.faceLight.hslLightness > t.faceDark.hslLightness, id + ": the face is not lit from the top left")
}
console.log("checked " + Object.keys(themes).length + " themes: valid colours, readable ink, distinct groups and keys, grey stays grey")

// ---------- 3. a different theme gives a different console ----------
const a = evaluate(themes.vs), b = evaluate(themes.vbs), c = evaluate(themes.matugenBlue)
assert(dist(a.faceMid, b.faceMid) > 40, "the shell does not change between Virtual Singer and Vivid BAD SQUAD")
assert(dist(a.faceMid, c.faceMid) > 20, "the shell does not change for a matugen palette")
assert(dist(a.stageTop, b.stageTop) > 15, "the screen does not change between themes")

// ---------- 4. the equalizer's files ----------
const files = fs.readdirSync(eqDir).filter(f => f.endsWith(".qml") || f.endsWith(".js"))
const neutral = new Set(["#ffffff", "#000000"])
for (const f of files) {
    const text = fs.readFileSync(path.join(eqDir, f), "utf8")
    const hits = (text.match(/#[0-9a-fA-F]{6}\b/g) || []).filter(h => !neutral.has(h.toLowerCase()))
    assert.deepStrictEqual(hits, [], f + " still has hard-coded colours: " + hits.join(" "))
    assert(!/PM\.(GROUPS|LIGHT|DARK)\b/.test(text), f + " still uses PM.GROUPS / LIGHT / DARK")
    if (/PadPalette\./.test(text) && f.endsWith(".qml"))
        assert(/^import qs\.modules\.common$/m.test(text), f + " uses PadPalette without `import qs.modules.common`")
}

// every canvas paints again when the theme changes (Connections to PadPalette), except the dome's cap,
// which is painted again by its own colour properties (capColor / wallColor come from PadPalette)
const canvases = { "PadBody.qml": 1, "PadScreen.qml": 3, "PadWheel.qml": 1, "PadShoulder.qml": 1, "PadCartridge.qml": 2, "PadDpad.qml": 1, "PadDome.qml": 1 }
const viaProps = { "PadDome.qml": 1 }
for (const f of files.filter(f => f.endsWith(".qml"))) {
    const text = fs.readFileSync(path.join(eqDir, f), "utf8")
    const nCanvas = (text.match(/^\s*Canvas \{/gm) || []).length
    const nConn = (text.match(/target: PadPalette/g) || []).length
    const want = canvases[f] || 0
    assert.strictEqual(nCanvas, want + (viaProps[f] || 0), f + ": the canvases changed, update this test (" + nCanvas + ")")
    assert.strictEqual(nConn, want, f + ": " + nCanvas + " canvases but " + nConn + " repaint connections to PadPalette")
}
const dome = fs.readFileSync(path.join(eqDir, "PadDome.qml"), "utf8")
assert(/onC1Changed: requestPaint\(\)/.test(dome) && /onC2Changed: requestPaint\(\)/.test(dome), "the dome cap no longer repaints on its colours")
const popup = fs.readFileSync(path.join(eqDir, "EqualizerPopup.qml"), "utf8")
for (const k of ["domeAuto", "domeSave", "domeUndo", "domeSaveAs"])
    assert(popup.includes("capColor: PadPalette." + k), "the popup's dome key does not use PadPalette." + k)

// the palette itself
assert(/^pragma Singleton/.test(src), "PadPalette.qml must be a pragma Singleton")
assert(/readonly property var p: ThemeService\.palette/.test(src), "PadPalette must read ThemeService.palette (the repaint hangs on its `p`)")

console.log("pad_palette_test: all checks passed")
