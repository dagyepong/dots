// node tests/capsule-test/capsule_source_test.js   (run from the sekaipop folder)
// Quickshell can't be run here, so this reads the source to check the Capsule bar
// style is wired in everywhere a style has to be, and that its numbers are the
// ones measured off the reference screenshot.
//   1. the style exists (service, both pickers, the preview glyph);
//   2. Bar.qml gives it a slim strip (a flat one and a standing one), its own inset /
//      edge gap / height, and draws it on a standing bar too (chips stacked);
//   3. Status_Bar.qml turns `capsuleBar` on for it, hides the old background, and
//      draws the rim + body + hard shadow;
//   4. the shared widgets (Pill, MaterialIcon, WorkspaceBadges) ask Theme.capsuleFor;
//   5. the geometry matches the reference: 36 bar = 3 + 30 + 3, 3 shadow, 18 dots
//      (12 + 3 + 3), 34 active, 21 chip, 6 gaps.
const assert = require("assert"), fs = require("fs"), path = require("path")
const top = path.join(__dirname, "..", "..")
const read = rel => fs.readFileSync(path.join(top, rel), "utf8")
const code = s => s.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:"'])\/\/.*$/gm, "$1")
const num = (src, name) => {
    const m = new RegExp("readonly property (?:real|int) " + name + ":\\s*([0-9.]+)").exec(src)
    assert(m, "Theme." + name + " not found")
    return Number(m[1])
}

// 1. the style exists
const svc = code(read("services/BarStyleService.qml"))
assert(/names:\s*\["float", "straight", "transparent", "capsule"\]/.test(svc), "BarStyleService.names")
for (const f of ["modules/sekai/settings/SettingsPageBar.qml", "modules/sekai/settings/SettingsPageQuick.qml"])
    assert(/id: "capsule", label: "Capsule", edge: "top", variant: "capsule"/.test(read(f)), f + " has no Capsule option")
assert(/variant === "capsule"/.test(read("modules/sekai/quickPanel/ScreenGlyph.qml")), "ScreenGlyph draws no capsule")

// 2. Bar.qml
const bar = code(read("modules/sekai/bar/Bar.qml"))
assert(/win\.barStyle === 3 \? \(win\.vertical \? Theme\.capStripV : Theme\.capStrip\)/.test(bar), "slim strip, flat and standing")
assert(/readonly property int barStyle: BarStyleService\.index\b/.test(bar), "Capsule is drawn on a standing bar too, not as Float")
assert(/win\.barStyle === 3 \? Theme\.capVBarFace : Theme\.barVBody/.test(bar), "standing bar width")
assert(/win\.barStyle === 0 \|\| win\.barStyle === 3\) \? Theme\.barFloatInset/.test(bar), "side inset")
assert(/win\.barStyle === 3 \? Theme\.capEdgeGap/.test(bar), "edge gap")
assert(/win\.barStyle === 3 \? Theme\.capBarHeight : 61/.test(bar), "bar height")

// 3. Status_Bar.qml
const sb = code(read("modules/sekai/bar/Status_Bar.qml"))
assert(/readonly property bool capsule: status_Bar\.barStyle === 3\s/.test(sb), "capsule flag (any edge)")
assert(/readonly property bool capsuleVertical: status_Bar\.capsule && status_Bar\.vertical/.test(sb), "capsuleVertical marker")
assert(/readonly property bool capsuleBar: status_Bar\.capsule/.test(sb), "capsuleBar marker")
assert(/status_Bar\.barStyle === 2 \|\| status_Bar\.capsule\) \? 0 : 1/.test(sb), "old background not hidden")
for (const t of ["Theme.capShade", "Theme.capRim", "Theme.capBody"]) assert(sb.includes(t), "capsule layer lacks " + t)

// 4. the widgets that redraw themselves
const th = code(read("modules/common/Theme.qml"))
assert(/function capsuleFor\(item\)/.test(th) && /p\.capsuleBar === true/.test(th), "Theme.capsuleFor")
for (const f of ["modules/common/widgets/Pill.qml", "modules/common/widgets/MaterialIcon.qml", "modules/sekai/bar/WorkspaceBadges.qml"])
    assert(code(read(f)).includes("Theme.capsuleFor(root)"), f + " does not ask Theme.capsuleFor")

// 5. the measured numbers
const want = { capBarFace: 36, capBarHeight: 39, capRimWidth: 3, capShadowDy: 3, capDotFill: 12, capDotRing: 3,
    capChipHeight: 21, capGap: 6, capEdgeGap: 8, capStrip: 55, capPadX: 7 }
