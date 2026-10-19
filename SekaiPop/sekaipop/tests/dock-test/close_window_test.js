// Closing a window from the dock (the X on a preview tile, "Close window" / "Close all windows"
// in a key's menu): the address handed to Hyprland must be "0x...". Quickshell's toplevel
// address can come without the prefix, and a dispatch with a bare address finds no window.
// The QML can't be run here, so the rules are read from source. Run: node close_window_test.js
const fs = require('fs'), assert = require('assert')
const D = fs.readFileSync(__dirname + '/../../modules/sekai/dock/Dock.qml', 'utf8')
const S = fs.readFileSync(__dirname + '/../../services/DockService.qml', 'utf8')

// the helper itself, cut out of the .qml and run
const m = S.match(/function hexAddr\(address\) \{[\s\S]*?\n    \}\n/)
assert.ok(m, 'DockService.hexAddr exists')
const hexAddr = new Function('root', 'return (' + m[0].replace('function hexAddr', 'function') + ')')({})
assert.strictEqual(hexAddr('55d0c0a1b2c0'), '0x55d0c0a1b2c0', 'a bare address gets its 0x')
assert.strictEqual(hexAddr('0x55d0c0a1b2c0'), '0x55d0c0a1b2c0', 'a prefixed one is left alone')
assert.strictEqual(hexAddr(''), '', 'nothing stays nothing')
assert.strictEqual(hexAddr(undefined), '', 'undefined stays nothing')
assert.strictEqual(hexAddr(null), '', 'null stays nothing')

// every dispatch that names a window goes through it
const close = D.match(/function closeWin\(rawAddress\) \{[\s\S]*?\n    \}\n/)
assert.ok(close && /DockService\.hexAddr\(rawAddress\)/.test(close[0]), 'closeWin normalizes the address')
assert.ok(/address:" \+ address/.test(close[0]) && /closewindow address:" \+ address/.test(close[0]), 'both dispatch forms use the normalized one')
assert.ok(/function moveTo\(rawAddress, workspace\) \{\s*const address = root\.hexAddr\(rawAddress\)/.test(S), 'moveTo normalizes')
assert.ok(/function focusAddress\(rawAddress, workspace\) \{\s*const address = root\.hexAddr\(rawAddress\)/.test(S), 'focusAddress normalizes')
// the X on a tile and the menu row both end in closeWin
assert.ok(/onCloseRequested: dockWindow\.closeWin\(tile\.modelData\)/.test(D), 'the tile X calls closeWin')
assert.ok(/function closeAll\(info\)[\s\S]*?dockWindow\.closeWin\(w\.address\)/.test(D), 'Close all windows calls closeWin')
console.log('close_window_test: all checks passed')
