// Rules of the Custom Image widget's maths, one by one. Run: node image_unit.js
const fs = require('fs'), assert = require('assert')
const src = fs.readFileSync(__dirname + '/../../modules/common/functions/ImageMath.js', 'utf8').replace('.pragma library', '')
const M = {}
new Function('M', src + ';Object.assign(M,{clamp,normalize,defaults,initialSize,shapeRect,drawRect,panBy,resize,originalRatio,keepOn,decodeSide,cascade,emptyFrame,localPath,isPicture,sortDrop,MIN_SIDE,MAX_ZOOM,EMPTY_W,EMPTY_H,PICTURE_EXTS});')(M)
const near = (a, b, m) => assert.ok(Math.abs(a - b) < 1e-6, (m || '') + ': ' + a + ' vs ' + b)

// 1. normalize: junk in, drawable record out
assert.strictEqual(M.normalize(null), null)
assert.strictEqual(M.normalize({ id: 'a' }), null)
assert.strictEqual(M.normalize({ id: 'a', path: 5 }), null)
// a path of '' is an EMPTY frame (a drop target), and it survives a round trip
const empty0 = M.normalize({ id: 'e', path: '', w: 320, h: 240 })
assert.strictEqual(empty0.path, ''); assert.strictEqual(empty0.w, 320); assert.deepStrictEqual(M.normalize(empty0), empty0)
assert.strictEqual(M.normalize({ path: '' }).path, '')
let n = M.normalize({ id: 'a', path: '/x.png', mode: 'banana', roundness: 9, opacity: -3, zoom: 99, panX: 5, borderColor: 'red', shadowKind: 'x', borderWidth: 500, w: -4, lockAspect: undefined })
assert.strictEqual(n.mode, 'fit'); assert.strictEqual(n.roundness, 1); assert.strictEqual(n.opacity, 0.05)
assert.strictEqual(n.zoom, M.MAX_ZOOM); assert.strictEqual(n.panX, 1); assert.strictEqual(n.borderColor, 'white')
assert.strictEqual(n.shadowKind, 'soft'); assert.strictEqual(n.borderWidth, 24); assert.strictEqual(n.w, 0)
assert.strictEqual(n.lockAspect, true); assert.strictEqual(n.borderOn, false)
assert.ok(M.normalize({ path: '/y.gif' }).id.length > 3)
const keep = M.normalize({ id: 'k', path: '/k.gif', mode: 'crop', zoom: 2.5, panX: -0.5, panY: 0.25, roundness: 0.5, borderOn: true, borderWidth: 8, borderColor: 'mint', shadowOn: true, shadowKind: 'hard', shadowDepth: 0.8, opacity: 0.6, lockAspect: false, x: 10, y: 20, w: 300, h: 200, scale: 1.5, screen: 'DP-1', nw: 600, nh: 400 })
assert.deepStrictEqual(M.normalize(keep), keep)
console.log('ok  normalize cleans, and keeps a good record exactly')

// 2. first size keeps the aspect ratio, caps big pictures, lifts tiny ones
let s = M.initialSize(4000, 2000, 1920, 1080)
near(s.w / s.h, 2, 'aspect'); assert.ok(Math.max(s.w, s.h) <= 432 + 1)
s = M.initialSize(32, 32, 1920, 1080); assert.strictEqual(s.w, 160)
s = M.initialSize(0, 0, 1920, 1080); assert.deepStrictEqual(s, { w: 240, h: 240 })
console.log('ok  initial size')

// 3. shape: FIT wraps the picture, FILL / CROP the whole frame
let r = M.shapeRect(400, 400, 200, 100, 'fit')
near(r.w, 400); near(r.h, 200); near(r.x, 0); near(r.y, 100)
r = M.shapeRect(400, 400, 200, 100, 'fill'); assert.deepStrictEqual(r, { x: 0, y: 0, w: 400, h: 400 })
r = M.shapeRect(400, 400, 0, 0, 'fit'); assert.deepStrictEqual(r, { x: 0, y: 0, w: 400, h: 400 })
console.log('ok  shape rectangle')

