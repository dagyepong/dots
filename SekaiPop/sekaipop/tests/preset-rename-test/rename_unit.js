// Renaming a preset: preset-state.sh's `rename` mode runs for real in a temp
// folder, DesktopPresetService.rename() is cut out of the .qml and run against
// fakes, and the board's wiring is checked as text (Quickshell can't run here).
const fs = require("fs"), os = require("os"), path = require("path"), assert = require("assert")
const { spawnSync } = require("child_process")
const top = path.join(__dirname, "..", "..")
const read = f => fs.readFileSync(require("../lib/locate")(f), "utf8")

// ---------- the script ----------
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "presets-"))
const env = Object.assign({}, process.env, { XDG_CONFIG_HOME: path.join(tmp, "config"), XDG_STATE_HOME: path.join(tmp, "state"), XDG_DATA_HOME: path.join(tmp, "data") })
const dir = path.join(tmp, "config", "sekaipop", "presets")
const sh = (...a) => spawnSync("sh", [path.join(top, "scripts", "state", "preset-state.sh"), ...a], { env, encoding: "utf8" })
const png = path.join(tmp, "a.png"); fs.writeFileSync(png, "x")
const json = n => JSON.stringify({ _meta: { name: n, v: 1 }, theme: { group: "g" } })

assert.strictEqual(sh("save", "Night", json("Night"), png, "-").status, 0)
assert.strictEqual(sh("save", "Day", json("Day")).status, 0)
assert.ok(fs.existsSync(path.join(dir, "Night.images", "avatar.png")))

let r = sh("rename", "Night", "Late night", json("Late night"))
assert.strictEqual(r.status, 0, r.stderr)
assert.ok(!fs.existsSync(path.join(dir, "Night.json")), "old file is gone")
assert.ok(!fs.existsSync(path.join(dir, "Night.images")), "old pictures folder is gone")
assert.ok(fs.existsSync(path.join(dir, "Late night.images", "avatar.png")), "pictures moved with it")
assert.strictEqual(JSON.parse(fs.readFileSync(path.join(dir, "Late night.json"), "utf8"))._meta.name, "Late night", "name inside is the new one")
assert.ok(sh("all").stdout.split("\n").some(l => l.startsWith("Late night\t")), "listed under the new name")

// a name another preset has: refused, nothing changes
r = sh("rename", "Late night", "Day", json("Day"))
assert.strictEqual(r.status, 3, "taken name -> exit 3")
assert.ok(fs.existsSync(path.join(dir, "Late night.json")) && fs.existsSync(path.join(dir, "Late night.images")))
assert.strictEqual(JSON.parse(fs.readFileSync(path.join(dir, "Day.json"), "utf8"))._meta.name, "Day", "the other preset is untouched")

// no such preset, bad names, missing json
assert.strictEqual(sh("rename", "Nope", "X", json("X")).status, 1)
assert.strictEqual(sh("rename", "Day", "a/b", json("x")).status, 2)
assert.strictEqual(sh("rename", "Day", ".hid", json("x")).status, 2)
assert.strictEqual(sh("rename", "Day", "", json("x")).status, 2)
assert.strictEqual(sh("rename", "Day", "New").status, 2, "no json -> refused")
assert.ok(fs.existsSync(path.join(dir, "Day.json")))

// capitals only, and the same name
assert.strictEqual(sh("rename", "Day", "DAY", json("DAY")).status, 0)
assert.ok(fs.existsSync(path.join(dir, "DAY.json")) && !fs.existsSync(path.join(dir, "Day.json")))
assert.strictEqual(sh("rename", "DAY", "DAY", json("DAY")).status, 0)
assert.ok(fs.existsSync(path.join(dir, "DAY.json")))

// a pictures folder left behind by a gone preset doesn't come along
fs.mkdirSync(path.join(dir, "Ghost.images")); fs.writeFileSync(path.join(dir, "Ghost.images", "banner.png"), "x")
assert.strictEqual(sh("rename", "DAY", "Ghost", json("Ghost")).status, 0)
assert.ok(!fs.existsSync(path.join(dir, "Ghost.images")), "no stray pictures under the new name")

