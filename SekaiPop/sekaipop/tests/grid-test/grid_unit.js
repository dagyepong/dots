// Rules of the alignment grid, one by one. Run: node grid_unit.js
const fs = require('fs'), assert = require('assert')
const src = fs.readFileSync(__dirname + '/../../modules/common/functions/EditGridMath.js', 'utf8').replace('.pragma library', '')
const G = {}
new Function('G', src + ';G.snap=snap;G.snapAxis=snapAxis;G.targets=targets;G.relations=relations;G.gridHits=gridHits;G.assignSlots=assignSlots;G.sig=sig;G.CELL=CELL;G.PULL_GRID=PULL_GRID;G.PULL_WIDGET=PULL_WIDGET;')(G)

const room = { w: 1920, h: 1080 }
const R = (id, x, y, w, h) => ({ id, x, y, w, h })
const keys = r => r.lines.map(l => l.key).sort()

// 1. near a grid line, an edge is pulled onto it; far from one, nothing moves
let s = G.snap(R('a', 203, 405, 300, 150), [], room)
assert.strictEqual(s.x, 200); assert.strictEqual(s.kindX, 'grid')
assert.strictEqual(s.y, 400); assert.strictEqual(s.kindY, 'grid')
s = G.snap(R('a', 210, 410, 280, 140), [], room)   // every edge 10 (half a cell) from the nearest line: out of reach
assert.strictEqual(s.x, 210); assert.strictEqual(s.kindX, '')
assert.strictEqual(s.y, 410); assert.strictEqual(s.kindY, '')
console.log('ok  grid pull and free space between lines')

// 2. the RIGHT edge can be the one that lands on the grid
s = G.snap(R('a', 101, 400, 299, 150), [], room)    // right edge at 400
assert.strictEqual(s.x, 101 + (400 - 400)); assert.strictEqual(s.kindX, 'grid')
s = G.snap(R('a', 123, 400, 284, 150), [], room)    // left is 3 from 120, right (407) is 7 from 400: the nearer one wins
assert.strictEqual(s.x, 120)
console.log('ok  either edge can land on a grid line')

// 3. another widget beats the grid when both are in reach
const other = R('b', 513, 100, 300, 200)
s = G.snap(R('a', 205, 100, 300, 150), [other], room)   // right edge 505 -> b.left 513 is 8 away; grid 200 is 5 away
assert.strictEqual(s.x, 213); assert.strictEqual(s.kindX, 'widget')
console.log('ok  widget lines win over the grid')

// 4. centres pair with centres
s = G.snap(R('a', 0, 500, 100, 100), [R('b', 600, 100, 300, 200)], room)
s = G.snap(R('a', 695, 450, 110, 100), [R('b', 600, 100, 300, 200)], room)  // a centre 750 = b centre 750
assert.strictEqual(s.x, 695); assert.strictEqual(s.kindX, 'widget')
s = G.snap(R('a', 700, 450, 110, 100), [R('b', 600, 100, 300, 200)], room)  // centre 755 -> 750
assert.strictEqual(s.x, 695)
console.log('ok  centre to centre')

// 5. never outside the screen
s = G.snap(R('a', -5, -3, 300, 150), [], room)
assert.ok(s.x >= 0 && s.y >= 0)
s = G.snap(R('a', 1915 - 300, 1075 - 150, 300, 150), [], room)
assert.ok(s.x <= 1920 - 300 && s.y <= 1080 - 150)
console.log('ok  stays on screen')

// 6. alignment: top, bottom, left, right, centre
const m = R('m', 100, 100, 300, 150)
let r = G.relations(m, [R('t', 600, 100, 200, 90)], room)
assert.deepStrictEqual(keys(r), ['h:T:1000'])
assert.strictEqual(r.lines[0].label, 'TOP'); assert.strictEqual(r.lines[0].kind, 'edge')
r = G.relations(m, [R('t', 600, 160, 200, 90)], room)             // bottoms both 250
assert.strictEqual(r.lines[0].label, 'BOTTOM')
r = G.relations(m, [R('t', 100, 400, 200, 90)], room)
assert.strictEqual(r.lines[0].label, 'LEFT')
r = G.relations(m, [R('t', 200, 400, 200, 90)], room)             // rights both 400
assert.strictEqual(r.lines[0].label, 'RIGHT')
r = G.relations(m, [R('t', 175, 400, 150, 90)], room)             // centres both 250
assert.strictEqual(r.lines[0].label, 'CENTER'); assert.strictEqual(r.lines[0].kind, 'center')
console.log('ok  top / bottom / left / right / centre')

