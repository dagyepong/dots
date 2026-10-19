// The bar's popups on every edge, and the visualizer band hung from the top.
// The QML can't be run here, so the rules are checked as text, and the one piece of arithmetic
// (where a popup's top-left corner is, from its anchor and gravity) is checked by running it.
// Run: node popup_origin_test.js
const fs = require('fs'), assert = require('assert')
const read = f => fs.readFileSync(__dirname + '/../../' + f, 'utf8')
const SP = read('modules/sekai/bar/SekaiPopup.qml'), TP = read('modules/sekai/bar/TrayPopups.qml')
const VW = read('modules/sekai/visualizer/VisualizerWidget.qml')

// Edges as Quickshell has them (any distinct bit flags work for this check).
const Edges = { Top: 1, Bottom: 2, Left: 4, Right: 8 }
const gravityOf = pos => pos === 'left' ? (Edges.Bottom | Edges.Right)
    : pos === 'right' ? (Edges.Bottom | Edges.Left)
    : pos === 'bottom' ? (Edges.Top | Edges.Right) : (Edges.Bottom | Edges.Right)
const winLeft = (g, rectX, w) => rectX - ((g & Edges.Left) ? w : 0)
const winTop = (g, rectY, h) => rectY - ((g & Edges.Top) ? h : 0)

// A 1920x1080 screen, a 63 px strip, a 300x200 popup, the button 400 px along the bar.
const W = 1920, H = 1080, strip = 63, gap = 4, pw = 300, ph = 200
const cases = {
    top:    { rect: { x: 250, y: strip },       pill: { x: 400, y: strip / 2 } },
    bottom: { rect: { x: 250, y: H - strip },   pill: { x: 400, y: H - strip / 2 } },
    left:   { rect: { x: strip + gap, y: 300 }, pill: { x: strip / 2, y: 400 } },
    right:  { rect: { x: W - strip - gap, y: 300 }, pill: { x: W - strip / 2, y: 400 } },
}
for (const [pos, c] of Object.entries(cases)) {
    const g = gravityOf(pos)
    const l = winLeft(g, c.rect.x, pw), t = winTop(g, c.rect.y, ph)
    const ox = c.pill.x - l, oy = c.pill.y - t
    // the popup must lie on the far side of the bar from the pill, so its grow origin is
    // OUTSIDE the window, on the bar's side of it
    if (pos === 'top')    assert.ok(oy < 0 && t === strip, 'top: origin above the window')
    if (pos === 'bottom') assert.ok(oy > ph && t + ph === H - strip, 'bottom: origin below the window, not at its top')
    if (pos === 'left')   assert.ok(ox < 0 && l === strip + gap, 'left: origin left of the window')
    if (pos === 'right')  assert.ok(ox > pw && l + pw === W - strip - gap, 'right: origin right of the window, not at its left edge')
}
console.log('ok  popup corner and grow origin on all four edges')

// SekaiPopup and TrayPopups measure from the window's real corner, not anchor.rect
assert.ok(/readonly property real windowLeft: popup\.anchor\.rect\.x - \(\(host\.gravity & Edges\.Left\) \? popup\.implicitWidth : 0\)/.test(SP))
assert.ok(/readonly property real windowTop: popup\.anchor\.rect\.y - \(\(host\.gravity & Edges\.Top\) \? popup\.implicitHeight : 0\)/.test(SP))
assert.ok(/anchorCenterX - host\.windowLeft\) \/ host\.uiScale - host\.padL/.test(SP) && /anchorCenterY - host\.windowTop\) \/ host\.uiScale - host\.padT/.test(SP))
assert.ok(!/popup\.anchor\.rect\.[xy]\) \/ host\.uiScale/.test(SP), 'no origin measured from anchor.rect alone')
assert.ok(/root\.dropdownCenterX - root\.windowLeft\(popup\)/.test(TP) && /root\.dropdownCenterY - root\.windowTop\(popup\)/.test(TP))
assert.ok(/root\.windowLeft\(menuPopup\)\) \/ root\.uiScale - x/.test(TP) && /root\.windowTop\(menuPopup\)\) \/ root\.uiScale - y/.test(TP))
assert.ok(!/- popup\.anchor\.rect\.[xy]\) \/ root\.uiScale/.test(TP) && !/- menuPopup\.anchor\.rect\.[xy]\) \/ root\.uiScale/.test(TP))
console.log('ok  popups measure their origin from the window corner')

// a standing bar: the menu card (and the dropdown capsule) sit against the bar, not centred in the wide window
assert.ok(/x: root\.menuPadL \+ \(root\.parentWindow && root\.parentWindow\.vertical\s*\? \(root\.barEdge === "right" \? maxWidth - width : 0\)\s*: \(maxWidth - width\) \/ 2\)/.test(TP), 'menu card against the bar on a standing bar')
assert.ok(/x: root\.dropPadL \+ \(root\.parentWindow && root\.parentWindow\.vertical\s*\? \(root\.barEdge === "right" \? root\.windowW - width : 0\)\s*: \(root\.windowW - width\) \/ 2\)/.test(TP), 'dropdown capsule against the bar on a standing bar')
assert.ok(/padB: host\.barEdge === "bottom" \? 6 : host\.bleed/.test(SP), 'a bottom bar gets the same air a top bar has')
console.log('ok  standing bar: tray menu against the bar')

// visualizer: a band in the top half of the screen hangs upside down
assert.ok(/card\.topSide = win\.isBand && !win\.vertical && \(card\.y \+ card\.height \/ 2\) < win\.roomH \/ 2/.test(VW))
assert.ok(/yScale: win\.isBand && !win\.vertical && card\.topSide \? -1 : 1/.test(VW) && /origin\.y: flip\.height \/ 2/.test(VW))
assert.ok(/card\.topSide \? card\.height - btnRow\.height \+ 12 : -12/.test(VW), 'the corner buttons stay on screen under a top band')
assert.ok(/function updateSide\(\)[\s\S]*?topSide[\s\S]*?\}/.test(VW) && /win\.updateSide\(\)\s*win\.placed = true/.test(VW), 'decided when placed or dropped')
console.log('ok  visualizer band flips at the top')
console.log('popup_origin_test: all checks passed')
