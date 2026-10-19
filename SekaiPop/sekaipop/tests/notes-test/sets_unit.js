// One set of notes per preset: the NotesService functions that switch them, run on a fake
// list model. (Not run against Qt; the QML is the same text, taken out of the file.)
const assert = require("assert")
const fs = require("fs")
const src = fs.readFileSync(require("../lib/locate")("services/NotesService.qml"), "utf8")
function grab(name) {
    const start = src.indexOf("    function " + name + "(")
    assert(start >= 0, "no function " + name)
    return src.slice(start, src.indexOf("\n    }\n", start) + 7).replace(/^    function /, "function ")
}

function make() {
    const rows = []
    const listModel = {
        get count() { return rows.length },
        get: i => rows[i], append: o => rows.push(Object.assign({}, o)), clear: () => { rows.length = 0 }
    }
    const root = { loaded: true, shown: true, setName: "", sets: {}, freshId: "x", commits: 0, rows }
    root.recount = () => {}
    root.commit = () => { root.commits++ }
    for (const n of ["currentNotes", "fill", "stashCurrent", "switchSet", "adoptSet", "renameSet", "dropSet"])
        root[n] = new Function("root", "listModel", "return (" + grab(n) + ")")(root, listModel)
    root.add = body => rows.push({ nid: "n" + rows.length, body, tint: "pink", nx: 0, ny: 0, nw: 200, nh: 200, nz: 1, pinned: false })
    return root
}
const bodies = r => r.rows.map(n => n.body)

// 1. a preset with no notes of its own keeps the desktop's, and owns that copy from then on
let r = make()
r.add("first")
r.switchSet("Day")
assert.strictEqual(r.setName, "Day"); assert.deepStrictEqual(bodies(r), ["first"]); assert.deepStrictEqual(r.sets, {})

// 2. edit under Day, wear Night (no notes yet): Day keeps its edit, Night starts from the same notes
r.add("day only")
r.switchSet("Night")
assert.deepStrictEqual(bodies(r), ["first", "day only"], "Night inherits what was on the desktop")
assert.deepStrictEqual(r.sets.Day.notes.map(n => n.body), ["first", "day only"])

// 3. now they are separate: change Night, go back to Day, and Night's change is not there
r.rows[0].body = "night edit"
r.switchSet("Day")
assert.deepStrictEqual(bodies(r), ["first", "day only"], "Day got its own notes back")
assert.deepStrictEqual(r.sets.Night.notes.map(n => n.body), ["night edit", "day only"])
r.switchSet("Night")
assert.deepStrictEqual(bodies(r), ["night edit", "day only"])
assert.ok(!("Night" in r.sets), "the worn preset's notes live on the desktop, not in sets")

// 4. wearing the one already worn does nothing
const c = r.commits
r.switchSet("Night")
assert.strictEqual(r.commits, c)

// 5. saving a new preset: it takes the desktop's notes, the worn one keeps its own
r.adoptSet("Third")
assert.strictEqual(r.setName, "Third"); assert.deepStrictEqual(r.sets.Night.notes.map(n => n.body), ["night edit", "day only"])
r.rows[1].body = "third edit"
r.switchSet("Night")
assert.deepStrictEqual(bodies(r), ["night edit", "day only"])
assert.deepStrictEqual(r.sets.Third.notes.map(n => n.body), ["night edit", "third edit"])

// 6. rename moves the set (stashed or worn)
r.renameSet("Third", "Fourth")
assert.ok(r.sets.Fourth && !r.sets.Third)
r.renameSet("Night", "Late")
assert.strictEqual(r.setName, "Late")

// 7. delete drops the stashed set; deleting the worn one leaves its notes on the desktop
r.dropSet("Fourth")
assert.ok(!r.sets.Fourth)
r.dropSet("Late")
assert.strictEqual(r.setName, ""); assert.deepStrictEqual(bodies(r), ["night edit", "day only"])

// 8. a preset whose own set was emptied comes back empty and off
r = make(); r.add("a"); r.switchSet("A"); r.switchSet("B")
r.rows.length = 0; r.shown = false
r.switchSet("A"); r.switchSet("B")
assert.strictEqual(r.rows.length, 0); assert.strictEqual(r.shown, false)

// 9. nothing happens before the state is read
r = make(); r.loaded = false; r.switchSet("X"); r.adoptSet("X")
assert.strictEqual(r.setName, "")
console.log("sets_unit: all checks passed")