// 7. touching edges are FLUSH, and a middle never pairs with an edge
r = G.relations(m, [R('t', 400, 400, 200, 90)], room)             // m.right 400 = t.left 400
assert.strictEqual(r.lines.length, 1); assert.strictEqual(r.lines[0].label, 'FLUSH'); assert.strictEqual(r.lines[0].kind, 'flush')
r = G.relations(m, [R('t', 250, 400, 200, 90)], room)             // m centre x 250 = t.left 250
assert.strictEqual(r.lines.length, 0)
console.log('ok  flush edges; centre never pairs with an edge')

// 8. many widgets on one line make ONE line that runs over all of them
r = G.relations(m, [R('a', 600, 100, 200, 80), R('b', 900, 100, 200, 60), R('c', 1300, 100, 100, 40)], room)
assert.strictEqual(r.lines.length, 1)
assert.deepStrictEqual(r.lines[0].ids, ['m', 'a', 'b', 'c'])
assert.ok(r.lines[0].from < 100 && r.lines[0].to > 1400)
assert.strictEqual(r.lines[0].dots.length, 4)
console.log('ok  one guide through many widgets')

// 9. same size
r = G.relations(m, [R('a', 600, 600, 300, 90), R('b', 900, 300, 120, 150.4)], room)
assert.deepStrictEqual(r.sizes.map(z => z.axis + ':' + z.ids.join('+')), ['w:m+a', 'h:m+b'])
console.log('ok  same width / same height')

// 10. the screen's middle
r = G.relations(R('m', 810, 100, 300, 150), [], room)             // centre x 960
assert.strictEqual(r.lines.length, 1); assert.strictEqual(r.lines[0].label, 'SCREEN CENTER')
assert.strictEqual(r.lines[0].from, 0); assert.strictEqual(r.lines[0].to, 1080)
console.log('ok  dead centre of the screen')

// 11. a snapped rect always reports what it was snapped to
const others = [R('b', 513, 100, 300, 200)]
const sn = G.snap(R('a', 205, 103, 300, 150), others, room)
const rr = G.relations(R('a', sn.x, sn.y, 300, 150), others, room)
assert.ok(rr.lines.some(l => l.label === 'FLUSH' || l.label === 'LEFT'), 'snap -> guide')
assert.ok(rr.lines.some(l => l.label === 'TOP'))
console.log('ok  what snapping does, the guides then say')

// 12. grid hits, for the ping
let h = G.gridHits(R('a', 200, 400, 300, 160), room)
assert.deepStrictEqual(h.xs, [200, 500]); assert.deepStrictEqual(h.ys, [400, 560])   // 20-px cells: the right edge (500) is on a line too
assert.strictEqual(h.corners.length, 4)
h = G.gridHits(R('a', 203, 403, 300, 160), room)
assert.strictEqual(h.xs.length, 0)
console.log('ok  grid hits')

// 13. slots keep a line where it was
const a = { key: 'v:L:1000' }, b = { key: 'h:T:500' }, c = { key: 'v:R:3000' }
let slots = G.assignSlots([null, null, null, null, null, null], [a, b], 6)
assert.deepStrictEqual(slots.map(x => x && x.key), ['v:L:1000', 'h:T:500', null, null, null, null])
slots = G.assignSlots(slots, [c, b], 6)         // a goes, c arrives, b stays put
assert.deepStrictEqual(slots.map(x => x && x.key), ['v:R:3000', 'h:T:500', null, null, null, null])
console.log('ok  slots are stable')

// 14. every position a drag can reach lands on SOMETHING consistent: snap twice = snap once
for (let i = 0; i < 2000; i++) {
    const rect = R('a', Math.random() * 1500, Math.random() * 800, 120 + Math.random() * 300, 80 + Math.random() * 200)
    const once = G.snap(rect, others, room)
    const twice = G.snap(R('a', once.x, once.y, rect.w, rect.h), others, room)
    assert.ok(Math.abs(once.x - twice.x) < 1e-9 && Math.abs(once.y - twice.y) < 1e-9, 'idempotent ' + JSON.stringify(rect))
}
console.log('ok  snapping is idempotent (the drag hook can re-run it safely)')
console.log('all grid rules hold')
