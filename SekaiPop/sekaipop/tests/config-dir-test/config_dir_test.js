// The user's adjustments (settings.json, scale.json) and presets live in
// ~/.config/sekaipop, and what an older version left in ~/.local/state/sekaipop or
// next to shell.qml is moved over once, never over something already there.
const assert = require("assert")
const fs = require("fs")
const os = require("os")
const path = require("path")
const { spawnSync } = require("child_process")

const top = path.join(__dirname, "..", "..")
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "cfgdir-"))
const env = Object.assign({}, process.env, {
    XDG_CONFIG_HOME: path.join(tmp, "config"), XDG_STATE_HOME: path.join(tmp, "state"), XDG_DATA_HOME: path.join(tmp, "data")
})
const cfg = (...p) => path.join(tmp, "config", "sekaipop", ...p)
const old = (...p) => path.join(tmp, "state", "sekaipop", ...p)
const run = (script, ...a) => spawnSync("sh", [path.join(top, "scripts", "state", script), ...a], { env, encoding: "utf8" })
const put = (f, t) => { fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, t) }

// ---------- settings.json ----------
put(old("settings.json"), '{"a":1}\n')
let r = run("settings-state.sh", "load")
assert.strictEqual(r.status, 0)
assert.strictEqual(r.stdout.trim(), '{"a":1}', "the old settings are read from the new place")
assert.ok(fs.existsSync(cfg("settings.json")) && !fs.existsSync(old("settings.json")), "moved, not copied")
run("settings-state.sh", "save", '{"a":2}')
assert.strictEqual(fs.readFileSync(cfg("settings.json"), "utf8").trim(), '{"a":2}', "saves go to ~/.config")
put(old("settings.json"), '{"a":99}\n')
assert.strictEqual(run("settings-state.sh", "load").stdout.trim(), '{"a":2}', "a file already in ~/.config is never overwritten")

// ---------- presets ----------
put(old("presets", "Night.json"), '{"_meta":{"name":"Night","v":1}}\n')
put(old("presets", "Night.images", "avatar.png"), "x")
r = run("preset-state.sh", "all")
assert.strictEqual(r.status, 0)
assert.ok(r.stdout.startsWith("Night\t"), "old presets are listed from the new place")
assert.ok(fs.existsSync(cfg("presets", "Night.images", "avatar.png")), "the pictures came along")
assert.ok(!fs.existsSync(old("presets")), "the old folder is gone")
assert.strictEqual(run("preset-state.sh", "save", "Day", '{"_meta":{"name":"Day","v":1}}').status, 0)
assert.ok(fs.existsSync(cfg("presets", "Day.json")), "new presets are saved in ~/.config")
put(old("presets", "Stale.json"), "{}")
run("preset-state.sh", "all")
assert.ok(!fs.existsSync(cfg("presets", "Stale.json")), "an existing presets folder is not merged into")

// ---------- scale.json ----------
const shellScale = path.join(tmp, "shell", "scale.json")
put(shellScale, '{"default":1.25,"monitors":{}}\n')
assert.strictEqual(run("scale-state.sh", "init", shellScale).status, 0)
assert.strictEqual(JSON.parse(fs.readFileSync(cfg("scale.json"), "utf8")).default, 1.25, "the old scale.json is copied over")
assert.ok(fs.existsSync(shellScale), "the old one is left where it was")
put(shellScale, '{"default":2,"monitors":{}}\n')
run("scale-state.sh", "init", shellScale)
assert.strictEqual(JSON.parse(fs.readFileSync(cfg("scale.json"), "utf8")).default, 1.25, "an existing file is never touched")
fs.rmSync(cfg("scale.json"))
run("scale-state.sh", "init", path.join(tmp, "nothing.json"))
assert.strictEqual(JSON.parse(fs.readFileSync(cfg("scale.json"), "utf8")).default, 1, "no old file: the defaults")

// ---------- the QML side ----------
const scaleQml = fs.readFileSync(path.join(top, "services", "ShellScale.qml"), "utf8")
assert.ok(scaleQml.includes('"/sekaipop"') && scaleQml.includes("XDG_CONFIG_HOME") && !scaleQml.includes('shellDir + "/scale.json"\n        watch'), "ShellScale watches the config file")
assert.ok(!fs.existsSync(path.join(top, "scale.json")), "no scale.json is shipped (it would overwrite the user's)")

console.log("config dir ok")
