// Rules of the Sticky Notes maths, one by one. Run: node notes_unit.js
const fs = require('fs'), assert = require('assert')
const src = fs.readFileSync(__dirname + '/../../modules/common/functions/NotesMath.js', 'utf8').replace('.pragma library', '')
const N = {}
new Function('N', src + ';N.fit=fit;N.cascade=cascade;N.move=move;N.resize=resize;N.topZ=topZ;N.windowRect=windowRect;N.parse=parse;N.cleanNotes=cleanNotes;N.nextTint=nextTint;N.paperOf=paperOf;N.validTint=validTint;N.COLORS=COLORS;N.MIN_W=MIN_W;N.MIN_H=MIN_H;N.MAX_NOTES=MAX_NOTES;N.MAX_CHARS=MAX_CHARS;')(N)

const W = 1920, H = 1080
const R = (x, y, w, h) => ({ x, y, w, h })

// 1. a rect is kept on screen and never below the minimum size
let r = N.fit(R(-50, 2000, 10, 10), W, H)
assert.deepStrictEqual(r, R(0, H - N.MIN_H, N.MIN_W, N.MIN_H))
r = N.fit(R(1900, 10, 300, 200), W, H)
assert.strictEqual(r.x, W - 300)
r = N.fit(R(0, 0, 5000, 5000), W, H)
assert.strictEqual(r.w, W); assert.strictEqual(r.h, H)
console.log('ok  fit keeps a note on screen')

// 2. a tiny screen (smaller than the minimum) still gets a valid rect
r = N.fit(R(0, 0, 400, 400), 150, 100)
assert.ok(r.w <= 150 && r.h <= 100 && r.x >= 0 && r.y >= 0)
console.log('ok  fit on a tiny screen')

// 3. moving follows the pointer and stops at the edges
r = N.move(R(100, 100, 240, 200), 50, -500, W, H)
assert.strictEqual(r.x, 150); assert.strictEqual(r.y, 0)
r = N.move(R(100, 100, 240, 200), 99999, 99999, W, H)
assert.strictEqual(r.x, W - 240); assert.strictEqual(r.y, H - 200)
console.log('ok  move clamps')

// 4. resizing keeps the top-left corner, respects the minimum and the screen
r = N.resize(R(100, 100, 240, 200), 60, 40, 'rb', W, H)
assert.deepStrictEqual(r, R(100, 100, 300, 240))
r = N.resize(R(100, 100, 240, 200), -500, -500, 'rb', W, H)
assert.strictEqual(r.w, N.MIN_W); assert.strictEqual(r.h, N.MIN_H)
r = N.resize(R(100, 100, 240, 200), 99999, 99999, 'rb', W, H)
assert.strictEqual(r.w, W - 100); assert.strictEqual(r.h, H - 100)
r = N.resize(R(100, 100, 240, 200), 60, 40, 'r', W, H)
assert.strictEqual(r.w, 300); assert.strictEqual(r.h, 200)
r = N.resize(R(100, 100, 240, 200), 60, 40, 'b', W, H)
assert.strictEqual(r.w, 240); assert.strictEqual(r.h, 240)
// a note already past the minimum on a cramped spot is not forced off screen
r = N.resize(R(1800, 100, 240, 200), 50, 0, 'r', W, H)
assert.ok(r.x + r.w <= W)
console.log('ok  resize')

// 5. new notes cascade, wrap after six and stay on screen
const spots = [0, 1, 2, 3, 4, 5, 6].map(n => N.cascade(n, W, H))
assert.ok(spots[1].x < spots[0].x && spots[1].y > spots[0].y)
assert.deepStrictEqual(spots[6], spots[0])
for (const s of spots) assert.ok(s.x >= 0 && s.y >= 0 && s.x + s.w <= W && s.y + s.h <= H)
const small = N.cascade(3, 500, 300)
assert.ok(small.x >= 0 && small.y >= 0 && small.x + small.w <= 500 && small.y + small.h <= 300)
console.log('ok  cascade')

