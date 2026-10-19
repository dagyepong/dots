// The dock's Shelf card is drawn as a real shelf (wall dots, tape, a plank with brackets).
// The QML can't be run here, so the wiring is read from source. Run: node shelf_look_test.js
const fs = require('fs'), assert = require('assert')
const root = __dirname + '/../../'
const C = fs.readFileSync(root + 'modules/sekai/dock/DockShelfCard.qml', 'utf8')
const D = fs.readFileSync(root + 'modules/sekai/dock/DockCard.qml', 'utf8')
const MJ = fs.readFileSync(root + 'modules/common/functions/ShelfMath.js', 'utf8')
const SM = new Function(MJ.replace('.pragma library', '') + '; return { seedOf, isImage, kindOf, iconOf, specOf, heightOf, restTilt, pack }')()
const SRV = fs.readFileSync(root + 'services/ShelfService.qml', 'utf8')
const face = n => fs.readFileSync(root + 'modules/sekai/dock/' + n + '.qml', 'utf8')

// the plank has room: the card grows by it, and it sits at the bottom of the content
assert.ok(/readonly property real ledgeBlock: 8 \+ root\.plankH/.test(C), 'the room the plank takes')
assert.ok(/\+ root\.ledgeBlock\s*\n/.test(C), 'contentHeight includes it')
assert.ok(/y: root\.areaH \+ 8/.test(C), 'each plank sits 8 px under its books\' area, which is where it sat at the bottom of the content')
// it stays inside the card: 16 px of padding under it hold the shadow and the brackets
const pad = +D.match(/readonly property real pad: (\d+)/)[1]
const plankH = +C.match(/readonly property real plankH: (\d+)/)[1]
const shadow = 4, bracketTip = plankH - 5 + 6 * Math.SQRT2 * 1 // centre at plankH+1, half-diagonal 8.5
assert.ok(plankH + 9.5 + 0 <= plankH + pad, 'the brackets fit in the padding under the plank')
assert.ok(shadow <= pad, 'so does the shadow')
// the plank overhangs the rows by 8 px a side and stays inside the card's padding
assert.ok(/fullW: root\.listW \+ 16/.test(C) && /x: root\.vpMargin - 8 \+/.test(C) && pad >= 8, 'the overhang stays inside the card')