// 4. draw: cover, centred; crop zoom + pan reach every edge and never leave a gap
r = M.drawRect(400, 400, 200, 100, 'fill', 1, 0, 0)
near(r.h, 400); near(r.w, 800); near(r.x, -200); near(r.y, 0)
for (const [px, py] of [[-1, -1], [0, 0], [1, 1], [0.3, -0.7]]) {
    for (const z of [1, 1.7, 6]) {
        r = M.drawRect(300, 200, 640, 480, 'crop', z, px, py)
        assert.ok(r.x <= 1e-6 && r.y <= 1e-6 && r.x + r.w >= 300 - 1e-6 && r.y + r.h >= 200 - 1e-6, 'gap at ' + [px, py, z])
    }
}
r = M.drawRect(300, 200, 640, 480, 'crop', 2, -1, -1); near(r.x, 0); near(r.y, 0)
r = M.drawRect(300, 200, 640, 480, 'crop', 2, 1, 1); near(r.x + r.w, 300); near(r.y + r.h, 200)
r = M.drawRect(300, 200, 640, 480, 'fit', 3, 1, 1); assert.deepStrictEqual(r, { x: 0, y: 0, w: 300, h: 200 })
console.log('ok  cover / crop never leave a gap')

// 5. panning: the picture follows the pointer, clamped, and a picture with no overflow doesn't pan
let p = M.panBy(300, 200, 640, 480, 2, 0, 0, 30, 0)
assert.ok(p.panX < 0 && p.panY === 0)
r = M.drawRect(300, 200, 640, 480, 'crop', 2, p.panX, p.panY)
near(r.x, M.drawRect(300, 200, 640, 480, 'crop', 2, 0, 0).x + 30, 'moved exactly by the drag')
p = M.panBy(300, 200, 640, 480, 2, 0, 0, 99999, -99999); assert.strictEqual(p.panX, -1); assert.strictEqual(p.panY, 1)
p = M.panBy(300, 300, 100, 100, 1, 0.4, 0.4, 50, 50); assert.deepStrictEqual(p, { panX: 0, panY: 0 })
console.log('ok  panning')

// 6. resize, aspect locked: the opposite corner stays, the ratio is exact
const st = { x: 200, y: 200, w: 300, h: 200 }, room = { roomW: 1920, roomH: 1080 }
for (const c of ['se', 'sw', 'ne', 'nw']) {
    r = M.resize(st, c, c.includes('e') ? 90 : -90, c.includes('s') ? 60 : -60, { lock: true, ...room })
    near(r.w / r.h, 1.5, c + ' ratio'); assert.ok(r.w > 300)
    const ax = c.includes('e') ? st.x : st.x + st.w, ay = c.includes('s') ? st.y : st.y + st.h
    near(c.includes('e') ? r.x : r.x + r.w, ax, c + ' anchor x'); near(c.includes('s') ? r.y : r.y + r.h, ay, c + ' anchor y')
}
r = M.resize(st, 'se', -5000, -5000, { lock: true, ...room }); near(r.w / r.h, 1.5); assert.ok(r.h >= M.MIN_SIDE - 1e-6 && r.w >= M.MIN_SIDE)
r = M.resize(st, 'se', 9000, 9000, { lock: true, ...room }); assert.ok(r.x + r.w <= 1920 + 1e-6 && r.y + r.h <= 1080 + 1e-6); near(r.w / r.h, 1.5)
r = M.resize(st, 'nw', -9000, -9000, { lock: true, ...room }); assert.ok(r.x >= -1e-6 && r.y >= -1e-6); near(r.w / r.h, 1.5)
r = M.resize(st, 'se', 100, 0, { lock: true, aspect: 1, ...room }); near(r.w / r.h, 1, 'explicit aspect')
console.log('ok  locked resize')

