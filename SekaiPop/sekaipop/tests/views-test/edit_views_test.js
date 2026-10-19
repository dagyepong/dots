// Edit Desktop's VIEWS tab (the sixth one) holds the Quick Panel phone's style and the overview's
// style / side / size. The QML can't be run here, so the wiring is read from source.
// Run: node edit_views_test.js
const fs = require('fs'), assert = require('assert')
const root = __dirname + '/../../'
const T = fs.readFileSync(root + 'modules/sekai/editMode/EditTray.qml', 'utf8')
const B = fs.readFileSync(root + 'modules/sekai/editMode/EditViewsBoard.qml', 'utf8')
const S = fs.readFileSync(root + 'services/SettingsService.qml', 'utf8')
const Q = fs.readFileSync(root + 'modules/sekai/settings/SettingsPageQuick.qml', 'utf8')
const H = fs.readFileSync(root + 'modules/sekai/settings/SettingsPageHyprland.qml', 'utf8')

// six tabs, three per row: the block is full
const keys = T.match(/TabKey \{\s*icon: "[^"]+"\s*label: "[^"]+"/g) || []
assert.strictEqual(keys.length, 6, 'six tab keys')
assert.deepStrictEqual(keys.map(k => k.match(/label: "([^"]+)"/)[1]),
    ['WIDGETS', 'BAR', 'DOCK', 'VIEWS', 'THEME', 'PRESETS'], 'the order of the tabs')
assert.ok(/columns: 3/.test(T), 'still three columns, so six keys make two full rows')
assert.ok(/onActivated: \{\s*EditMode\.select\(""\)\s*win\.tab = "views"/.test(T), 'the key opens the tab and lets go of the widget being edited')
assert.ok(/EditViewsBoard \{\s*visible: win\.tab === "views"/.test(T), 'the board shows on its tab only')
assert.ok(/win\.tab === "views"\s*\? "[^"]+"/.test(T), 'the heading has a subtitle for it')
assert.ok(/pickTab: win\.tab === "dock" \|\| win\.tab === "views"/.test(T), 'the hint rows read like the dock tab')

// the keys are the very switches Settings uses
const settingKeys = ['quick.flat', 'overview.style', 'overview.position', 'overview.workspaces']
for (const k of settingKeys) {
    assert.ok(S.includes('"' + k + '"'), k + ' is a real setting')
    assert.ok(B.includes('"' + k + '"'), 'the VIEWS board uses ' + k)
}
assert.ok(/set\("quick\.flat", modelData\.id === "flat"\)/.test(B) && /set\("quick\.flat", id === "flat"\)/.test(Q), 'phone: same write as Settings')
assert.ok(/set\("overview\.style", modelData\.id\)/.test(B) && /set\("overview\.style", id\)/.test(H), 'overview style: same write as Settings')
assert.ok(/set\("overview\.position", modelData\.id\)/.test(B) && /set\("overview\.position", id\)/.test(H), 'board side: same write as Settings')

// same option ids as Settings
for (const id of ['tilted', 'flat', 'board', 'scroll', 'left', 'center', 'right'])
    assert.ok(B.includes('id: "' + id + '"'), 'option ' + id)
assert.ok(/id: "tilted"[\s\S]*id: "flat"/.test(Q), 'Settings has the same two phone options')

// the board's own options hide while Scroll is picked, as in Settings
assert.strictEqual((B.match(/visible: !root\.scroll/g) || []).length, 2, 'board side and size hide under Scroll')
assert.ok(/visible: !overviewCard\.scroll/.test(H), 'Settings hides them too')

// the count is kept in 1 - 10 (what the Settings slider allows)
assert.ok(/from: 1\s*to: 10/.test(H), 'Settings allows 1 - 10')
const clamp = n => Math.max(1, Math.min(10, n))
assert.strictEqual(clamp(0), 1); assert.strictEqual(clamp(11), 10); assert.strictEqual(clamp(5), 5)
assert.ok(/Math\.max\(1, Math\.min\(10, n\)\)/.test(B), 'the stepper clamps to 1 - 10')

// every symbol the board names exists
for (const f of ['GameModeService', 'ScrollOverviewService'])
    assert.ok(fs.existsSync(root + 'services/' + f + '.qml'), f + ' exists')
assert.ok(/Flow \{\s*id: groups/.test(B) && !/Flickable/.test(B), 'groups wrap, nothing is cut off')
console.log('edit_views_test: all checks passed')

// The bar's workspace pills (same setting as Settings' slider) are on the VIEWS tab; the BAR tab keeps its original room.
{
    const L = fs.readFileSync(root + 'modules/sekai/editMode/EditBarLayout.qml', 'utf8')
    const SB = fs.readFileSync(root + 'modules/sekai/settings/SettingsPageBar.qml', 'utf8')
    assert.ok(S.includes('"bar.workspaceCount"') && /bar\.workspaceCount/.test(SB), 'the setting Settings uses')
    assert.ok(/set\("bar\.workspaceCount", Math\.max\(1, Math\.min\(10, n\)\)\)/.test(B), 'the stepper writes it, clamped to 1 - 10')
    assert.ok(/title: "BAR PILLS"/.test(B) && /setBarCount\(root\.barCount - 1\)/.test(B) && /setBarCount\(root\.barCount \+ 1\)/.test(B), 'a - and a + key')
    assert.ok(/title: "BOARD CARDS"/.test(B) && !/title: "WORKSPACES"/.test(B), 'the two counts have different names')
    assert.ok(/readonly property real ctlW: 244/.test(L) && !/WORKSPACES|workspaceCount/.test(L), 'the BAR tab is back to its original width, with nothing added')
}
console.log('bar pills checks passed')