// the look
assert.ok(/DotField \{[\s\S]*?corner: "tr"/.test(C), 'halftone wall')
assert.strictEqual((C.match(/WashiTape \{/g) || []).length, 2, 'two strips of tape')
assert.ok(/ScrapbookTheme\.tapeMint/.test(C) && /ScrapbookTheme\.tapePink/.test(C), 'the same two tapes as the Edit Desktop shelf')
assert.ok(/gradient: plankFill/.test(C) && /border\.color: Theme\.line/.test(C) && /color: Theme\.lineShadow/.test(C), 'accent gradient, navy outline, hard shadow')
assert.ok(/Math\.min\(1\.12, root\.shown\)/.test(C), 'the plank springs out with the pop')
assert.ok(/property real shown/.test(D), 'DockCard has `shown`')
// no model that is rebuilt while the plank grows
assert.ok(!/model: \[[^\]]*ledge\.width/.test(C) && !/model: \[[^\]]*board\.width/.test(C), 'no Repeater model that changes every frame')

// nothing about the behaviour changed
for (const t of ['ShelfService.addDrop(drop)', 'drop.accept(Qt.CopyAction)', 'ShelfService.addFromClipboard()', 'ShelfService.clear()',
    'root.closeRequested()', 'ShelfService.open(row.it)', 'ShelfService.revealInFolder(row.it)', 'ShelfService.remove(row.it.id)'])
    assert.ok(C.includes(t), t + ' is still there')
// What stands on the plank depends on what it is.
{
    const num = n => +C.match(new RegExp('readonly property (?:real|int) ' + n + ': (\\d+)'))[1]
    const bookMaxH = num('bookMaxH'), listW = num('listW'), gap = num('bookGap'), lift = num('lift')
    assert.ok(/readonly property real areaH: root\.bookMaxH \+ root\.lift/.test(C), 'the area: the tallest thing plus the slide-up')
    assert.ok(/root\.items\.length === 0 \? 44 : root\.nameH \+ 6 \+ root\.areaH/.test(C), 'the card is tall enough for the name line and the things')
    assert.ok(!/\browH\b/.test(C), 'no rows left')
    // every kind fits: no thing is taller than the area, none wider than the shelf
    const kinds = ['book', 'folder', 'video', 'image', 'audio', 'archive', 'note']
    for (const k of kinds) {
        const sp = SM.specOf(k)
        assert.ok(sp.w <= listW, k + ' fits the shelf')
        assert.ok(sp.hMax <= bookMaxH, k + ' is not taller than the tallest thing')
        for (let sd = 0; sd < 4; sd++) {
            const h = SM.heightOf(k, sd)
            // its buttons fit: a column (3 x 22 + 2 x 4 from y 14) or a row (18 px, 7 px from the foot, 3 x 18 + 2 x 3 wide)
            if (sp.buttons === 'column') assert.ok(14 + 3 * 22 + 2 * 4 <= h - 3, k + ' h' + h + ': three buttons fit up it')
            else { const nb = k === 'note' ? 2 : 3; assert.ok(nb * 18 + (nb - 1) * 3 <= sp.w, k + ': its buttons fit along its foot'); assert.ok(18 + 7 <= h - 40, k + ': and the foot is clear of the top') }
            // a leaning one does not poke out of the side margin
            const lean = Math.abs(sp.lean) + 2.5
            assert.ok(Math.ceil(h * Math.sin(lean * Math.PI / 180)) <= num('vpMargin'), k + ' leaning stays in the side margin')
        }
    }
    // the kinds: folder, polaroid, video tape, record, box, note, book
    const f = (value, extra) => Object.assign({ id: 'x', kind: 'file', value }, extra || {})
    assert.strictEqual(SM.kindOf(f('/a/b', { dir: true })), 'folder', 'a directory is a folder')
    assert.strictEqual(SM.kindOf(f('/a/b')), 'book', 'until it is known to be a directory, a file with no known type is a book')
    for (const [v, k] of [['/a/p.PNG', 'image'], ['/a/p.jpeg', 'image'], ['/a/p.webp', 'image'], ['/a/m.mkv', 'video'], ['/a/m.mp4', 'video'],
        ['/a/s.flac', 'audio'], ['/a/s.mp3', 'audio'], ['/a/s.opus', 'audio'], ['/a/z.zip', 'archive'], ['/a/z.tar.zst', 'archive'], ['/a/z.7z', 'archive'],
        ['/a/d.pdf', 'book'], ['/a/d.txt', 'book'], ['/a/main.py', 'book'], ['/a/noext', 'book']])
        assert.strictEqual(SM.kindOf(f(v)), k, v + ' is a ' + k)
    assert.strictEqual(SM.kindOf({ id: 't', kind: 'text', value: 'hello' }), 'note', 'a text is a note')
    assert.strictEqual(SM.kindOf(f('/a/p.png', { dir: true })), 'folder', 'a directory called x.png is still a folder')
    assert.strictEqual(SM.iconOf(f('/a/d.pdf')), 'picture_as_pdf'); assert.strictEqual(SM.iconOf(f('/a/main.py')), 'code'); assert.strictEqual(SM.iconOf(f('/a/d.txt')), 'description')
    // the picture list is the one the shelf always used
    assert.ok(SM.isImage('/a/p.svg') && SM.isImage('/a/P.JPEG') && !SM.isImage('/a/p.mp4'))
    // heights: books 96 - 120, folders 94 - 112, the rest one height; no random
    assert.deepStrictEqual([0, 1, 2, 3].map(sd => SM.heightOf('book', sd)), [120, 112, 104, 96])
    assert.deepStrictEqual([0, 1, 2, 3].map(sd => SM.heightOf('image', sd)), [88, 88, 88, 88])
    assert.ok(!/Math\.random/.test(MJ), 'a thing keeps its colour and height: no random')
    assert.ok(/h = \(h \* 31 \+ t\.charCodeAt\(i\)\) % 1000003/.test(MJ), 'the same seed as before: a thing keeps the colour it had')
    assert.strictEqual(SM.seedOf('abc'), SM.seedOf('abc'))
    const cols = new Set(), hs = new Set()
    for (let n = 0; n < 200; n++) { const sd = SM.seedOf('item-' + n); cols.add(Math.floor(sd / 4) % 5); hs.add(sd % 4) }
    assert.strictEqual(cols.size, 5); assert.strictEqual(hs.size, 4)
    assert.ok(/Theme\.attributeColors\[Math\.floor\(row\.seed \/ 4\) % Theme\.attributeColors\.length\]/.test(C), 'the five card colours, from the seed')
    // the card draws each kind with its own file
    for (const [k, n] of [['folder', 'ShelfFolder'], ['image', 'ShelfPolaroid'], ['video', 'ShelfTape'], ['audio', 'ShelfVinyl'], ['archive', 'ShelfBox'], ['note', 'ShelfNote']]) {
        assert.ok(new RegExp('case "' + k + '": return ').test(C) && new RegExp(n + ' \\{ item: row\\.it').test(C), k + ' is drawn by ' + n)
        const F = face(n)
        assert.ok(/required property var item/.test(F) && /required property bool lifted/.test(F) && /Theme\.lineShadow/.test(F) && /Theme\.borderWidth/.test(F), n + ': an item, a lift, the outline and the hard shadow')
    }
    assert.ok(/ShelfBook \{ item: row\.it; icon: SM\.iconOf\(row\.it\)/.test(C), 'every other file is a book')
    // the polaroid shows the picture itself; the book keeps the name up its spine
    assert.ok(/source: root\.item\.kind === "file" \? "file:\/\/" \+ root\.item\.value : ""/.test(face('ShelfPolaroid')), 'the polaroid has the picture')
    assert.ok(/rotation: -90/.test(face('ShelfBook')) && /text: root\.item\.name/.test(face('ShelfBook')), 'the book has its name up the spine')
    // the pointer box does not move while the thing slides (or it would flicker)
    assert.ok(/y: root\.areaH - row\.height/.test(C) && /height: row\.modelData\.h \+ root\.lift/.test(C), 'the hover box is fixed')
    assert.ok(/y: \(row\.lifted \? 0 : root\.lift\)/.test(C), 'the thing itself slides up inside it')
    assert.ok(/id: shelfRow[\s\S]*?y: 10\s*\n/.test(C), 'the things stand on the plank (area 10 px under the view top, plank at areaH + 8, feet 2 px behind its edge)')
    assert.ok(/rotation: row\.lifted \? -2\.5 : SM\.restTilt\(row\.kind, row\.seed\)/.test(C), 'it tilts when pointed at; a polaroid and a note lean a little at rest')
    // the buttons: a column up a tall thing, a row along the foot of a wide one; a text has no folder button
    assert.ok(/\["copy", "folder", "x"\]/.test(C) && /\["copy", "x"\]/.test(C), 'the same buttons: files get a folder one too')
    assert.ok(/columns: row\.rowButtons \? 3 : 1/.test(C), 'column or row')
    assert.ok(/Text \{[\s\S]*?text: root\.hoverItem \? root\.hoverItem\.name : \(root\.hint !== "" \? root\.hint : "Pick one to open it"\)/.test(C), 'the name of the thing you point at (or what the header button does)')
    assert.ok(/\(shelves\.currentIndex \+ 1\) \+ " \/ " \+ root\.shelfCount/.test(C), 'the "2 / 3" tag')
    // packing: in order, never split, a new shelf when the next one does not fit, none over the width
    const mk = (n, v) => Array.from({ length: n }, (_, i) => ({ id: 'i' + i, kind: 'file', value: v }))
    let sh = SM.pack(mk(9, '/a/d.pdf'), listW, gap)
    assert.strictEqual(sh.length, 1, 'nine books are one shelf'); assert.strictEqual(SM.pack(mk(10, '/a/d.pdf'), listW, gap).length, 2, 'the tenth starts the next')
    assert.strictEqual(SM.pack([], listW, gap).length, 0)
    const many = []
    for (let n = 0; n < 60; n++) many.push(f(['/a/p.png', '/a/m.mp4', '/a/s.mp3', '/a/z.zip', '/a/d.pdf', '/a/dir'][n % 6], { id: 'n' + n, dir: n % 6 === 5 }))
    many[7] = { id: 'tx', kind: 'text', value: 'a note' }
    sh = SM.pack(many, listW, gap)
    assert.deepStrictEqual(sh.flat().map(t => t.item.id), many.map(t => t.id), 'the order is kept and nothing is lost')
    for (const row of sh) {
        let x = 0
        for (const t of row) { assert.strictEqual(t.x, x, 'things stand edge to edge, with the gap'); x += t.w + gap }
        assert.ok(x - gap <= listW, 'a shelf is never wider than the card')
    }
    // a new thing does not leave a half-empty shelf when it would fit on the one before
    for (let r = 0; r + 1 < sh.length; r++) {
        const last = sh[r].at(-1), next = sh[r + 1][0]
        assert.ok(last.x + last.w + gap + next.w > listW, 'the next shelf only starts when its first thing does not fit')
    }
}
// "Copy all": a header button and a dock menu row, both ShelfService.copyAll().
{
    const DK = fs.readFileSync(root + 'modules/sekai/dock/Dock.qml', 'utf8')
    assert.ok(/icon: root\.copiedAll \? "check" : "copy_all"/.test(C) && /ShelfService\.copyAll\(\)/.test(C), 'a copy-all button in the header, with a tick after')
    assert.ok(/id: "shelfcopyall"/.test(DK) && /id === "shelfcopyall"\)\s*\{\s*\n\s*ShelfService\.copyAll\(\)/.test(DK), 'and a row in the Shelf key\'s menu')
    // the header is icons only (Paste, Copy all, Clear, Close: 4 x 40 px + 3 x 8 gaps, next to the title), each with a hint
    const head = C.slice(C.indexOf('id: header'), C.indexOf('// ===== the line above') > 0 ? C.indexOf('// ===== the line above') : C.length)
    assert.ok(!/label:/.test(head), 'the header buttons are icons only')
    for (const [h, t] of [['pasteHover', 'Add what is on the clipboard'], ['copyAllHover', 'Copy everything on the shelf'], ['clearHover', 'Clear the shelf']])
        assert.ok(new RegExp('id: ' + h).test(head) && new RegExp(h + '\\.hovered \\? "' + t + '"').test(C), h + ' says "' + t + '"')
    assert.ok(4 * 40 + 3 * 8 + 90 <= 360, 'the header fits the 360 px')
    assert.ok(/function copyAll\(\)/.test(SRV) && /--type text\/uri-list/.test(SRV.slice(SRV.indexOf('function copyAll'))), 'files go on the clipboard as files')
    assert.ok(/root\.items\.map\(i => i\.value\)\.join\("\\n\\n"\)/.test(SRV), 'with no files, the texts one after another')
}
// Folders are found out by the service, once, and kept.
assert.ok(/\{ id, kind: "file" \| "text", value, name, added, dir \}/.test(SRV), 'the item can say it is a folder')
assert.ok(/i\.kind === "file" && i\.dir === undefined/.test(SRV) && /\[ -d \\"\$p\\" \]/.test(SRV), 'every file with no `dir` yet is asked about with test -d')
assert.ok(/root\.persist\(\)\s*\n\s*root\.checkDirs\(\)/.test(SRV) && /root\.items = j\s*\n\s*root\.checkDirs\(\)/.test(SRV), 'asked when something is put down and when the shelf is loaded')
assert.ok(/Object\.assign\(\{\}, i, \{ dir: dirs\.has\(i\.value\) \}\)/.test(SRV), '`dir` is set without touching the rest of the item')
// The shelves scroll vertically: nine books a shelf, one plank each, one shelf at a time.
{
    const num = n => +C.match(new RegExp('readonly property (?:real|int) ' + n + ': (\\d+)'))[1]
    const areaH = num('bookMaxH') + num('lift'), plankH = num('plankH'), listW = num('listW')
    assert.ok(/ListView \{\s*\n\s*id: shelves/.test(C) && /clip: true/.test(C), 'a clipped ListView holds the shelves')
    assert.ok(/model: root\.shelfCount/.test(C) && /Math\.max\(1, root\.packed\.length\)/.test(C), 'one delegate per shelf')
    assert.ok(/root\.packed\[shelf\.index\] \?\? \[\]/.test(C) && /SM\.pack\(root\.items, root\.listW, root\.bookGap\)/.test(C), 'a shelf takes its own row from ShelfMath.pack')
    assert.ok(!/orientation: ListView\.Horizontal/.test(C), 'vertical, not sideways')
    assert.ok(/snapMode: ListView\.SnapOneItem/.test(C) && /highlightRangeMode: ListView\.StrictlyEnforceRange/.test(C), 'it always rests on a whole shelf')
    assert.ok(/height: root\.unitH/.test(C) && /readonly property real unitH: root\.areaH \+ 8 \+ root\.plankH \+ 10/.test(C), 'the view is one shelf tall')
    // the shelf (books, plank, its shadow and brackets) fits the view; the view stays inside the card's padding
    const unitH = areaH + 8 + plankH + 10
    assert.ok(10 + areaH <= areaH + 8 + 2 + 0 + 8, 'books stay above the plank bottom')
    assert.ok(8 + plankH + 9.5 <= unitH - 8 + 8, 'the brackets (9.5 px under the plank) are not cut')
    assert.ok(unitH - (areaH + 8 + plankH) <= pad, 'the view only reaches as far down as the card\'s padding')
    // the view has side room for the plank's spring (up to 3.6 % wider) and for a leaning book
    const vp = num('vpMargin'), spring = (listW + 16) * 0.036 / 2
    assert.ok(vp >= 8 + spring && vp <= pad, 'side margin holds the plank overhang plus its spring, inside the padding')
    const lean = Math.ceil(num('bookMaxH') * Math.sin(2.5 * Math.PI / 180))
    assert.ok(vp >= lean, 'a leaning book is not cut at the first column')
    // the wheel: one notch of Theme.wheelStep (110) passes the 60 px threshold, a touchpad adds up to it
    assert.ok(/WheelHandler \{/.test(C) && /acceptedDevices: PointerDevice\.Mouse \| PointerDevice\.TouchPad/.test(C), 'wheel and touchpad')
    assert.ok(/Theme\.wheelPx\(event, false\)/.test(C) && /wheelHost\.acc >= 60/.test(C) && /wheelHost\.acc <= -60/.test(C), 'the shell\'s wheel distance, 60 px per shelf')
    assert.ok(/shelves\.currentIndex = Math\.max\(0, shelves\.currentIndex - 1\)/.test(C) && /Math\.min\(root\.shelfCount - 1, shelves\.currentIndex \+ 1\)/.test(C), 'up goes to the previous shelf, down to the next, both clamped')
    assert.ok(/interval: 220/.test(C), 'a touchpad swipe\'s tail does not skip shelves')
    assert.ok(/SekaiScrollBar \{/.test(C), 'the shell\'s scroll bar')
    // 2 / 3 labels: nine books to a shelf, the others fewer or more (up to 60 items kept)
    const count = (n, v) => Math.max(1, SM.pack(Array.from({ length: n }, (_, i) => ({ id: 'i' + i, kind: 'file', value: v })), listW, 4).length)
    assert.deepStrictEqual([0, 1, 9, 10, 18, 19, 60].map(n => count(n, '/a/d.pdf')), [1, 1, 1, 2, 2, 3, 7])
    assert.ok(count(60, '/a/p.png') > count(60, '/a/d.pdf') && count(60, '/a/m.mp4') < count(60, '/a/d.pdf'), 'wide things fill a shelf sooner, thin ones later')
    // new things land on the first shelf, closing the card goes back to it
    assert.ok(/onItemsChanged:[\s\S]*?shelves\.currentIndex = 0/.test(C) && /onOpenChanged:[\s\S]*?shelves\.currentIndex = 0/.test(C), 'back to the first shelf')
}
console.log('shelf_look_test: all checks passed')
