// Runs the avatar/banner parts of services/DesktopPresetService.qml on their
// own: the functions are cut out of the .qml text and run against fakes.
const fs = require("fs")
const assert = require("assert")
const src = fs.readFileSync(process.argv[2] || require("path").join(__dirname, "..", "..", "services", "DesktopPresetService.qml"), "utf8")

function grab(name) {
    const start = src.indexOf("    function " + name + "(")
    assert(start >= 0, "no function " + name)
    const end = src.indexOf("\n    }\n", start)
    return src.slice(start, end + 7).replace(/^    function /, "function ")
}

const calls = { clear: [], exec: [], assign: [] }
const PanelImages = {
    loaded: true, avatarPath: "", bannerPath: "",
    clear(k) { calls.clear.push(k); this[k + "Path"] = "" },
    assign(k, p) { calls.assign.push([k, p]) }
}
const imager = { exec(a) { calls.exec.push(a) } }
const root = { script: "/s/preset-state.sh" }
const TodoService = { size: "full" }
for (const n of ["baseName", "imageEntry", "stable", "digestOf", "isCurrent", "wearImages", "variantKey"])
    root[n] = eval("(" + grab(n) + ")")
// the functions call root.x(...), so bind them to our fake root
for (const n of Object.keys(root)) if (typeof root[n] === "function") { const f = root[n]; root[n] = f }
let dockItems = [{ type: "app", class: "firefox", iconName: "firefox" }]
const capture = () => ({ theme: { g: "x" }, dock: { items: dockItems }, images: {
    avatar: root.imageEntry("avatar", PanelImages.avatarPath),
    banner: root.imageEntry("banner", PanelImages.bannerPath) } })
const reset = () => { calls.clear = []; calls.exec = []; calls.assign = [] }

// --- imageEntry ---
assert.deepStrictEqual(root.imageEntry("avatar", ""), null)
assert.deepStrictEqual(root.imageEntry("avatar", "/h/.local/share/sekaipop/avatar-170.PNG"),
    { file: "avatar.png", from: "avatar-170.PNG" })          // ext lower-cased, like the script
assert.deepStrictEqual(root.imageEntry("banner", "/x/banner-9"), { file: "banner", from: "banner-9" })

// --- wearImages ---
// older preset (no images part): nothing at all happens
PanelImages.avatarPath = "/d/avatar-1.png"; reset()
root.wearImages("Old", undefined); root.wearImages("Old", null)
assert.deepStrictEqual([calls.clear, calls.exec], [[], []])

// saved with none: the worn ones go back to default, only if something is worn
PanelImages.avatarPath = "/d/avatar-1.png"; PanelImages.bannerPath = ""; reset()
root.wearImages("P", { avatar: null, banner: null })
assert.deepStrictEqual(calls.clear, ["avatar"])             // banner wasn't worn: no pointless rm
assert.strictEqual(calls.exec.length, 0)

// both worn, both to be cleared: two clears in a row (PanelImages queues them)
PanelImages.avatarPath = "/d/avatar-1.png"; PanelImages.bannerPath = "/d/banner-2.png"; reset()
root.wearImages("P", { avatar: null, banner: null })
assert.deepStrictEqual(calls.clear, ["avatar", "banner"])

// different pictures: one restore call carrying both, name + file + old name
PanelImages.avatarPath = "/d/avatar-1.png"; PanelImages.bannerPath = "/d/banner-2.png"; reset()
root.wearImages("Miku look", {
    avatar: { file: "avatar.png", from: "avatar-100.png" },
    banner: { file: "banner.jpg", from: "banner-200.jpg" } })
assert.deepStrictEqual(calls.exec, [["sh", "/s/preset-state.sh", "restore", "Miku look",
    "avatar", "avatar.png", "avatar-100.png", "banner", "banner.jpg", "banner-200.jpg"]])

// the one already worn is not copied again; the other still is
PanelImages.avatarPath = "/d/avatar-100.png"; reset()
root.wearImages("Miku look", {
    avatar: { file: "avatar.png", from: "avatar-100.png" },
    banner: { file: "banner.jpg", from: "banner-200.jpg" } })
assert.deepStrictEqual(calls.exec[0].slice(4), ["banner", "banner.jpg", "banner-200.jpg"])

