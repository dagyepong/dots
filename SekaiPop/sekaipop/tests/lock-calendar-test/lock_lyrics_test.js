// Lyrics on the gacha lockscreen: a setting (off by default, kept by presets), a toggle,
// a LockLyrics capsule under the clock, and the phone / window shadows. Quickshell can't run
// here, so the wiring is read from source. Run: node lock_lyrics_test.js
const fs = require("fs"), assert = require("assert"), path = require("path")
const read = f => fs.readFileSync(path.join(__dirname, "..", "..", f), "utf8")
const ss = read("services/SettingsService.qml"), dp = read("services/DesktopPresetService.qml")
const gen = read("modules/sekai/settings/SettingsPageGeneral.qml")
const surf = read("modules/sekai/lock/LockSurface.qml"), L = read("modules/sekai/lock/LockLyrics.qml")
const phone = read("modules/sekai/phone/PhoneBody.qml")
const rules = fs.readFileSync(path.join(__dirname, "../../../hypr/hyprland/rules.lua"), "utf8")
const general = fs.readFileSync(path.join(__dirname, "../../../hypr/hyprland/general.lua"), "utf8")

assert.ok(/"lock\.lyrics": false/.test(ss), "lock.lyrics exists and is off by default")
assert.ok(/"lock\.lyrics"/.test(dp.slice(dp.indexOf("readonly property var keepExact"), dp.indexOf("readonly property var keepExact") + 3000)), "presets leave lock.lyrics alone")
assert.ok(/SettingsService\.toggle\("lock\.lyrics"\)/.test(gen), "Settings has the toggle")
assert.ok(/active: SettingsService\.flag\("lock\.lyrics"\)/.test(surf) && /LockLyrics\s*\{/.test(surf), "the lockscreen builds it only while on")
assert.ok(/media: lyricsLoader\.player/.test(surf), "the capsule gets the lockscreen's player")
assert.ok(/LyricsService\.request\(/.test(L) && /LyricsService\.lines/.test(L), "it uses LyricsService")
assert.ok(/LM\.lineIndexAt\(root\.lines, root\.clockT\)/.test(L) && /LyricsService\.syncTotal/.test(L), "same clock maths and nudge as the widget")
assert.ok(/running: root\.working/.test(L) && /running: root\.haveLines && root\.playing/.test(L), "nothing ticks without a song / lyrics")
assert.ok(/property bool shadow: SettingsService\.flag\("quick\.phoneShadow"\)/.test(phone) && /visible: root\.shadow && !root\.flat/.test(phone), "phone has a switchable shadow")
assert.ok(!/no_shadow = true/.test(rules), "tiled windows are no longer shadow-free")
assert.ok(/rgba\(0000005a\)/.test(general), "the default window shadow is visible")
console.log("lock_lyrics_test: ok")
