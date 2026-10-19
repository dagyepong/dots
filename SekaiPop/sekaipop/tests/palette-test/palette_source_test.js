// node tests/palette-test/palette_source_test.js   (run from the sekaipop folder)
// Quickshell can't be run here, so this reads the source to hold the Palette tool to
// its one rule: looking at a palette never changes the theme. Only the Apply and
// Undo buttons may, and only through PaletteService.apply() / undo().
const assert = require("assert"), fs = require("fs"), path = require("path")
const top = path.join(__dirname, "..", "..")
const read = rel => fs.readFileSync(path.join(top, rel), "utf8")
const code = s => s.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:"'])\/\/.*$/gm, "$1")   // no comments
const dir = "modules/sekai/palette/"
const view = ["PalettePreview.qml", "PaletteSwatch.qml", "PaletteFavorite.qml", "PaletteButton.qml", "PaletteExtractor.qml", "PaletteTool.qml"]
const widgetFile = "modules/sekai/desktopWidgets/PaletteWidget.qml"

// 1. the drawing files never name ThemeService (the preview wears no live palette, and nothing here can set one)
for (const f of view) {
    const c = code(read(dir + f))
    assert.ok(!/ThemeService/.test(c), f + " must not use ThemeService")
    assert.ok(!/applyPalette|setTheme|setMode|setDark/.test(c), f + " must not change the theme")
}

// 1b. the desktop widget is held to the same rule
{
    const w = code(read(widgetFile))
    assert.ok(!/ThemeService/.test(w), "PaletteWidget.qml must not use ThemeService")
    assert.ok(!/applyPalette|setTheme|setMode|setDark/.test(w), "PaletteWidget.qml must not change the theme")
}

// 2. the preview takes its palette only from PaletteMath.toShell
const prev = code(read(dir + "PalettePreview.qml"))
assert.ok(/PM\.toShell\(root\.colors\)/.test(prev), "preview must derive its palette with PM.toShell(colors)")
assert.ok(!/Theme\.(pal|palette|accentCyan|accentMint|colBorder|colDeep|surface\b|line\b|lineShadow|ink\b|chipFill|chipInk)/.test(prev.replace(/Theme\.(darkerFactor|darkerLineFactor|darkerShadowFactor|darkShadowFactor|lightLineAlpha|lightShadowAlpha|lightChipAlpha|dark\b|darker\b|fontFamily|fontStyleBold)/g, "")),
    "preview may read only Theme's mode and fixed constants, never the live palette")

// 3. ThemeService.applyPalette is defined once and called only by PaletteService.apply()
const hits = []
const walk = d => { for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name)
    if (e.isDirectory()) { if (e.name !== "tests") walk(p) } else if (/\.(qml|js)$/.test(e.name) && /applyPalette\(/.test(code(fs.readFileSync(p, "utf8")))) hits.push(path.relative(top, p)) } }
walk(top)
assert.deepStrictEqual(hits.sort(), ["services/PaletteService.qml", "services/ThemeService.qml"], "applyPalette( used in: " + hits)
const svc = code(read("services/PaletteService.qml"))
const fn = name => { const m = svc.match(new RegExp("function " + name + "\\([^)]*\\) \\{[\\s\\S]*?\\n    \\}\\n")); assert.ok(m, name + " not found"); return m[0] }
for (const name of ["setSource", "fillFrom", "shuffle", "toggleLock", "saveFavorite", "removeFavorite", "toggleFavorite", "useFavorite", "copy", "copyAll", "persist", "snapshot", "restore"])
    assert.ok(!/ThemeService\./.test(fn(name)), "PaletteService." + name + "() must not touch the theme")
assert.ok(/ThemeService\.applyPalette/.test(fn("apply")), "apply() applies")
assert.ok(/ThemeService\.setTheme\(root\.prevTheme\)/.test(fn("undo")), "undo() restores the previous theme")

// 4. the tool: Apply and Undo are single buttons; no IPC, no shuffle, no tab and no favourite applies anything
const tool = code(read(dir + "PaletteTool.qml"))
assert.strictEqual((tool.match(/PaletteService\.apply\(\)/g) || []).length, 1, "exactly one PaletteService.apply() call")
assert.ok(/primary: true[\s\S]{0,400}onClicked: PaletteService\.apply\(\)/.test(tool), "apply() is called by the primary button")
assert.strictEqual((tool.match(/PaletteService\.undo\(\)/g) || []).length, 1, "exactly one undo() call")
// (The tool is built on demand now, so its `palette` IPC handler lives in shell.qml, next to the loader.)
assert.ok(!/IpcHandler/.test(tool), "the tool is built on demand: its handler is not inside it")
const shellSrc = code(read("shell.qml"))
const ipc = shellSrc.match(/IpcHandler \{\s*target: "palette"[\s\S]*?\n    \}\n/)[0]
assert.ok(/function toggle\(\)/.test(ipc) && /function shuffle\(\)/.test(ipc), "the palette handler is in shell.qml")
assert.ok(!/apply|undo/.test(ipc), "the IPC handler cannot apply")
// the strings the user reads say so
assert.ok(/Preview only, theme unchanged/.test(tool))

