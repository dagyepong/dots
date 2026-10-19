.pragma library

// The on-screen keyboard's layout and its little state machine, as plain
// numbers and strings so it can be unit-tested without a Quickshell runtime
// (tests/keyboard-test/keyboard_unit.js).
//
// Everything is in design pixels. A key is UNIT wide per unit of `w`, with GAP
// between neighbours (the workspace badges' own gap), so every row is exactly
// COLS units long and the edges line up whatever the keys in between are.
//
// A key looks like:
//   { kind, id, label, shifted, sym, icon, w, repeat }
//   kind    "char" types text      "sym" presses a named key (Return, Left...)
//           "mod"  Shift / Caps / Ctrl / Alt / Super (they only change state)
//   sym     the XKB key name wtype is given when a modifier is held
//           (`wtype -M ctrl -k c -m ctrl`); a plain character is typed as text.
//
// The state is { shift: 0|1|2, caps, ctrl, alt, logo }. shift 1 = armed for
// one key, 2 = locked; ctrl / alt / logo are armed for one key.

var UNIT = 46
var GAP = 6
var COLS = 15

var MOD_COLORS = {
    shift: "#FF9ECB",   // pink      (the five workspace colours)
    caps:  "#FFE066",   // yellow
    ctrl:  "#B39DDB",   // lavender
    alt:   "#A5E6A5",   // mint
    logo:  "#FFB27A"    // peach
}

function ch(label, shifted, sym, w) {
    return { kind: "char", id: label, label: label, shifted: shifted, sym: sym, icon: "", w: w || 1, repeat: true }
}

function letter(c) {
    return ch(c, c.toUpperCase(), c, 1)
}

function sy(id, label, icon, sym, w, repeat) {
    return { kind: "sym", id: id, label: label, shifted: label, sym: sym, icon: icon, w: w, repeat: !!repeat }
}

function md(id, label, w) {
    return { kind: "mod", id: id, label: label, shifted: label, sym: "", icon: "", w: w, repeat: false }
}

function letters(s) {
    var out = []
    for (var i = 0; i < s.length; i++)
        out.push(letter(s.charAt(i)))
    return out
}

function digits() {
    var shifted = ")!@#$%^&*("
    var out = []
    var order = "1234567890"
    for (var i = 0; i < order.length; i++) {
        var d = order.charAt(i)
        out.push(ch(d, shifted.charAt(parseInt(d, 10)), d, 1))
    }
    return out
}

function defs() {
    var space = { kind: "char", id: "space", label: " ", shifted: " ", sym: "space", icon: "", w: 5.75, repeat: true }

    var r1 = [ch("`", "~", "grave")].concat(digits(), [
        ch("-", "_", "minus"), ch("=", "+", "equal"),
        sy("back", "", "backspace", "BackSpace", 2, true)
    ])
    var r2 = [sy("tab", "", "keyboard_tab", "Tab", 1.5, false)].concat(letters("qwertyuiop"), [
        ch("[", "{", "bracketleft"), ch("]", "}", "bracketright"),
        ch("\\", "|", "backslash", 1.5)
    ])
    var r3 = [md("caps", "Caps", 1.75)].concat(letters("asdfghjkl"), [
        ch(";", ":", "semicolon"), ch("'", "\"", "apostrophe"),
        sy("enter", "", "keyboard_return", "Return", 2.25, false)
    ])
    var r4 = [md("shift", "Shift", 2.25)].concat(letters("zxcvbnm"), [
        ch(",", "<", "comma"), ch(".", ">", "period"), ch("/", "?", "slash"),
        md("shift", "Shift", 2.75)
    ])
    var r5 = [
        sy("esc", "Esc", "", "Escape", 1.25, false),
        md("ctrl", "Ctrl", 1.5), md("logo", "Super", 1.25), md("alt", "Alt", 1.25),
        space,
        sy("left", "", "keyboard_arrow_left", "Left", 1, true),
        sy("down", "", "keyboard_arrow_down", "Down", 1, true),
        sy("up", "", "keyboard_arrow_up", "Up", 1, true),
        sy("right", "", "keyboard_arrow_right", "Right", 1, true)
    ]
    return [r1, r2, r3, r4, r5]
}

// The rows with every key's x and pixel width worked out:
// [{ units, width, keys: [{ ...key, x, width }] }]
function layout() {
    var rows = defs()
    var out = []
    for (var r = 0; r < rows.length; r++) {
        var x = 0
        var units = 0
        var keys = []
        for (var i = 0; i < rows[r].length; i++) {
            var d = rows[r][i]
            var w = d.w * (UNIT + GAP) - GAP
            var k = {}
            for (var p in d)
                k[p] = d[p]
            k.x = x
            k.width = w
            keys.push(k)
            x += w + GAP
            units += d.w
        }
        out.push({ units: units, width: x - GAP, keys: keys })
    }
    return out
}

function rowsWidth() {
    return COLS * (UNIT + GAP) - GAP
}

// ===== state =====

function initial() {
    return { shift: 0, caps: false, ctrl: false, alt: false, logo: false }
}

function copy(st) {
    return { shift: st.shift, caps: st.caps, ctrl: st.ctrl, alt: st.alt, logo: st.logo }
}

// 0 off, 1 armed (or on), 2 locked (Shift only).
function modState(st, id) {
    if (id === "shift")
        return st.shift
    if (id === "caps")
        return st.caps ? 1 : 0
    return st[id] ? 1 : 0
}

function modColor(id) {
    return MOD_COLORS[id] || MOD_COLORS.shift
}

// A press on a modifier key. Shift: off -> armed -> locked -> off.
function tapMod(st, id) {
    var n = copy(st)
    if (id === "shift")
        n.shift = (st.shift + 1) % 3
    else if (id === "caps")
        n.caps = !st.caps
    else if (id === "ctrl" || id === "alt" || id === "logo")
        n[id] = !st[id]
    return n
}

// After a key that is not a modifier: one-shot modifiers let go.
function afterKey(st) {
    var n = copy(st)
    if (n.shift === 1)
        n.shift = 0
    n.ctrl = false
    n.alt = false
    n.logo = false
    return n
}

function isLetter(key) {
    return key.kind === "char" && key.label.length === 1 && key.label >= "a" && key.label <= "z"
}

// Is Shift effectively on for this key? Caps only touches letters.
function shifted(key, st) {
    var s = st.shift > 0
    if (isLetter(key))
        return s !== st.caps
    return s
}

// What the key shows (and types): "A" or "a", "!" or "1".
function labelFor(key, st) {
    if (key.kind !== "char")
        return key.label
    return shifted(key, st) ? key.shifted : key.label
}

// The wtype command for one press.
//   plain character          wtype -- "A"
//   with Ctrl / Alt / Super  wtype -M ctrl -k c -m ctrl
//   Backspace, arrows...     wtype -k BackSpace   (Shift held: -M shift ...)
function command(key, st) {
    var mods = []
    if (st.ctrl)
        mods.push("ctrl")
    if (st.alt)
        mods.push("alt")
    if (st.logo)
        mods.push("logo")

    if (key.kind === "char" && mods.length === 0)
        return ["wtype", "--", labelFor(key, st)]

    var sh = key.kind === "char" ? shifted(key, st) : st.shift > 0
    if (sh)
        mods.unshift("shift")

    var argv = ["wtype"]
    for (var i = 0; i < mods.length; i++)
        argv.push("-M", mods[i])
    argv.push("-k", key.sym)
    for (var j = mods.length - 1; j >= 0; j--)
        argv.push("-m", mods[j])
    return argv
}
