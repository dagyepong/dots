// A first run (no saved dark / light choice) starts the shell in DARK mode.
// Node cannot load QML, so this reads the source for the pieces that make that work.
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const root = path.join(__dirname, "..", "..")
const th = fs.readFileSync(path.join(root, "services/ThemeService.qml"), "utf8")
const ub = fs.readFileSync(path.join(root, "modules/sekai/bar/UtilButtons.qml"), "utf8")

assert.ok(/property bool dark: true/.test(th), "ThemeService.dark defaults to true (dark)")
assert.ok(!/property bool dark: false/.test(th), "no light default left")
assert.ok(/root\.bootCustom\(\); root\.bootSaved\(\)/.test(th), "bootSaved still runs at startup")

// bootSaved: nothing saved -> first-run path that saves dark and sets the system scheme
const boot = th.slice(th.indexOf("function bootSaved()"), th.indexOf("function bootSaved()") + 900)
assert.ok(/d === null[\s\S]*firstRunDark\(\)/.test(boot), "bootSaved calls firstRunDark when nothing is saved")

const first = th.slice(th.indexOf("function firstRunDark()"), th.indexOf("function firstRunDark()") + 400)
assert.ok(/darkSaver\.save\(true\)/.test(first), "first run saves dark = on")
assert.ok(/syncSystemScheme\(false\)/.test(first), "first run asks for a dark system scheme")
assert.ok(/firstDarkPending = true/.test(first), "first run sets the pending guard")

// the bar must not undo it with a light scheme that has not been changed yet
assert.ok(/ThemeService\.firstDarkPending/.test(ub), "UtilButtons checks firstDarkPending")
assert.ok(/ThemeService\.firstDarkDone\(\)/.test(ub), "UtilButtons ends the guard when the scheme turns dark")

console.log("theme-default-test: ok")