// 7. resize, free: each side moves alone, and stays on screen / above the minimum
r = M.resize(st, 'se', 100, -50, { lock: false, ...room }); near(r.w, 400); near(r.h, 150); near(r.x, 200); near(r.y, 200)
r = M.resize(st, 'nw', -100, 40, { lock: false, ...room }); near(r.w, 400); near(r.h, 160); near(r.x, 100); near(r.y, 240)
r = M.resize(st, 'se', -9999, 9999, { lock: false, ...room }); near(r.w, M.MIN_SIDE); near(r.y + r.h, 1080)
console.log('ok  free resize')

// 8. original ratio, staying on screen
r = M.originalRatio({ x: 0, y: 900, w: 400, h: 400 }, 800, 400, 1920, 1080); near(r.w / r.h, 2); assert.ok(r.y + r.h <= 1080 + 1e-6)
r = M.originalRatio({ x: 0, y: 0, w: 300, h: 300 }, 0, 0, 1920, 1080); assert.deepStrictEqual(r, { x: 0, y: 0, w: 300, h: 300 })
console.log('ok  original ratio')

// 9. keepOn, decodeSide, cascade
assert.deepStrictEqual(M.keepOn(-50, 2000, 300, 200, 1920, 1080), { x: 0, y: 880 })
assert.deepStrictEqual(M.keepOn(5, 5, 3000, 3000, 1920, 1080), { x: 0, y: 0 })
assert.strictEqual(M.decodeSide(300, 200, 1, 1), 512); assert.strictEqual(M.decodeSide(300, 200, 1, 1) % 256, 0)
assert.strictEqual(M.decodeSide(5000, 5000, 2, 6), 4096); assert.strictEqual(M.decodeSide(1, 1, 1, 1), 256)
assert.strictEqual(M.decodeSide(300, 200, 1, 1), M.decodeSide(310, 200, 1, 1), 'a small resize does not change the decode size')
assert.deepStrictEqual(M.cascade(100, 100, 300, 200, 1920, 1080), { x: 128, y: 128 })
console.log('ok  keepOn / decodeSide / cascade')

// 9b. empty frames: made at once with a size of their own, so they can be seen and dropped on
let e = M.emptyFrame('e1', 'DP-1', 1920, 1080)
assert.strictEqual(e.path, ''); assert.strictEqual(e.screen, 'DP-1'); assert.strictEqual(e.id, 'e1')
assert.strictEqual(e.w, M.EMPTY_W); assert.strictEqual(e.h, M.EMPTY_H); assert.ok(e.x === -1 && e.y === -1, 'never placed: the middle of the screen')
e = M.emptyFrame('e2', '', 600, 300); assert.ok(e.h <= 150 + 1 && e.w / e.h > 1.3 && e.w / e.h < 1.4, 'a small screen: smaller frame, same shape')
e = M.emptyFrame('e3', '', 0, 0); assert.strictEqual(e.w, M.EMPTY_W, 'unknown screen size: the normal size')
console.log('ok  empty frames')

// 9c. what a drop carries
assert.strictEqual(M.localPath('file:///home/me/My%20Pics/a%C3%A9.png'), '/home/me/My Pics/aé.png')
assert.strictEqual(M.localPath('file://localhost/tmp/x.gif'), '/tmp/x.gif')
assert.strictEqual(M.localPath('/already/a/path.png'), '/already/a/path.png')
assert.strictEqual(M.localPath('https://example.com/a.png'), ''); assert.strictEqual(M.localPath(''), ''); assert.strictEqual(M.localPath(undefined), '')
assert.strictEqual(M.localPath('file:///bad%E0%A4%A'), '', 'a broken escape is not a path')
assert.ok(M.isPicture('/a/b.PNG') && M.isPicture('x.webp') && M.isPicture('/a b/c.d.gif') && M.isPicture('v.apng') && M.isPicture('i.svg'))
assert.ok(!M.isPicture('/a.b/noext') && !M.isPicture('x.txt') && !M.isPicture('.png/') && !M.isPicture('') && !M.isPicture(null))
let d = M.sortDrop(['file:///a/1.png', 'file:///a/1.png', 'file:///a/2.txt', 'https://q/a.png', 'file:///a/3.GIF'], '')
assert.deepStrictEqual(d, { files: ['/a/1.png', '/a/3.GIF'], skipped: 2 }, 'order kept, repeats dropped, non-pictures counted')
d = M.sortDrop([], '# a comment\r\nfile:///a/x.gif\r\n/b/y.jpg\r\n\r\nhello')
assert.deepStrictEqual(d, { files: ['/a/x.gif', '/b/y.jpg'], skipped: 1 }, 'paths sent only as text work too')
d = M.sortDrop(['file:///a/1.png'], 'ignored text'); assert.deepStrictEqual(d.files, ['/a/1.png'], 'urls win over text')
assert.deepStrictEqual(M.sortDrop([], ''), { files: [], skipped: 0 })
assert.deepStrictEqual(M.sortDrop(null, null), { files: [], skipped: 0 })
console.log('ok  drops are sorted into pictures and the rest')

