// node tests/capsule-test/capsule_popup_test.js   (run from the sekaipop folder)
// Quickshell can't be run here, so this reads the source to check that the bar's popup
// cards take the Capsule bar's colours: outline = capRim, hard shadow = capShade, ring and
// fill = capBody, and only while the bar is in the Capsule style.
const assert = require("assert"), fs = require("fs"), path = require("path")
const top = path.join(__dirname, "..", "..")
const read = rel => fs.readFileSync(path.join(top, rel), "utf8")
const code = s => s.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:"'])\/\/.*$/gm, "$1")
const balanced = (f, s) => { for (const [a, b] of [["{", "}"], ["(", ")"], ["[", "]"]])
    assert.strictEqual(s.split(a).length, s.split(b).length, f + ": " + a + b + " unbalanced") }

const files = ["modules/common/widgets/Pill.qml", "modules/sekai/bar/SekaiPopup.qml", "modules/sekai/bar/TrayPopups.qml"]
for (const f of files) balanced(f, code(read(f)))

// Pill: the new switch, off by default, and every layer of the card reads it
const pill = code(read(files[0]))
assert(/property bool capRim: false/.test(pill), "Pill.capRim default")
for (const t of ["root.capRim ? Theme.capShade", "root.capRim ? Theme.capRim", "root.capRim ? Theme.capBody : root.ringColorTop",
                 "root.capRim ? Theme.capBody : root.ringColorBottom", "root.capRim ? Theme.capBody"])
    assert(pill.includes(t), "Pill lacks: " + t)
// the in-bar chip path is untouched
assert(/root\.capsule\s*\?\s*\(root\.capKeepsFill \? root\.fillColor : Theme\.capChip\)/.test(pill), "chip fill changed")

// SekaiPopup: on only for barStyle 3, handed to the card Pill (not to `bare` cards)
const sp = code(read(files[1]))
assert(/capsuleStyle: !!host\.parentWindow && host\.parentWindow\.barStyle === 3/.test(sp), "SekaiPopup flag")
assert(/capRim: host\.capsuleStyle/.test(sp), "SekaiPopup card")
assert(!/capsuleBar/.test(sp), "SekaiPopup must not set capsuleBar (that would turn inner pills into chips)")

// Tray: dropdown + menu card
const tp = code(read(files[2]))
assert(/capsuleStyle: !!root\.parentWindow && root\.parentWindow\.barStyle === 3/.test(tp), "TrayPopups flag")
assert((tp.match(/capRim: root\.capsuleStyle/g) || []).length === 2, "dropdown and menu both take it")

// Bar.qml reports 3 only for a flat bar, and hands its window to the popups
const bar = code(read("modules/sekai/bar/Bar.qml"))
assert(/readonly property int barStyle: BarStyleService\.index\b/.test(bar), "barStyle reports 3 on any edge")
assert(/win\.barStyle === 3 \? 0 : 4/.test(bar), "popup gap beside a standing capsule bar")
console.log("capsule popup test: ok")
