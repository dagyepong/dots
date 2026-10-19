.pragma library

// The maths behind the Sticky Notes widget (services/NotesService.qml keeps the
// notes, StickyNotesWidget.qml / StickyNote.qml draw them). Pure functions on
// plain numbers in DESIGN pixels (the space the other desktop cards use), so
// they can be unit-tested with node: tests/notes-test/notes_unit.js.
//
// A "rect" is { x, y, w, h }. `room` is the screen as the notes see it (real
// size / the monitor's UI scale).

var MAX_NOTES = 12          // the widget's input mask has one slot per note
var MIN_W = 200             // room for the header's four keys (or the six swatches)
var MIN_H = 130
var DEF_W = 240
var DEF_H = 200
// Longest text a note keeps. The whole state travels to notes-state.sh as ONE command-line
// argument (Linux allows ~128 KB for it): 12 notes x 3000 characters x at most 3 bytes
// each stays under that.
var MAX_CHARS = 3000

// Paper colours. Fixed, not the theme's: a yellow note stays yellow.
var COLORS = [
    { id: "yellow",   name: "Yellow",   paper: "#ffec8b" },
    { id: "pink",     name: "Pink",     paper: "#ffc2e4" },
    { id: "mint",     name: "Mint",     paper: "#b9f6e1" },
    { id: "cyan",     name: "Cyan",     paper: "#bfeaff" },
    { id: "lavender", name: "Lavender", paper: "#dccfff" },
    { id: "peach",    name: "Peach",    paper: "#ffd3b3" }
]

function validTint(id) {
    for (var i = 0; i < COLORS.length; i++)
        if (COLORS[i].id === id)
            return true
    return false
}

function paperOf(id) {
    for (var i = 0; i < COLORS.length; i++)
        if (COLORS[i].id === id)
            return COLORS[i].paper
    return COLORS[0].paper
}

// The colour a new note gets: the palette in turn, so a fresh pile is not all yellow.
function nextTint(count) {
    return COLORS[((count % COLORS.length) + COLORS.length) % COLORS.length].id
}

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v))
}

// A rect kept on screen: never smaller than the minimum (unless the screen is),
// never bigger than the screen, never partly off it.
function fit(r, roomW, roomH) {
    var w = clamp(Math.round(r.w), Math.min(MIN_W, roomW), Math.max(1, roomW))
    var h = clamp(Math.round(r.h), Math.min(MIN_H, roomH), Math.max(1, roomH))
    return {
        x: clamp(Math.round(r.x), 0, Math.max(0, roomW - w)),
        y: clamp(Math.round(r.y), 0, Math.max(0, roomH - h)),
        w: w,
        h: h
    }
}

// Where the n-th new note goes: the top right, each one a step down and to the
// left of the last, wrapping after six so a long pile never runs off screen.
function cascade(n, roomW, roomH) {
    var step = 30
    var k = ((n % 6) + 6) % 6
    return fit({ x: roomW - DEF_W - 80 - k * step, y: 110 + k * step, w: DEF_W, h: DEF_H }, roomW, roomH)
}

// A note dragged by its header: the start rect moved by the pointer's travel.
function move(start, dx, dy, roomW, roomH) {
    return fit({ x: start.x + dx, y: start.y + dy, w: start.w, h: start.h }, roomW, roomH)
}

// A note resized by an edge or the corner: `edge` is "r", "b" or "rb". The
// top-left corner never moves.
function resize(start, dx, dy, edge, roomW, roomH) {
    var w = start.w
    var h = start.h
    if (edge === "r" || edge === "rb")
        w = clamp(start.w + dx, MIN_W, Math.max(MIN_W, roomW - start.x))
    if (edge === "b" || edge === "rb")
        h = clamp(start.h + dy, MIN_H, Math.max(MIN_H, roomH - start.y))
    return fit({ x: start.x, y: start.y, w: w, h: h }, roomW, roomH)
}

// One above every other note.
function topZ(zs) {
    var m = 0
    for (var i = 0; i < zs.length; i++)
        if (zs[i] > m)
            m = zs[i]
    return m + 1
}

// A note's rect in WINDOW pixels, for the input mask: `ox` / `oy` is where the
// stage's picture starts in the window, `k` the design -> window factor
// (UI scale x the Edit Desktop shrink).
function windowRect(r, ox, oy, k) {
    var x = Math.max(0, Math.round(ox + r.x * k))
    var y = Math.max(0, Math.round(oy + r.y * k))
    return {
        x: x,
        y: y,
        w: Math.max(0, Math.ceil(ox + (r.x + r.w) * k) - x),
        h: Math.max(0, Math.ceil(oy + (r.y + r.h) * k) - y)
    }
}

// Puts a saved list of notes right: anything odd is dropped or corrected, never thrown.
// Returns [{ id, body, tint, x, y, w, h, z, pinned }], at most MAX_NOTES.
function cleanNotes(list) {
    var out = []
    if (!Array.isArray(list))
        return out
    var seen = {}
    var num = function (v, d) { return typeof v === "number" && isFinite(v) ? v : d }
    for (var i = 0; i < list.length && out.length < MAX_NOTES; i++) {
        var n = list[i]
        if (!n || typeof n !== "object")
            continue
        var id = typeof n.id === "string" && n.id !== "" ? n.id : "n" + i
        if (seen[id])
            continue
        seen[id] = true
        out.push({
            id: id,
            body: typeof n.body === "string" ? n.body.slice(0, MAX_CHARS) : "",
            tint: validTint(n.tint) ? n.tint : nextTint(i),
            x: num(n.x, 0),
            y: num(n.y, 0),
            w: Math.max(MIN_W, num(n.w, DEF_W)),
            h: Math.max(MIN_H, num(n.h, DEF_H)),
            z: Math.round(num(n.z, i + 1)),
            pinned: n.pinned === true
        })
    }
    return out
}

// Reads what the state script printed back into clean notes. Anything odd is
// dropped or put right, never thrown: a hand-edited file must not take the
// widget down. Returns
//   { shown, scale, notes: [...], setName, sets: { <preset name>: { shown, notes: [...] } } }
// `notes` are the notes on the desktop now, and they belong to the preset called `setName`
// ("" = none yet); `sets` holds the notes of every OTHER preset (see NotesService.qml).
function parse(text) {
    var out = { shown: true, scale: 0, notes: [], setName: "", sets: {} }
    var s
    try {
        s = JSON.parse(text)
    } catch (e) {
        return out
    }
    if (!s || typeof s !== "object")
        return out
    out.shown = s.shown !== false
    if (typeof s.scale === "number" && s.scale > 0)
        out.scale = s.scale
    out.notes = cleanNotes(s.notes)
    if (typeof s.setName === "string")
        out.setName = s.setName
    if (s.sets && typeof s.sets === "object" && !Array.isArray(s.sets)) {
        var names = Object.keys(s.sets)
        for (var k = 0; k < names.length; k++) {
            var e = s.sets[names[k]]
            if (names[k] === "" || !e || typeof e !== "object")
                continue
            out.sets[names[k]] = { shown: e.shown !== false, notes: cleanNotes(e.notes) }
        }
    }
    return out
}
