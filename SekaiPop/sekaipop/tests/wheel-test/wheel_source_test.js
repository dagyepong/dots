// node tests/wheel-test/wheel_source_test.js   (run from the sekaipop folder)
// Quickshell can't be run here, so this reads the source to hold every scrolling
// area to one wheel feel. A list that is left on Qt's own wheel handling scrolls
// less (and differently) than the rest, which is what made "some lists need a lot
// of scrolling and some don't".
//   1. every scrolling ListView / GridView / Flickable either has a
//      `WheelScroll { scroller: <id> }` or is on the list of areas that scroll
//      some other way (and say so);
//   2. no handler does its own wheel distance maths: it calls Theme.wheelPx.
const assert = require("assert"), fs = require("fs"), path = require("path")
const top = path.join(__dirname, "..", "..")
const code = s => s.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:"'])\/\/.*$/gm, "$1")   // no comments

const files = []
const walk = d => { for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name)
    if (e.isDirectory()) { if (e.name !== "tests") walk(p) } else if (/\.qml$/.test(e.name)) files.push(p) } }
walk(top)

// Scroll areas that are not on WheelScroll on purpose, as "file:id".
const other = {
    "modules/sekai/notificationPopup/NotificationPopup.qml:list": "interactive: false, never scrolls",
    "modules/sekai/cheatSheet/CheatSheet.qml:flick": "animated scroll; its own handler calls Theme.wheelPx",
    "modules/sekai/desktopWidgets/StickyNote.qml:flick": "sits under a text editor; its own handler calls Theme.wheelPx",
    "modules/sekai/overview/Overview.qml:viewport": "not a Flickable; its handler calls Theme.wheelPx",
    "modules/sekai/settings/SettingsPage.qml:chipStrip": "sideways row; its handler calls Theme.wheelPx(event, true)",
    "modules/sekai/editMode/EditThemeBoard.qml:flick": "sideways row; its handler calls Theme.wheelPx(event, true)",
    "modules/sekai/editMode/EditPresetBoard.qml:flick": "sideways row; its handler calls Theme.wheelPx(event, true)",
    "modules/sekai/editMode/EditTray.qml:shelf": "sideways row; its handler calls Theme.wheelPx(event, true)",
    "modules/sekai/palette/PaletteTool.qml:favFlick": "sideways row; its handler calls Theme.wheelPx(event, true)",
    "modules/sekai/desktopWidgets/PaletteWidget.qml:favFlick": "sideways row; its handler calls Theme.wheelPx(event, true)",
}

// 1. every view has a WheelScroll (or a reason it does not)
const views = []
for (const f of files) {
    const rel = path.relative(top, f).split(path.sep).join("/")
    const c = code(fs.readFileSync(f, "utf8"))
    const re = /\b(ListView|GridView|Flickable)\s*\{\s*id:\s*(\w+)/g
    let m
    while ((m = re.exec(c))) views.push({ rel, id: m[2], c })
}
assert.ok(views.length >= 20, "found only " + views.length + " scrolling views - did the pattern break?")
for (const v of views) {
    const key = v.rel + ":" + v.id
    if (key in other) continue
    assert.ok(new RegExp("WheelScroll\\s*\\{[^}]*scroller:\\s*" + v.id + "\\b").test(v.c),
        key + " scrolls on Qt's own wheel; add `WheelScroll { scroller: " + v.id + " }` next to it " +
        "(or list it in `other` with the reason)")
}

// 2. nobody does their own wheel distance maths
for (const f of files) {
    const rel = path.relative(top, f).split(path.sep).join("/")
    const c = code(fs.readFileSync(f, "utf8"))
    // a handler that moves contentX / contentY / scrollBy must take its distance from Theme.wheelPx
    const re = /onWheel:\s*\w+\s*=>\s*\{([\s\S]*?)\n\s{0,40}\}\s*\n/g
    let m
    while ((m = re.exec(c))) {
        const body = m[1]
        if (/contentX|contentY|scrollBy/.test(body))
            assert.ok(/Theme\.wheelPx/.test(body), rel + ": a wheel handler scrolls without Theme.wheelPx")
    }
}
for (const rel of ["modules/sekai/desktopWidgets/StickyNote.qml"])
    assert.ok(/contentY - Theme\.wheelPx\(event\)/.test(code(fs.readFileSync(path.join(top, rel), "utf8"))), rel + " must scroll by Theme.wheelPx")

// 3. the helper and the shared layer agree
const theme = code(fs.readFileSync(path.join(top, "modules/common/Theme.qml"), "utf8"))
assert.ok(/function wheelPx\(event, sideways\)/.test(theme), "Theme.wheelPx is missing")
const ws = code(fs.readFileSync(path.join(top, "modules/common/widgets/WheelScroll.qml"), "utf8"))
assert.ok(/Theme\.wheelPx\(event, sideways\)/.test(ws), "WheelScroll must take its distance from Theme.wheelPx")

console.log("wheel_source_test: ok (" + views.length + " scrolling views checked)")