// wearing the pictures still works under the new name
const data = path.join(tmp, "data", "sekaipop")
r = sh("restore", "Late night", "avatar", "avatar.png", "avatar-1.png")
assert.strictEqual(r.status, 0); assert.ok(fs.existsSync(path.join(data, "avatar-1.png")), "restore finds the renamed folder")
assert.ok(!fs.readdirSync(dir).some(f => f.endsWith(".tmp")), "no temp files left")
fs.rmSync(tmp, { recursive: true, force: true })

// ---------- the service function ----------
const src = read("services/DesktopPresetService.qml")
function grab(name) {
    const start = src.indexOf("    function " + name + "(")
    assert(start >= 0, "no function " + name)
    return src.slice(start, src.indexOf("\n    }\n", start) + 7).replace(/^    function /, "function ")
}
// The sticky notes follow a rename (NotesService.renameSet).
const noteCalls = []
const NotesService = { renameSet: (a, b) => noteCalls.push([a, b]) }
const mk = names => names.map(n => ({ name: n, data: { theme: { g: n }, _meta: { name: n, saved: 5, v: 1 } } }))
const jobs = []
const root = { presets: mk(["Day", "Night", "Zed"]), lastName: "", pendingName: "", script: "/s.sh", enqueue: a => jobs.push(a) }
for (const n of ["find", "cleanName", "byName", "rename"]) root[n] = eval("(" + grab(n).replace(/root\./g, "root.") + ")")
const names = () => root.presets.map(p => p.name)

assert.strictEqual(root.rename("Nope", "X"), "", "no such preset")
assert.strictEqual(root.rename("Day", "   "), "", "empty name")
assert.strictEqual(root.rename("Day", "///"), "", "a name that cleans to nothing")
assert.strictEqual(root.rename("Day", "night"), "", "another preset's name, in other capitals")
assert.strictEqual(root.rename("Day", "Zed"), "")
assert.strictEqual(jobs.length, 0, "refused: no job")
assert.deepStrictEqual(names(), ["Day", "Night", "Zed"])
assert.strictEqual(root.rename("Day", "Day"), "Day"); assert.strictEqual(jobs.length, 0, "same name: nothing to do")

const before = root.presets[0].data
root.lastName = "Day"; root.pendingName = "Day"
assert.strictEqual(root.rename("Day", "  Evening  //desk "), "Evening desk", "the name is cleaned the way saving does")
assert.deepStrictEqual(names(), ["Evening desk", "Night", "Zed"], "list is re-sorted at once")
assert.strictEqual(jobs.length, 1)
assert.deepStrictEqual(jobs[0].slice(0, 5), ["sh", "/s.sh", "rename", "Day", "Evening desk"])
const sent = JSON.parse(jobs[0][5])
assert.strictEqual(sent._meta.name, "Evening desk"); assert.strictEqual(sent._meta.saved, 5, "saved time kept"); assert.deepStrictEqual(sent.theme, { g: "Day" })
assert.strictEqual(before._meta.name, "Day", "the old data object isn't edited in place")
assert.strictEqual(root.lastName, "Evening desk"); assert.strictEqual(root.pendingName, "Evening desk")
assert.deepStrictEqual(noteCalls, [["Day", "Evening desk"]], "the preset's notes are renamed with it, and only on a real rename")

assert.strictEqual(root.rename("Zed", "ZED"), "ZED", "capitals only")
assert.deepStrictEqual(names(), ["Evening desk", "Night", "ZED"])
root.lastName = "Night"; root.rename("Evening desk", "Aaa"); assert.strictEqual(root.lastName, "Night", "another preset's name isn't touched")
assert.deepStrictEqual(names(), ["Aaa", "Night", "ZED"])

// ---------- the wiring ----------
assert.ok(src.includes("function rename(name: string, to: string): string") && src.includes("presets rename"), "ipc rename")
const board = read("EditPresetBoard.qml")
for (const t of ["id: renameBtn", "id: renameArea", "tile.beginRename()", "id: nameInput", "function commitRename()", "function endRename()",
                 "DesktopPresetService.rename(tile.entry.name, nameInput.text)", "Keys.onEscapePressed", "if (tile.renaming)\n                    return"])
    assert.ok(board.includes(t), "board: " + t)
assert.ok(/visible: \(tileArea\.containsMouse[^\n]*\n[^\n]*!tile\.renaming/.test(board), "SAVE OVER hides while renaming")
console.log("rename_unit: all checks passed")
