// Edit Desktop's DOCK tab has a TOOLS group: one key per dock tool, lit while the tool is
// on the dock, a click turns it on / off. The QML can't be run here, so the wiring is read
// from source. Run: node edit_tools_test.js
const fs = require('fs'), assert = require('assert')
const B = fs.readFileSync(__dirname + '/../../modules/sekai/editMode/EditDockBoard.qml', 'utf8')
const P = fs.readFileSync(__dirname + '/../../services/PinnedAppsService.qml', 'utf8')
const D = fs.readFileSync(__dirname + '/../../modules/sekai/dock/Dock.qml', 'utf8')

const ids = (P.match(/readonly property var toolIds: \[([^\]]*)\]/) || [])[1]
assert.ok(ids, 'PinnedAppsService lists its tools')
const tools = ids.split(',').map(s => s.trim().replace(/"/g, ''))
assert.deepStrictEqual(tools, ['search', 'files', 'clipboard', 'shelf', 'timer'], 'the five tools')

for (const t of tools) {
    assert.ok(new RegExp('id: "' + t + '", label: "[^"]+", icon: "[^"]+"').test(B), 'TOOLS has a key for ' + t)
    assert.ok(new RegExp(t + ': \\{ label: "[^"]+", icon: "[^"]+" \\}').test(D), 'the dock draws ' + t)
}
// the icon on the board matches the icon on the dock key
for (const t of tools) {
    const b = B.match(new RegExp('id: "' + t + '", label: "[^"]+", icon: "([^"]+)"'))[1]
    const d = D.match(new RegExp(t + ': \\{ label: "[^"]+", icon: "([^"]+)" \\}'))[1]
    assert.strictEqual(b, d, t + ' uses the same icon on the board and on the dock')
}
assert.ok(/on: PinnedAppsService\.hasTool\(modelData\.id\)/.test(B), 'a key is lit while its tool is on the dock')
assert.ok(/onPicked: PinnedAppsService\.toggleTool\(modelData\.id\)/.test(B), 'a click toggles the tool')
assert.ok(/title: "TOOLS"/.test(B), 'the group has its heading')
assert.ok(/Flow \{\s*id: groups/.test(B) && !/Flickable/.test(B), 'the groups wrap onto a second line when the shelf is narrow, nothing is cut off')

// The Shelf's card stays open on a click outside; its header X closes it.
const SH = fs.readFileSync(__dirname + '/../../modules/sekai/dock/DockShelfCard.qml', 'utf8')
assert.ok(/active: dockWindow\.menuOpen \|\| dockWindow\.folderOpen\s*\|\| \(dockWindow\.toolOpen !== "" && dockWindow\.toolOpen !== "shelf"\)/.test(D), 'the focus grab is not on for the shelf')
assert.ok(/if \(dockWindow\.toolOpen !== "shelf"\)\s*dockWindow\.toolOpen = ""/.test(D), 'a click outside does not close the shelf')
assert.ok(/icon: "close"[\s\S]*?onClicked: root\.closeRequested\(\)/.test(SH), 'the shelf card has an X that closes it')
assert.ok(/shelfCard[\s\S]*?onCloseRequested: dockWindow\.toolOpen = ""/.test(D), 'the X closes the card')

// Drag and drop on the Shelf.
const SS = fs.readFileSync(__dirname + '/../../services/ShelfService.qml', 'utf8')
assert.ok(/DropArea \{\s*id: cardDrop[\s\S]*?ShelfService\.addDrop\(drop\)/.test(SH), 'files can be dropped on the open card')
assert.ok(/id: hotDrop/.test(D) && /\|\| dockWindow\.dragOver/.test(D), 'a drag at the edge brings a hidden dock back')
assert.ok(/hotDrop\.containsDrag \|\| dockWindow\.dragKey \|\| shelfCard\.dropping/.test(D), 'the key, the edge and the card all count as a drag over the dock')
assert.ok(!/drop\.accept\(\)/.test(D + SH), 'drops are accepted as a copy, never a move')
assert.ok(/dockWindow\.toolOpen === "shelf"\) \? WlrLayer\.Top/.test(D), 'the open Shelf card is not behind windows')
assert.ok(/addText\(String\(u\)\)/.test(SS), 'a dragged web link is kept as text, not as a file path')

// The Timer key's fill in the Capsule style stays inside the circle.
assert.ok(/import QtQuick\.Shapes/.test(D), 'Dock.qml can draw a shape')
assert.ok(/id: capFill[\s\S]*?visible: toolPill\.timing && dockWindow\.capKeys/.test(D), 'a circular fill for the capsule keys')
assert.ok(/visible: toolPill\.timing && !dockWindow\.capKeys/.test(D), 'the rising bar is only for Float / Transparent')
{
    // the arc maths: p = 0.5 is a half circle, p = 1 the whole circle, and the level rises with p like the old bar did
    const phi = p => Math.acos(1 - 2 * p) * 180 / Math.PI
    assert.ok(Math.abs(phi(0.5) - 90) < 1e-9 && Math.abs(phi(1) - 180) < 1e-9 && phi(0) === 0, 'arc angle at 0, half and full')
    for (const p of [0.1, 0.25, 0.5, 0.8]) {
        const f = phi(p) * Math.PI / 180        // half angle, radians
        // height of the segment from the bottom = 1 - cos(f) (r = 1); level line is at 2p of the diameter
        assert.ok(Math.abs((1 - Math.cos(f)) - 2 * p) < 1e-9, 'its height is p of the key')
    }
}
console.log('edit_tools_test: all checks passed')