// 4b. the desktop widget: one Apply (the primary key), one Undo, and an IPC that cannot apply
const wid = code(read(widgetFile))
assert.strictEqual((wid.match(/PaletteService\.apply\(\)/g) || []).length, 1, "widget: exactly one PaletteService.apply() call")
assert.ok(/primary: true[\s\S]{0,400}onClicked: PaletteService\.apply\(\)/.test(wid), "widget: apply() is called by the primary key")
assert.strictEqual((wid.match(/PaletteService\.undo\(\)/g) || []).length, 1, "widget: exactly one undo() call")
assert.ok(!/IpcHandler/.test(wid), "widget: no IPC inside the widget")
const sh = code(read("shell.qml"))
const cardIpc = sh.match(/target: "palettecard"[\s\S]*?\n    \}\n/)[0]
assert.ok(!/apply|undo/.test(cardIpc), "the palettecard IPC cannot apply")
assert.ok(/Preview only/.test(wid), "the widget says the theme is untouched")

// 4c. the widget is a real desktop widget: loader + gate + ipc in shell.qml, a shelf tile, switch / hide in Edit Desktop,
// the wake-up order, and a place that is saved
assert.ok(/id: palettecardGate[\s\S]{0,120}widgetId: "palettecard"/.test(sh), "shell.qml: a FocusGate for the palette card")
assert.ok(/id: paletteCardWidgetLoader[\s\S]{0,260}PaletteWidget \{\}/.test(sh), "shell.qml: a LazyLoader for PaletteWidget")
const em = code(read("services/EditMode.qml"))
assert.ok(/id: "palettecard"/.test(em), "EditMode: shelf tile")
for (const fn of ["widgetShown", "widgetOn", "addWidget", "removeWidget"])
    assert.ok(new RegExp("function " + fn + "\\([^)]*\\) \\{[\\s\\S]*?palettecard[\\s\\S]*?\\n    \\}\\n").test(em), "EditMode." + fn + " knows the palette card")
assert.ok(!/openPalette/.test(em) && !/launcher/.test(code(read("modules/sekai/editMode/EditTraySlot.qml"))), "the old launcher tile is gone")
assert.ok(/palettecard: \d+/.test(read("modules/common/functions/FocusMath.js")), "FocusMath.SLOTS has the palette card")
const ps = code(read("services/PaletteService.qml"))
for (const [key, prop] of [["x", "posX"], ["y", "posY"], ["scale", "posScale"], ["screen", "screenName"], ["shown", "shown"]]) {
    assert.ok(new RegExp("\\b" + key + ": root\\." + prop + "\\b").test(ps), "snapshot saves " + prop)
    assert.ok(new RegExp("root\\." + prop + " = s\\." + key + "\\b").test(ps), "restore reads " + prop)
}
assert.ok(/root\.shown = s\.shown === true/.test(ps), "the card stays off unless it was switched on")
assert.ok(/root\.fresh = s\.fresh === true/.test(ps), "a saved file from before the widget keeps its palette (fresh is false)")

// 5. a saved "custom" theme is accepted at startup: the colours are read synchronously, before the saved id returns
const th = code(read("services/ThemeService.qml"))
assert.ok(/blockLoading: true[\s\S]{0,80}/.test(th.match(/id: customBoot[\s\S]*?\}/)[0]), "custom colours are loaded synchronously")
assert.ok(/root\.bootCustom\(\); root\.bootSaved\(\)/.test(th), "bootCustom runs before bootSaved / the async theme load")
assert.ok(/root\.customPalette \? \[[\s\S]*?id: "custom"/.test(th), "the custom group exists only once a palette was applied")

// 6. brace balance of every new / edited QML file (strings and comments removed), and every JS import resolves
// (ThemeService.qml has a template string the crude counter below misreads, so only the
// block this feature added to it is counted, below.)
const files = view.map(f => dir + f).concat([widgetFile, "services/PaletteService.qml", "services/EditMode.qml", "modules/sekai/editMode/EditTraySlot.qml", "modules/sekai/desktopWidgets/FocusGate.qml", "shell.qml", "modules/sekai/settings/SettingsPageQuick.qml", "modules/sekai/settings/SettingsPageDesktop.qml"])
for (const f of files) {
    const raw = read(f)
    const c = code(raw).replace(/"(?:[^"\\\n]|\\.)*"/g, '""').replace(/'(?:[^'\\\n]|\\.)*'/g, "''")
    for (const [o, cl] of [["{", "}"], ["(", ")"], ["[", "]"]])
        assert.strictEqual(c.split(o).length, c.split(cl).length, f + ": unbalanced " + o + cl)
    for (const m of raw.matchAll(/import "([^"]+\.js)" as/g))
        assert.ok(fs.existsSync(path.join(top, path.dirname(f), m[1])), f + ": missing " + m[1])
}
const blk = read("services/ThemeService.qml")
const added = blk.slice(blk.indexOf("// ===== custom palette"), blk.indexOf("property string current"))
const ac = code(added).replace(/"(?:[^"\\\n]|\\.)*"/g, '""')
for (const [o, cl] of [["{", "}"], ["(", ")"], ["[", "]"]])
    assert.strictEqual(ac.split(o).length, ac.split(cl).length, "ThemeService custom block: unbalanced " + o + cl)
console.log("palette_source_test: all checks passed")
