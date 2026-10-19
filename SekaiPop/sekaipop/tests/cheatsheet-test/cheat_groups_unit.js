// node tests/cheatsheet-test/cheat_groups_unit.js   (run from the sekaipop folder)
// Hyprland's Lua config reports every bind as "__lua", so the cheat sheet groups binds by their
// "Group: sentence" description. This checks that, the folding of rows, and the "(more)" marker.
const fs = require("fs")
const locate = require("../lib/locate.js")
const src = fs.readFileSync(locate("modules/sekai/cheatSheet/CheatBinds.js"), "utf8").replace(".pragma library", "")
const CB = new Function(src + "; return { build, lastHidden }")()

let fails = 0
function eq(a, b, msg) {
    const x = JSON.stringify(a), y = JSON.stringify(b)
    if (x !== y) { fails++; console.log("FAIL " + msg + "\n   got  " + x + "\n   want " + y) }
}
const SUPER = 64, SHIFT = 1, CTRL = 4
let n = 0
const bind = (key, modmask, description, extra) => Object.assign({
    dispatcher: "__lua", arg: String(++n), key, modmask, has_description: description !== undefined,
    description: description || "", mouse: false, submap: "", release: false }, extra || {})

const binds = [
    bind("Q", SUPER, "Windows: Close window"),
    bind("Left", SUPER, "Windows: Focus window in direction"),
    bind("Right", SUPER, "Windows: Focus window in direction"),
    bind("Up", SUPER, "Windows: Focus window in direction"),
    bind("Down", SUPER, "Windows: Focus window in direction"),
    ...["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map(k => bind(k, SUPER, "Workspaces: Focus workspace # (1-10)")),
    bind("Page_Down", SUPER, "Workspaces: Focus workspace left/right"),
    bind("Page_Up", SUPER, "Workspaces: Focus workspace left/right"),
    bind("mouse_down", SUPER, "Workspaces: Focus workspace left/right"),
    bind("mouse_up", SUPER, "Workspaces: Focus workspace left/right"),
    bind("Return", SUPER, "Apps: Terminal"),
    bind("T", SUPER, "Apps (more): Terminal"),
    bind("L", SUPER, "Session: Lock screen"),
    bind("N", SUPER, "Shell: Toggle quick panel"),
    bind("W", CTRL, "Shell (more): Welcome tour"),
    bind("S", SUPER | SHIFT, "Utilities: Screen snip"),
    bind("XF86AudioMute", 0),                       // hardware key, no description
    bind("F4", 8),                                  // no description: stays out of the short list
    bind("X", SUPER, "Not a group: something"),     // unknown prefix: older rules, ends in Other
    bind("Z", SUPER, "Windows: inside a submap", { submap: "vm" }),
]
const raw = JSON.stringify(binds)

const rowsOf = notes => {
    const o = {}
    notes.forEach(nt => { const g = nt.title.replace(/ \(\d+\)$/, ""); (o[g] = o[g] || []).push(...nt.rows.map(r => r.caps.join(" ") + " | " + r.label)) })
    return o
}

// short list
const short = rowsOf(CB.build(raw, false, false))
eq(short.Windows, ["Q | Close window", "←/↑/→/↓ | Focus window in direction"], "windows rows (arrows fold, submap skipped)")
eq(short.Workspaces, ["# | Focus workspace # (1-10)", "PgUp/Dn | Focus workspace left/right", "Wheel↑/↓ | Focus workspace left/right"],
   "workspaces: 1..0 fold to #, PgUp/Dn and the wheel stay separate rows")
eq(short.Apps, ["Enter | Terminal"], "the (more) terminal key is not in the short list")
eq(short.Session, ["L | Lock screen"], "session")
eq(short.Shell, ["N | Toggle quick panel"], "shell, (more) hidden")
eq(short.Utilities, ["S | Screen snip"], "utilities")
eq(short.Media, undefined, "hardware key without a description stays out of the short list")
eq(short.Other && short.Other.length, 1, "an unknown prefix still lands in Other (kept as before)")
eq(CB.lastHidden() > 0, true, "something is counted as hidden")

// everything
const all = rowsOf(CB.build(raw, false, true))
eq(all.Apps, ["Enter | Terminal", "T | Terminal"], "show all: the (more) terminal key comes back")
eq(all.Shell, ["N | Toggle quick panel", "W | Welcome tour"], "show all: shell (more)")
eq(all.Media, ["Mute | Mute / unmute"], "show all: hardware key named by the key")

// shell-only mode still sees both spellings of a Shell description
const shellOnly = rowsOf(CB.build(raw, true, true))
eq(shellOnly.Shell, ["N | Toggle quick panel", "W | Welcome tour"], "shellOnly keeps Shell and Shell (more)")
eq(Object.keys(shellOnly), ["Shell"], "shellOnly shows nothing else")

console.log(fails ? fails + " FAILED" : "cheatsheet group tests: all passed")
process.exit(fails ? 1 : 0)
