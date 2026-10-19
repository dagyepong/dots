// QML refuses to load a file that declares a property with the name of one of Item's FINAL
// properties: `readonly property real left: ...` inside an Item gives
//   Cannot override FINAL property
// and the whole type, and everything that uses it up the chain (the lockscreen: LockCalendar ->
// LockHost -> LockRing -> Lockscreen -> shell.qml), is "unavailable", so the shell does not
// start. Node cannot load QML, so this reads every .qml file for such a declaration.
//
// The names are Qt 6.12's FINAL members of QQuickItem (listed by loading
// `Item { readonly property real NAME: 1 }` for each of its properties). A newer Qt may
// add more; add them here when the shell says "Cannot override FINAL property" for a name
// that is not in the list.
//
// A declaration is only a problem in an object that is an Item (Rectangle, Text, Row, ...).
// In a QtObject / Singleton / Process / Timer the name is free; list such a file in `allow`
// with the reason if it ever needs one.
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const FINAL = ["activeFocus", "activeFocusOnTab", "anchors", "baseline", "bottom", "childrenRect", "focus", "height",
    "horizontalCenter", "layer", "left", "opacity", "parent", "right", "top", "transform", "verticalCenter",
    "visible", "width", "x", "y", "z"]
const allow = {}   // "relative/path.qml": "reason"

const root = path.join(__dirname, "..", "..")
const found = []
function walk(dir) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        if (e.name === "node_modules" || e.name.startsWith(".")) continue
        const p = path.join(dir, e.name)
        if (e.isDirectory()) walk(p)
        else if (e.name.endsWith(".qml")) {
            const rel = path.relative(root, p)
            fs.readFileSync(p, "utf8").split("\n").forEach((line, i) => {
                const m = line.match(/^\s*(?:required\s+|readonly\s+|default\s+)*property\s+(?:alias\s+)?[\w.<>]+\s+(\w+)/)
                if (m && FINAL.includes(m[1]) && !allow[rel]) found.push(rel + ":" + (i + 1) + "  property " + m[1])
            })
        }
    }
}
walk(root)
assert.deepStrictEqual(found, [], "these declare a FINAL property of Item (QML: \"Cannot override FINAL property\"), rename them:\n  " + found.join("\n  "))

// the check itself works: it finds the declaration that broke the lockscreen
const bad = "        readonly property real left: (width - 2) / 2"
assert.ok(/^\s*(?:required\s+|readonly\s+|default\s+)*property\s+(?:alias\s+)?[\w.<>]+\s+(\w+)/.exec(bad)[1] === "left")
console.log("final_names_test: all checks passed")