console.log('image_unit: all checks passed')

// 10. The QML can't be run here, so the wiring is read from source: each rule that a
// mistake would silently break (a picture you can't click through to, a drag fighting
// a resize, a GIF that never stops) is checked as text.
const loc = require('../lib/locate')
const W = fs.readFileSync(loc('ImageWidget.qml'), 'utf8'), I = fs.readFileSync(loc('ImageInspector.qml'), 'utf8')
const S = fs.readFileSync(loc('ImageService.qml'), 'utf8'), shell = fs.readFileSync(__dirname + '/../../shell.qml', 'utf8')
const EM = fs.readFileSync(loc('EditMode.qml'), 'utf8')
assert.ok(/mask: Region \{\s*item: cardMask\s*Region \{\s*item: inspMask/.test(W), 'the input mask must be the frame AND the panel')
assert.ok(/id: follow[\s\S]*?dragArea\.drag\.active[\s\S]*?chrome\.dragging[\s\S]*?win\.sizing[\s\S]*?win\.place\(\)/.test(W), 'follow must not re-place during a drag or a resize')
assert.ok(/playing: win\.live/.test(W), 'an animated picture plays only while shown')
assert.ok(/AnimatedImage/.test(W) && /gif\|apng\|webp/.test(W), 'GIF / APNG / WebP use AnimatedImage')
assert.ok(/autoTransform: true/.test(W), 'phone photos are turned upright')
assert.ok(/IM\.resize\(/.test(W) && /ShiftModifier/.test(W) && /IM\.panBy\(/.test(W) && /IM\.shapeRect\(/.test(W) && /IM\.drawRect\(/.test(W))
assert.ok(/WlrLayershell\.keyboardFocus: WlrKeyboardFocus\.None/.test(W))
assert.ok(/ImageService\.setGeometry\(/.test(W), 'drops and resizes are saved')
assert.ok(/id: chrome[\s\S]*?widgetId: win\.widgetId[\s\S]*?onRemoveRequested: ImageService\.remove/.test(W))
for (const f of ['duplicate', 'remove']) assert.ok(new RegExp('ImageService\\.' + f + '\\(root\\.imageId\\)').test(I), 'inspector ' + f)
for (const k of ['mode', 'roundness', 'opacity', 'borderOn', 'borderWidth', 'borderColor', 'shadowOn', 'shadowKind', 'shadowDepth', 'lockAspect']) assert.ok(I.includes(k), 'inspector edits ' + k)
assert.ok(/ids: \[\]/.test(S) && /root\.ids = list\.map/.test(S) && /structural/.test(S), 'ids change only when a picture is added or removed')
assert.ok(/forgetQueue/.test(S) && /another picture still uses this file/.test(S), 'a shared file is deleted only with its last picture')
assert.ok(/Variants \{\s*model: ImageService\.ids/.test(shell) && /target: "image"/.test(shell))
assert.ok(/id: "image"/.test(EM) && /indexOf\("image:"\)/.test(EM))
assert.ok(/picPad/.test(W) && /id: picLayer[\s\S]*?anchors\.margins: win\.picPad/.test(W) && /id: picMask[\s\S]*?anchors\.margins: win\.picPad/.test(W), 'the picture and its mask sit inside the stroke')
assert.ok(/IM\.drawRect\(win\.innerW, win\.innerH/.test(W) && /IM\.panBy\(win\.innerW, win\.innerH/.test(W), 'drawing and panning use the inner area')
// -- an empty frame is on the desktop at once, and takes dropped files --
const SH = fs.readFileSync(loc('pick-custom-image.sh'), 'utf8'), SET = fs.readFileSync(loc('SettingsPageDesktop.qml'), 'utf8')
const addImage = EM.slice(EM.indexOf('} else if (id === "image") {'), EM.indexOf('} else if (id === "notes") {'))
assert.ok(/ImageService\.addEmpty\(here\)/.test(addImage) && !/ImageService\.pick\(/.test(addImage), 'the shelf tile adds an empty frame, it does not open a chooser first')
assert.ok(/function addEmpty\(screen(?:, px, py)?\)[\s\S]*?IM\.emptyFrame\([\s\S]*?root\.commit\(root\.items\.concat\(\[r\]\), true\)[\s\S]*?root\.saveNow\(\)[\s\S]*?EditMode\.select\(/.test(S), 'addEmpty: made, saved, selected')
assert.ok(/function forget\(path\) \{\s*if \(path === ""\)\s*return/.test(S), 'an empty frame has no file to delete')
assert.ok(/function drop\(id, urls, text\)[\s\S]*?IM\.sortDrop\(/.test(S) && /function reject\(/.test(S), 'drops are sorted, and a bad one is reported')
assert.ok(/property var importQueue/.test(S) && /importer\.waiting/.test(S) && /function pumpImport/.test(S), 'imports are queued, one answer per job')
assert.ok(/function addPath\([\s\S]*?root\.enqueue\(/.test(S), 'ipc addPath goes through the same queue')
assert.ok(/function landed\(job, path\)[\s\S]*?root\.replacePath\(job\.target, path\)/.test(S), 'the first dropped picture goes into the frame it was dropped on')
assert.ok(/readonly property bool empty: win\.rec !== null && win\.path === ""/.test(W), 'an empty frame is its own state')
assert.ok(/readonly property bool failed: win\.path !== "" && /.test(W), 'an empty frame is not a broken picture')
assert.ok(/DropArea \{\s*id: drops[\s\S]*?ImageService\.drop\(win\.imageId, urls[\s\S]*?drop\.accept\(\)/.test(W), 'the frame is a drop target')
assert.ok(/drag\.accepted = drag\.hasUrls \|\| drag\.hasText/.test(W), 'file drags are accepted when they enter')
assert.ok(!/BROWSE|browseKey|ImageService\.replace\(|ImageService\.pick\(/.test(W + I + S + shell), 'no file chooser: pictures come in by drag and drop only')
assert.ok(!/function (pick|replace)\(|id: picker/.test(S), 'the service has no chooser')
assert.ok(/onRejectTickChanged\(\)[\s\S]*?ImageService\.rejectId === win\.imageId/.test(W), 'only the frame that was dropped on flashes')
assert.ok(/function add\(\): void \{ ImageService\.addEmpty\(""\) \}/.test(shell), 'ipc: image add')
assert.ok(/ImageService\.addEmpty\(/.test(SET) && !/ImageService\.pick\(/.test(SET), 'Settings adds an empty frame too')
const shExts = (SH.match(/^exts="([^"]*)"/m) || [])[1].split(' ').sort().join(',')
assert.strictEqual(shExts, M.PICTURE_EXTS.slice().sort().join(','), 'the script and ImageMath accept the same picture types')
// -- the desktop menu has no Pin image, and a picture is never drawn squeezed into the old frame --
const DM = fs.readFileSync(loc('DesktopMenu.qml'), 'utf8')
assert.ok(!/text: "Pin image"/.test(DM) && !/ImageService\.addEmpty\(/.test(DM), 'the desktop menu has no "Pin image": pictures are added from Edit Desktop only')
assert.ok(/function addEmpty\(screen, px, py\)[\s\S]*?IM\.keepOn\(px \/ k - r\.w \/ 2, py \/ k - r\.h \/ 2, r\.w, r\.h, room\.w, room\.h\)/.test(S), 'a pinned frame is centred on the pointer and kept on the screen')
assert.ok(/readonly property real picW: win\.natW > 0 \? win\.natW/.test(W) && /IM\.shapeRect\(win\.frameW, win\.frameH, win\.picW, win\.picH, win\.mode\)/.test(W), 'the shape follows the loaded picture\'s ratio before the record has learned it')
assert.ok(/onNatWChanged: Qt\.callLater\(win\.report\)/.test(W) && /onReframingChanged: Qt\.callLater\(win\.report\)/.test(W), 'a picture put into a frame is reported even when its loading status does not change')
assert.ok(/String\(p\.source\) !== String\(win\.srcUrl\)/.test(W), 'only the picture of the current file is reported')
console.log('ok  menu has no pin image; ratio wiring')

console.log('ok  QML wiring read from source')
// -- pinned: in front of windows and games, click-through, off for anything saved before it --
assert.strictEqual(M.defaults('p', '/p.png').pinned, false, 'a new frame is not pinned')
assert.strictEqual(M.normalize({ id: 'o', path: '/old.png' }).pinned, false, 'a record from before pinning is not pinned')
assert.strictEqual(M.normalize({ id: 'o', path: '/old.png', pinned: 'yes' }).pinned, false, 'only true pins')
assert.strictEqual(M.normalize({ id: 'o', path: '/old.png', pinned: true }).pinned, true)
const pinnedRec = M.normalize({ id: 'q', path: '/q.png', pinned: true, x: 5, y: 6, w: 100, h: 80 })
assert.deepStrictEqual(M.normalize(pinnedRec), pinnedRec, 'a pinned record survives a round trip')
assert.ok(/readonly property bool onTop: win\.pinned && !win\.empty && !EditMode\.active/.test(W), 'pinned means in front, but not while Edit Desktop is open and not for an empty frame')
assert.ok(/WlrLayershell\.layer: win\.onTop \? WlrLayer\.Overlay/.test(W), 'a pinned picture is on the Overlay layer')
assert.ok(/readonly property bool want: win\.switchedOn && \(gate\.show \|\| win\.onTop\)/.test(W), 'Focus Mode / Game Mode do not hide a pinned picture')
assert.ok(/readonly property bool none: !win\.live \|\| win\.onTop/.test(W) && /width: cardMask\.none \? 1/.test(W), 'a pinned picture takes no clicks')
assert.ok(/\(!EditMode\.desktopDragAllowed \|\| win\.onTop\)/.test(W), 'a pinned picture never needs the whole screen')
assert.ok(/id: pinArea[\s\S]*?acceptedButtons: Qt\.RightButton[\s\S]*?enabled: !EditMode\.active && !win\.pinned && !win\.empty[\s\S]*?ImageService\.setPinned\(win\.imageId, true\)/.test(W), 'right-click pins, but not while editing (there it removes) and not an empty frame')
assert.ok(/ImageService\.setPinned\(root\.imageId/.test(I), 'the panel can pin and unpin')
assert.ok(/function setPinned\(id, on\)[\s\S]*?r\.path === ""/.test(S) && /function setAllPinned\(on\)/.test(S) && /readonly property bool anyPinned/.test(S), 'service: pin one, pin all, any pinned; an empty frame is never pinned')
const DMENU = fs.readFileSync(loc('DesktopMenu.qml'), 'utf8')
assert.ok(/visible: ImageService\.anyPinned[\s\S]*?text: "Unpin images"[\s\S]*?ImageService\.setAllPinned\(false\)/.test(DMENU), 'the desktop menu can take every picture back')
assert.ok(/function pin\(\): void \{ ImageService\.setAllPinned\(true\) \}/.test(shell) && /function unpin\(\): void \{ ImageService\.setAllPinned\(false\) \}/.test(shell), 'ipc pin / unpin')
console.log('ok  pinned pictures: overlay layer, click-through, never on by default')

console.log('image_unit: wiring checks passed')