for (const k of Object.keys(want)) assert.strictEqual(num(th, k), want[k], "Theme." + k)
assert.strictEqual(num(th, "capBarFace") + num(th, "capShadowDy"), num(th, "capBarHeight"), "face + shadow = bar")
assert.strictEqual(num(th, "capBarFace") - 2 * num(th, "capRimWidth"), 30, "body is 30")
assert.strictEqual(num(th, "capEdgeGap") * 2 + num(th, "capBarHeight"), num(th, "capStrip"), "strip = gap + bar + gap")
assert(/capDot: capDotFill \+ 2 \* capDotRing/.test(th) && /capDotActive: 28 \+ 2 \* capDotRing/.test(th), "dot sizes")
// the standing bar: 40 chip + 2 x (3 rim + 5) = 56 face, 8 + 56 + 8 = 72 strip, one pillar of the same colours
const wantV = { capVChip: 40, capVPadX: 5, capVPadY: 8 }
for (const k of Object.keys(wantV)) assert.strictEqual(num(th, k), wantV[k], "Theme." + k)
assert(/capVBarFace: capVChip \+ 2 \* \(capRimWidth \+ capVPadX\)/.test(th), "standing face")
assert(/capStripV: capEdgeGap \* 2 \+ capVBarFace/.test(th), "standing strip")
assert(/function capsuleVerticalFor\(item\)/.test(th) && /p\.capsuleVertical === true/.test(th), "Theme.capsuleVerticalFor")
const pillSrc = code(read("modules/common/widgets/Pill.qml"))
assert(/readonly property bool capsuleV: root\.capsule && Theme\.capsuleVerticalFor\(root\)/.test(pillSrc), "Pill.capsuleV")
assert(/readonly property real barVWidth: root\.capsule \? Theme\.capVChip : Theme\.barVPillWidth/.test(pillSrc), "Pill.barVWidth")
// every pill of a standing bar takes its width from the Pill, so a chip is capVChip wide
for (const f of ["BatteryIndicator", "WeatherIndicator", "DateIndicator", "ResourceIndicator", "StatusPill", "PrivacyIndicator", "DiscordPill"])
    assert(!/Theme\.barVPillWidth/.test(code(read("modules/sekai/bar/" + f + ".qml"))) && /pill\.barVWidth/.test(code(read("modules/sekai/bar/" + f + ".qml"))), f + " vertical width")
assert(/bar\.barVWidth/.test(code(read("modules/sekai/bar/UtilButtons.qml"))), "UtilButtons vertical width")
assert(/clockPill\.barVWidth/.test(sb), "clock vertical width")
assert(/Theme\.capVChip/.test(code(read("modules/sekai/bar/MediaPill.qml"))), "media chip width")
// the workspace dots stack in a column on a standing bar
const wsb = code(read("modules/sekai/bar/WorkspaceBadges.qml"))
assert(/Grid \{\s*id: dotRow/.test(wsb) && /columns: root\.vertical \? 1/.test(wsb), "dots are a row or a column")
assert(/height: dot\.isActive && root\.vertical \? Theme\.capDotActive : Theme\.capDot/.test(wsb), "active dot is tall on a standing bar")
// the standing bar's rim, body and shadow round by the shorter side
assert(/Math\.min\(width, height\) \/ 2/.test(sb), "capsule layer rounds by the shorter side")
// the body fits the dots with 6 above and below, as in the reference
assert.strictEqual((30 - (12 + 2 * 3)) / 2, 6, "6 px above and below the dots")
assert(/capLit: accentCyan/.test(th) && /capLitSoft: Qt\.color\(pal\.glint\)/.test(th), "lit colours come from the theme")
// the workspace dots follow the active theme, not a fixed palette
// (Monochrome swaps the five for greys through Theme.attributeColors; every other theme keeps the five below)
assert(/capWsColors: mono\s*\?\s*attributeColors\.map\(c => Qt\.color\(c\)\)\s*:\s*\[capLit, capLitSoft, accentMint,\s*Qt\.color\(pal\.wallLight\), Qt\.color\(pal\.divider\)\]/.test(th), "workspace dot colours come from the theme")
assert(/Theme\.capWsColors\[dot\.index % Theme\.capWsColors\.length\]/.test(wsb), "the dots use the theme's colours")
assert(!/capDotColors/.test(wsb), "no fixed dot palette left in the workspace badges")
// the dock's lit keys and running dots follow the theme too: no fixed pastel left anywhere
for (const f of ["modules/sekai/dock/Dock.qml", "modules/sekai/dock/DockRunDot.qml", "modules/common/Theme.qml"])
    assert(!/capDotColors|#FAA8E1|#C1B3D6/i.test(read(f)), f + " has no fixed capsule pastel")
assert(/Theme\.capLit\b/.test(read("modules/sekai/dock/DockRunDot.qml")) && /Theme\.capLitSoft/.test(read("modules/sekai/dock/DockRunDot.qml")), "run dot uses the theme colours")

console.log("capsule source test: ok")