// everything already worn: no process at all
PanelImages.avatarPath = "/d/avatar-100.png"; PanelImages.bannerPath = "/d/banner-200.jpg"; reset()
root.wearImages("Miku look", {
    avatar: { file: "avatar.png", from: "avatar-100.png" },
    banner: { file: "banner.jpg", from: "banner-200.jpg" } })
assert.strictEqual(calls.exec.length, 0)

// a half-saved preset (only avatar mentioned) leaves the banner alone
PanelImages.avatarPath = ""; PanelImages.bannerPath = "/d/banner-2.png"; reset()
root.wearImages("P", { avatar: { file: "avatar.png", from: "avatar-5.png" } })
assert.deepStrictEqual(calls.exec[0].slice(4), ["avatar", "avatar.png", "avatar-5.png"])
assert.deepStrictEqual(calls.clear, [])

// junk in the file is ignored, not thrown on
reset(); PanelImages.avatarPath = ""; PanelImages.bannerPath = ""
root.wearImages("P", { avatar: "nope", banner: { file: 5 } })
assert.deepStrictEqual([calls.clear, calls.exec], [[], []])

// --- the tick (isCurrent) ---
// stand-in for refreshLive(): its digests (every mix of no-images / no-dock / no-frames)
function live() {
    const now = capture()
    const out = {}
    for (const ni of [false, true]) for (const nd of [false, true]) for (const nf of [false, true]) for (const np of [false, true]) for (const no of [false, true]) {
        const r = Object.assign({}, now)
        if (ni) delete r.images
        if (nd) delete r.dock
        if (np) delete r.phone
        if (no) delete r.overview
        out[root.variantKey(ni, nd, nf, np, no)] = root.stable(r)
    }
    return out
}
const mk = () => { root.liveDigests = live() }
PanelImages.avatarPath = "/d/avatar-100.png"; PanelImages.bannerPath = ""
mk()
const saved = JSON.parse(JSON.stringify(capture()))
assert.strictEqual(root.isCurrent(saved), true)             // just saved = current
PanelImages.avatarPath = "/d/avatar-777.png"; mk()
assert.strictEqual(root.isCurrent(saved), false)            // picked another avatar: tick goes
PanelImages.avatarPath = "/d/avatar-100.png"; mk()
assert.strictEqual(root.isCurrent(saved), true)             // wearing it again (restore keeps the name): tick back
// a preset from before this feature has no images, and its tick must survive
const legacy = { theme: { g: "x" } }
assert.strictEqual(root.isCurrent(legacy), true)
PanelImages.avatarPath = "/d/avatar-555.png"; mk()
assert.strictEqual(root.isCurrent(legacy), true)            // whatever avatar is worn, it never mattered to it

// the dock is part of a preset: pinning another app takes the tick away from a
// preset that holds a dock, but not from one saved before docks were in presets
PanelImages.avatarPath = "/d/avatar-100.png"; mk()
const withDock = JSON.parse(JSON.stringify(capture()))
const beforeDock = JSON.parse(JSON.stringify(capture())); delete beforeDock.dock
assert.strictEqual(root.isCurrent(withDock), true)
assert.strictEqual(root.isCurrent(beforeDock), true)
dockItems = dockItems.concat([{ type: "app", class: "kitty", iconName: "kitty" }]); mk()
assert.strictEqual(root.isCurrent(withDock), false)         // dock changed: tick goes
assert.strictEqual(root.isCurrent(beforeDock), true)        // it never held a dock: tick stays
dockItems = withDock.dock.items; mk()
assert.strictEqual(root.isCurrent(withDock), true)          // back to the same dock: tick back

console.log("preset_images_unit: all checks passed")

// DesktopPresetService lives in services/ but PanelImages.qml sits in the
// config root, a different QML module. Without `import qs` the name is
// undefined at run time: capture() throws and nothing is saved. (Quickshell
// can't be run here, so this reads the source.)
{
    const fs = require("fs"), path = require("path")
    const svc = fs.readFileSync(path.join(__dirname, "..", "..", "services", "DesktopPresetService.qml"), "utf8")
    const head = svc.split("\n").filter(l => /^import /.test(l))
    assert.ok(head.includes("import qs.modules.common"),
        "DesktopPresetService.qml uses PanelImages (modules/common) and needs `import qs.modules.common`")
    console.log("preset_images_unit: import check passed")
}
