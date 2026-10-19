// A first run: only the clock widget is on, window borders follow the theme, and Log out works
// on Hyprland 0.55+ (Lua config). Node cannot load QML, so this reads the source.
const fs = require("fs")
const path = require("path")
const assert = require("assert")
const root = path.join(__dirname, "..", "..")
const read = f => fs.readFileSync(path.join(root, f), "utf8")

for (const f of ["TodoService", "UserCardService", "WeatherCardService", "VisualizerService"])
    assert.ok(/property bool shown: false/.test(read("services/" + f + ".qml")), f + " starts off")
assert.ok(/property bool shown: true/.test(read("services/ClockService.qml")), "the clock starts on")

assert.ok(/"appTheme\.hyprland": true/.test(read("services/SettingsService.qml")), "window borders follow the theme by default")

const sh = read("scripts/system/session-logout.sh")
assert.ok(sh.includes("hyprctl dispatch 'hl.dsp.exit()'"), "logout script uses the Lua dispatcher")
assert.ok(sh.includes("loginctl terminate-session"), "logout script has a logind fallback")
assert.ok(sh.indexOf("hl.dsp.exit()") < sh.indexOf("dispatch exit"), "Lua form is tried first")
assert.ok(read("modules/common/functions/Extras.js").includes("hl.dsp.exit()"), "launcher Log out uses the Lua dispatcher too")

console.log("first_run_defaults_test: ok")
