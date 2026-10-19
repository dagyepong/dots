// Edit Desktop -> DOCK -> APPS switches a pinned app off without unpinning it: the app keeps
// its place in the layout (and in presets), the dock draws no key for it, and the drag-to-reorder
// code, which used to treat a key's row number as its place in the layout, now goes by pinIndex.
// Node cannot load QML, so the real functions are cut out of the source and run here.
// Run: node hidden_apps_test.js
const fs = require("fs"), assert = require("assert")
const read = f => fs.readFileSync(__dirname + "/../../" + f, "utf8")
const P = read("services/PinnedAppsService.qml")
const D = read("modules/sekai/dock/Dock.qml")
const B = read("modules/sekai/editMode/EditDockBoard.qml")

// the source of `function name(...) { ... }` (brace matched)
function fn(src, name) {
    const at = src.indexOf("function " + name + "(")
    assert.ok(at >= 0, "found function " + name)
    let i = src.indexOf("{", src.indexOf(")", at)), depth = 0
    for (let j = i; j < src.length; j++) {
        if (src[j] === "{") depth++
        else if (src[j] === "}" && --depth === 0) return src.slice(at, j + 1)
    }
    throw new Error("unbalanced " + name)
}

// ----- PinnedAppsService, with `root` standing in for the singleton -----
const svc = { pinned: [], saved: 0 }
svc.commit = next => { svc.pinned = next; svc.saved++ }
for (const n of ["kindOf", "allApps", "isPinned", "copy", "isHidden", "setHidden", "toggleHidden",
                 "shownCount", "folderShown", "deleteFolder", "removeFromFolder", "unpin"])
    svc[n] = new Function("root", "return (" + fn(P, n).replace(/^function \w+/, "function") + ")")(svc)

const app = (cls, extra) => Object.assign({ type: "app", class: cls, iconName: cls }, extra || {})
const folder = (name, apps) => ({ type: "folder", name, apps })

// off and on again; the field is left out when the app is on
svc.pinned = [app("a"), app("b"), { type: "sep" }, app("c")]
svc.setHidden("b", true)
assert.strictEqual(svc.pinned[1].hidden, true, "b is switched off")
assert.ok(svc.isHidden("b") && !svc.isHidden("a"), "isHidden tells them apart")
assert.ok(svc.isPinned("b"), "an off app is still pinned")
assert.strictEqual(svc.shownCount(), 2, "two of three apps are on")
const saves = svc.saved
svc.setHidden("b", true)
assert.strictEqual(svc.saved, saves, "switching off what is already off writes nothing")
svc.toggleHidden("b")
assert.ok(!("hidden" in svc.pinned[1]), "back on: no hidden field left behind")
svc.setHidden("nope", true)
assert.strictEqual(svc.saved, saves + 1, "an app that is not pinned is ignored")

// inside a folder
svc.pinned = [folder("F", [app("x"), app("y")]), app("z")]
svc.setHidden("y", true)
assert.strictEqual(svc.pinned[0].apps[1].hidden, true, "an app inside a folder can be switched off")
assert.ok(svc.folderShown(svc.pinned[0]), "a folder with one app on is shown")
svc.setHidden("x", true)
assert.ok(!svc.folderShown(svc.pinned[0]), "a folder with every app off is not shown")
svc.deleteFolder(0)
assert.deepStrictEqual(svc.pinned.map(i => [i.class, i.hidden === true]), [["x", true], ["y", true], ["z", false]],
    "deleting a folder keeps its apps' on / off")
svc.pinned = [folder("F", [app("x", { hidden: true }), app("y")])]
svc.removeFromFolder(0, "x")
assert.strictEqual(svc.pinned[1].hidden, true, "taking an app out of a folder keeps it off")

// ----- Dock.qml: slotFor + pinnedSlots -----
const dock = {
    toolMeta: { search: { label: "Search", icon: "search" } },
    appName: (c) => c.toUpperCase()
}
dock.slotFor = new Function("PinnedAppsService", "dockWindow",
    "return (" + fn(D, "slotFor").replace(/^function \w+/, "function") + ")")(svc, dock)
const blockAt = D.indexOf("readonly property var pinnedSlots: {")
assert.ok(blockAt >= 0, "pinnedSlots is a block binding")
let depth = 0, end = D.indexOf("{", blockAt)
for (let j = end; j < D.length; j++) {
    if (D[j] === "{") depth++
    else if (D[j] === "}" && --depth === 0) { end = j; break }
}
const slotsBody = D.slice(D.indexOf("{", blockAt), end + 1)
const slots = () => new Function("PinnedAppsService", "dockWindow", slotsBody.replace(/^\{/, "").replace(/\}$/, ""))(svc, dock)
const shape = () => slots().map(s => s.kind === "sep" ? "|" : (s.kind === "folder" ? "[" + s.apps.map(a => a.class).join("") + "]" : s.class)).join(" ")

svc.pinned = [app("a"), app("b"), app("c")]
assert.strictEqual(shape(), "a b c", "nothing off: the dock is as before")
svc.setHidden("b", true)
assert.strictEqual(shape(), "a c", "an app that is off has no key")
assert.deepStrictEqual(slots().map(s => s.pinIndex), [0, 2], "the keys keep their place in the layout (pinIndex)")

svc.pinned = [app("a"), { type: "sep" }, app("b", { hidden: true }), { type: "sep" }, app("c")]
assert.strictEqual(shape(), "a | c", "two separators round an off app become one")
svc.pinned = [app("a", { hidden: true }), { type: "sep" }, app("b")]
assert.strictEqual(shape(), "b", "a separator left first is dropped")
svc.pinned = [app("a"), { type: "sep" }, app("b", { hidden: true })]
assert.strictEqual(shape(), "a", "a separator left last is dropped")
svc.pinned = [app("a"), { type: "sep" }, { type: "sep" }, app("b")]
assert.strictEqual(shape(), "a | | b", "separators the person made are left alone")
svc.pinned = [app("a"), { type: "sep" }]
assert.strictEqual(shape(), "a |", "so is a trailing one when nothing is off")
svc.pinned = [folder("F", [app("x", { hidden: true }), app("y")]), folder("G", [app("z", { hidden: true })])]
assert.strictEqual(shape(), "[y]", "a folder shows only its apps that are on, and none when all are off")

// ----- dragging: row numbers are turned into layout places -----
const endDrag = D.slice(D.indexOf("function endDrag()"))
assert.ok(/PinnedAppsService\.move\(row\.pinIndex, rows\[target\]\.pinIndex\)/.test(endDrag), "reordering goes by pinIndex")
assert.ok(!/PinnedAppsService\.move\(from, target\)/.test(D), "the old row-number move is gone")
assert.ok(/PinnedAppsService\.pin\(row\.class, row\.iconName, at\)/.test(endDrag), "pinning a running app goes by pinIndex too")
assert.ok(/PinnedAppsService\.folderShown\(it\)/.test(D), "\"Add to folder\" does not offer a folder with nothing showing")

// ----- the board -----
assert.ok(/title: "APPS"/.test(B), "the DOCK tab has an APPS group")
assert.ok(/on: modelData\.hidden !== true/.test(B), "a key is lit while its app is on the dock")
assert.ok(/onPicked: PinnedAppsService\.toggleHidden\(modelData\.class\)/.test(B), "a click switches the app")
assert.ok(!/Flickable/.test(B), "the board still has no scrolling, the keys wrap instead")
assert.ok(fs.existsSync(__dirname + "/../../modules/sekai/editMode/EditAppKey.qml"), "EditAppKey.qml exists")

console.log("hidden_apps_test: ok")