// 6. colours: valid ids, a fallback, a rotating default
assert.ok(N.validTint('mint')); assert.ok(!N.validTint('red')); assert.ok(!N.validTint(undefined))
assert.strictEqual(N.paperOf('nope'), N.COLORS[0].paper)
assert.strictEqual(N.nextTint(0), 'yellow'); assert.strictEqual(N.nextTint(6), 'yellow'); assert.strictEqual(N.nextTint(7), 'pink')
console.log('ok  colours')

// 7. raising puts a note above the rest
assert.strictEqual(N.topZ([]), 1); assert.strictEqual(N.topZ([3, 9, 2]), 10)
console.log('ok  topZ')

// 8. the input-mask rectangle follows the window offset and the factor
assert.deepStrictEqual(N.windowRect(R(10, 20, 100, 50), 0, 0, 1), R(10, 20, 100, 50))
assert.deepStrictEqual(N.windowRect(R(10, 20, 100, 50), 100, 50, 0.5), R(105, 60, 50, 25))
r = N.windowRect(R(-10, -10, 20, 20), 0, 0, 1)
assert.ok(r.x === 0 && r.y === 0)
console.log('ok  windowRect')

// 9. reading the saved file: good data stays, bad data is put right
let p = N.parse('')
assert.deepStrictEqual(p, { shown: true, scale: 0, notes: [], setName: '', sets: {} })
p = N.parse('{ not json')
assert.strictEqual(p.notes.length, 0)
p = N.parse(JSON.stringify({ shown: false, scale: 1.25, notes: [
    { id: 'a', body: 'hello', tint: 'pink', x: 10, y: 20, w: 300, h: 250, z: 4, pinned: true },
    { id: 'a', body: 'dup' },
    null,
    { body: 5, tint: 'blue', x: 'no', w: 3, h: 3 }
] }))
assert.strictEqual(p.shown, false); assert.strictEqual(p.scale, 1.25)
assert.strictEqual(p.notes.length, 2)
assert.deepStrictEqual(p.notes[0], { id: 'a', body: 'hello', tint: 'pink', x: 10, y: 20, w: 300, h: 250, z: 4, pinned: true })
assert.strictEqual(p.notes[1].body, ''); assert.ok(N.validTint(p.notes[1].tint)); assert.strictEqual(p.notes[1].x, 0)
assert.strictEqual(p.notes[1].w, N.MIN_W); assert.strictEqual(p.notes[1].h, N.MIN_H); assert.strictEqual(p.notes[1].pinned, false)
const many = N.parse(JSON.stringify({ notes: Array.from({ length: 40 }, (_, i) => ({ id: 'n' + i })) }))
assert.strictEqual(many.notes.length, N.MAX_NOTES)
assert.strictEqual(N.parse(JSON.stringify({ notes: [{ id: 'a', body: 'x'.repeat(N.MAX_CHARS + 500) }] })).notes[0].body.length, N.MAX_CHARS)
console.log('ok  parse')

// 10. one set of notes per preset: read back clean, the old file shape still loads
p = N.parse(JSON.stringify({ shown: true, notes: [{ id: 'a', body: 'mine' }], setName: 'Night',
    sets: { Day: { shown: false, notes: [{ id: 'b', body: 'day note', pinned: true }, null] },
            '': { notes: [{ id: 'x' }] }, Bad: 5, Arr: { notes: 'no' } } }))
assert.strictEqual(p.setName, 'Night')
assert.deepStrictEqual(Object.keys(p.sets).sort(), ['Arr', 'Day'])
assert.strictEqual(p.sets.Day.shown, false); assert.strictEqual(p.sets.Day.notes.length, 1)
assert.strictEqual(p.sets.Day.notes[0].body, 'day note'); assert.strictEqual(p.sets.Day.notes[0].pinned, true)
assert.strictEqual(p.sets.Arr.notes.length, 0)
p = N.parse(JSON.stringify({ shown: true, notes: [{ id: 'a' }], setName: 7, sets: [1] }))
assert.strictEqual(p.setName, ''); assert.deepStrictEqual(p.sets, {}); assert.strictEqual(p.notes.length, 1)
console.log('ok  per-preset sets')
