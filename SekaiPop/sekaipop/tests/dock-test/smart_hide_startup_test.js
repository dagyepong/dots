// Smart hide at start-up: the dock must stay away until Hyprland's window list is back,
// and must not give up after the 0.6 s the slide animations take to switch on.
// The QML can't be run here, so the rules are read from source. Run: node smart_hide_startup_test.js
const fs = require('fs'), assert = require('assert')
const D = fs.readFileSync(__dirname + '/../../modules/sekai/dock/Dock.qml', 'utf8')
const S = fs.readFileSync(__dirname + '/../../services/DockService.qml', 'utf8')
assert.ok(/readonly property bool smartWaiting: dockWindow\.smartOn && !DockService\.ready && !dockWindow\.startupDone/.test(D), 'smartWaiting waits for the list, not for animReady')
assert.ok(!/smartWaiting:[^\n]*animReady/.test(D), 'smartWaiting no longer ends with the animation timer')
assert.ok(/readonly property int startupMs: 5000/.test(D) && /onTriggered: dockWindow\.startupDone = true/.test(D), 'a Hyprland that never answers does not hide the dock for good')
assert.ok(/onReadyChanged\(\)[\s\S]*?dockWindow\.startupDone = true/.test(D), 'the wait ends when the list arrives')
assert.ok(/if \(DockService\.ready\)\s*dockWindow\.startupDone = true/.test(D), 'a dock built later finds the list already there')
assert.ok(/interval: 400\s*repeat: true\s*running: root\.wanted && !root\.ready\s*onTriggered: root\.refresh\(\)/.test(S), 'the window list is asked again until it has come back')
assert.ok(/wantsHidden: dockWindow\.hideMode === "auto" \|\| dockWindow\.smartCovered \|\| dockWindow\.smartWaiting/.test(D), 'waiting counts as hidden')
console.log('smart_hide_startup_test: all checks passed')
