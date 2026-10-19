// node tests/keyboard-test/keyboard_unit.js   (run from the sekaipop folder)
const fs = require("fs")
const locate = require("../lib/locate.js")
const src = fs.readFileSync(locate("modules/sekai/keyboard/KeyboardLayout.js"), "utf8").replace(".pragma library", "")
const K = new Function(src + "; return { UNIT, GAP, COLS, layout, rowsWidth, initial, tapMod, afterKey, modState, labelFor, command, shifted }")()

let fails = 0
function eq(a, b, msg) {
    const x = JSON.stringify(a), y = JSON.stringify(b)
    if (x !== y) { fails++; console.log("FAIL " + msg + "\n   got  " + x + "\n   want " + y) }
}

const rows = K.layout()
eq(rows.length, 5, "five rows")
rows.forEach((r, i) => {
    eq(r.units, K.COLS, "row " + (i + 1) + " is exactly " + K.COLS + " units")
    eq(r.width, K.rowsWidth(), "row " + (i + 1) + " is as wide as the board")
    let x = 0
    r.keys.forEach(k => { eq(k.x, x, "row " + (i + 1) + " key " + k.id + " x"); x += k.width + K.GAP })
})
const key = (id, row) => rows.flatMap(r => r.keys).filter(k => k.id === id)[row || 0]

// Labels
const st0 = K.initial()
eq(K.labelFor(key("a"), st0), "a", "a")
eq(K.labelFor(key("1"), K.tapMod(st0, "shift")), "!", "shift 1 -> !")
eq(K.labelFor(key("a"), K.tapMod(st0, "caps")), "A", "caps a -> A")
eq(K.labelFor(key("1"), K.tapMod(st0, "caps")), "1", "caps leaves digits alone")
const capsShift = K.tapMod(K.tapMod(st0, "caps"), "shift")
eq(K.labelFor(key("a"), capsShift), "a", "caps + shift a -> a")
eq(K.labelFor(key("1"), capsShift), "!", "caps + shift 1 -> !")

// Shift: off -> armed -> locked -> off; one press clears armed, not locked
let s = K.tapMod(st0, "shift"); eq(s.shift, 1, "shift armed")
eq(K.afterKey(s).shift, 0, "armed shift clears after a key")
s = K.tapMod(s, "shift"); eq(s.shift, 2, "shift locked")
eq(K.afterKey(s).shift, 2, "locked shift stays after a key")
s = K.tapMod(s, "shift"); eq(s.shift, 0, "shift off again")
let m = K.tapMod(K.tapMod(st0, "ctrl"), "alt")
eq(K.modState(m, "ctrl"), 1, "ctrl armed")
m = K.afterKey(m)
eq([m.ctrl, m.alt, m.logo], [false, false, false], "ctrl / alt clear after a key")
eq(K.afterKey(K.tapMod(st0, "caps")).caps, true, "caps stays after a key")

// Commands
eq(K.command(key("a"), st0), ["wtype", "--", "a"], "plain a")
eq(K.command(key("a"), K.tapMod(st0, "shift")), ["wtype", "--", "A"], "shift a")
eq(K.command(key("-"), st0), ["wtype", "--", "-"], "a dash is typed after --")
eq(K.command(key("space"), st0), ["wtype", "--", " "], "space")
eq(K.command(key("back"), st0), ["wtype", "-k", "BackSpace"], "backspace")
eq(K.command(key("left"), K.tapMod(st0, "shift")), ["wtype", "-M", "shift", "-k", "Left", "-m", "shift"], "shift + left")
eq(K.command(key("c"), K.tapMod(st0, "ctrl")), ["wtype", "-M", "ctrl", "-k", "c", "-m", "ctrl"], "ctrl c")
eq(K.command(key("c"), K.tapMod(K.tapMod(st0, "ctrl"), "shift")),
   ["wtype", "-M", "shift", "-M", "ctrl", "-k", "c", "-m", "ctrl", "-m", "shift"], "ctrl shift c")
eq(K.command(key("1"), K.tapMod(st0, "logo")), ["wtype", "-M", "logo", "-k", "1", "-m", "logo"], "super 1")
eq(K.command(key("tab"), K.tapMod(st0, "alt")), ["wtype", "-M", "alt", "-k", "Tab", "-m", "alt"], "alt tab")
eq(K.command(key("c"), K.tapMod(st0, "caps")), ["wtype", "--", "C"], "caps c")
eq(K.command(key("c"), K.tapMod(K.tapMod(st0, "caps"), "ctrl")),
   ["wtype", "-M", "shift", "-M", "ctrl", "-k", "c", "-m", "ctrl", "-m", "shift"], "caps + ctrl c is ctrl shift c (as a real caps lock would)")

console.log(fails ? fails + " FAILED" : "keyboard: all passed")
process.exit(fails ? 1 : 0)
