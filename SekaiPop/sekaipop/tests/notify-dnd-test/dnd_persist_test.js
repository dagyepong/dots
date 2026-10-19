// The Quick Panel's Notifications tile (OFF = do-not-disturb) is kept in settings.json,
// so a silenced desktop stays silent after a shell restart, and a preset does not undo it.
// Node cannot load QML, so this reads the source for the pieces that make that work.
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const root = path.join(__dirname, "..", "..")
const read = f => fs.readFileSync(path.join(root, f), "utf8")
const qs = read("services/QuickSource.qml")
const ss = read("services/SettingsService.qml")
const dp = read("services/DesktopPresetService.qml")
const shell = read("shell.qml")

// the setting exists and defaults to ON (nothing changes for anyone who never touches the tile)
assert.ok(/"notify\.on": true/.test(ss), "SettingsService has notify.on, default true")

// the tile reads the setting instead of a plain property that resets to true at every start
assert.ok(/readonly property bool notificationsOn: SettingsService\.flag\("notify\.on"\)/.test(qs),
    "QuickSource.notificationsOn is bound to the notify.on setting")
assert.ok(!/property bool notificationsOn: true/.test(qs), "no plain notificationsOn: true left")

// toggling writes the setting (which saves it)
const toggle = qs.slice(qs.indexOf("function toggleNotifications()"), qs.indexOf("function toggleNotifications()") + 200)
assert.ok(/SettingsService\.toggle\("notify\.on"\)/.test(toggle), "toggleNotifications toggles notify.on")
assert.ok(!/notificationsOn = /.test(qs), "nothing assigns notificationsOn directly (it is read-only now)")

// do-not-disturb is still what shell.qml hands the notification source
assert.ok(/doNotDisturb: !quickState\.notificationsOn/.test(shell), "shell.qml still ties doNotDisturb to the tile")

// wearing a preset keeps the person's choice, like the 24-hour clock
const keep = dp.slice(dp.indexOf("property var keepExact"), dp.indexOf("]", dp.indexOf("property var keepExact")))
assert.ok(/"notify\.on"/.test(keep), "notify.on is in DesktopPresetService.keepExact")

console.log("notify-dnd-test: ok")
