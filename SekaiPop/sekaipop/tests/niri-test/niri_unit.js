// The niri workspace badges (modules/common/functions/NiriMath.js), fed lines
// shaped like niri's event stream. Run: node niri_unit.js
const fs = require("fs")
const assert = require("assert")
const locate = require("../lib/locate.js")

const src = fs.readFileSync(locate("modules/common/functions/NiriMath.js"), "utf8").replace(".pragma library", "")
const N = {}
new Function("N", src + ";N.parse=parse;N.applyEvent=applyEvent;N.activeOn=activeOn;N.occupiedOn=occupiedOn;N.idOf=idOf;")(N)

const workspace = (id, idx, output, extra) => Object.assign({
    id, idx, name: null, output, is_urgent: false, is_active: false, is_focused: false, active_window_id: null,
}, extra || {})

// one event as niri sends it, through the same parse step the service uses
const line = event => N.parse(JSON.stringify(event))

// two outputs: eDP-1 has 1 (active, a window), 2 (a window), 3 (empty); HDMI-A-1 has 1 (active, empty)
const start = [
    workspace(10, 1, "eDP-1", { is_active: true, is_focused: true, active_window_id: 5 }),
    workspace(11, 2, "eDP-1", { active_window_id: 6 }),
    workspace(12, 3, "eDP-1"),
    workspace(20, 1, "HDMI-A-1", { is_active: true }),
]

// 1. the full list replaces whatever was there
let state = N.applyEvent([], line({ WorkspacesChanged: { workspaces: start } }))
assert.deepStrictEqual(state, start)
assert.strictEqual(N.activeOn(state, "eDP-1"), 1)
assert.strictEqual(N.activeOn(state, "HDMI-A-1"), 1)
assert.deepStrictEqual(N.occupiedOn(state, "eDP-1"), [1, 2])
assert.deepStrictEqual(N.occupiedOn(state, "HDMI-A-1"), [])
console.log("ok  the full list sets active and occupied per output")

// 2. activating a workspace moves only its own output, focus moves everywhere
const activated = N.applyEvent(state, line({ WorkspaceActivated: { id: 12, focused: true } }))
assert.strictEqual(N.activeOn(activated, "eDP-1"), 3)
assert.strictEqual(N.activeOn(activated, "HDMI-A-1"), 1, "the other output keeps its active workspace")
assert.strictEqual(activated.find(w => w.id === 12).is_focused, true)
assert.strictEqual(activated.find(w => w.id === 10).is_focused, false)
assert.strictEqual(state.find(w => w.id === 10).is_active, true, "the old list is not changed in place")
console.log("ok  activate moves only its own output")

// 3. activating without focus leaves focus where it was
const unfocused = N.applyEvent(state, line({ WorkspaceActivated: { id: 20, focused: false } }))
assert.strictEqual(unfocused.find(w => w.id === 10).is_focused, true)
console.log("ok  activate without focus keeps the focused workspace")

// 4. windows opening and the last one closing
let windows = N.applyEvent(state, line({ WorkspaceActiveWindowChanged: { workspace_id: 12, active_window_id: 9 } }))
assert.deepStrictEqual(N.occupiedOn(windows, "eDP-1"), [1, 2, 3])
windows = N.applyEvent(windows, line({ WorkspaceActiveWindowChanged: { workspace_id: 11, active_window_id: null } }))
assert.deepStrictEqual(N.occupiedOn(windows, "eDP-1"), [1, 3])
console.log("ok  occupied follows the active window")

// 5. events about workspaces that are not known change nothing
assert.strictEqual(N.applyEvent(state, line({ WorkspaceActivated: { id: 99, focused: true } })), null)
assert.strictEqual(N.applyEvent(state, line({ WorkspaceActiveWindowChanged: { workspace_id: 99, active_window_id: 1 } })), null)
console.log("ok  unknown workspace ids are ignored")

// 6. events the badges do not use change nothing
assert.strictEqual(N.applyEvent(state, line({ WindowsChanged: { windows: [] } })), null)
assert.strictEqual(N.applyEvent(state, line({ WorkspacesChanged: { workspaces: "nope" } })), null)
assert.strictEqual(N.applyEvent(state, line({ Ok: "Handled" })), null)
console.log("ok  unused events change nothing")

// 6b. parse survives empty input and garbage
assert.strictEqual(N.parse(""), null)
assert.strictEqual(N.parse("   "), null)
assert.strictEqual(N.parse("null"), null)
assert.strictEqual(N.parse("42"), null)
assert.strictEqual(N.parse("{not json"), null)
assert.deepStrictEqual(N.parse('{"Ok":"Handled"}'), { Ok: "Handled" })
console.log("ok  parse turns empty lines and garbage into null")

// 7. an output niri has not reported falls back to workspace 1, nothing occupied
assert.strictEqual(N.activeOn(state, "DP-3"), 1)
assert.deepStrictEqual(N.occupiedOn([], "eDP-1"), [])
console.log("ok  an unknown output falls back to 1")

// 8. a badge click finds niri's id for that number on that output
assert.strictEqual(N.idOf(state, "eDP-1", 2), 11)
assert.strictEqual(N.idOf(state, "HDMI-A-1", 1), 20, "the same number on another output is another workspace")
assert.strictEqual(N.idOf(state, "eDP-1", 5), 12, "a number niri does not have goes to the last workspace")
assert.strictEqual(N.idOf(state, "DP-3", 1), null, "an unknown output has no id")
assert.strictEqual(N.idOf([], "eDP-1", 1), null)
console.log("ok  idOf maps a badge number to niri's id")
