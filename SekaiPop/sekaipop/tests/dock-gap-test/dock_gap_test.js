// A pinned dock leaves the same gap to the windows in every dock style.
// Quickshell can't run here, so this repeats the formulas of Dock.qml (pinnedTrim, the zone
// Binding) and of the compositor (reserved = zone + the layer's margin; windows stop
// gaps_out past that), and checks the Dock.qml text still has them.
const assert = require("assert"), fs = require("fs"), path = require("path")
const src = fs.readFileSync(path.join(__dirname, "..", "..", "modules", "sekai", "dock", "Dock.qml"), "utf8")

function windowsGap({ look, indicators, scale = 1, gapsOut = 14, wanted = 8, icon = 35, flat = false }) {
    const padV = 11 + (indicators ? 6 : 0)
    const strip = Math.round((icon + padV * 2 + (flat ? 4 : 0)) * scale)
    const margin = Math.round(14 * scale)
    const invisible = look === "transparent" ? padV : 0
    const trim = Math.max(0, gapsOut) - Math.round(wanted * scale) + Math.round(invisible * scale)
    const zone = Math.max(1, strip - trim)
    const windowsStop = zone + margin + gapsOut             // from the screen edge
    const visibleEdge = margin + strip - Math.round(invisible * scale)
    return windowsStop - visibleEdge
}

// the screenshot: standing dock, 35 px keys with the dots on, gaps_out 14, scale 1
for (const look of ["float", "transparent", "capsule"])
    for (const indicators of [true, false])
        for (const flat of [false, true])
            assert.strictEqual(windowsGap({ look, indicators, flat }), 8, `${look} indicators=${indicators} flat=${flat}`)

// other gaps_out and scales: the gap is the wanted one (a little rounding at odd scales)
for (const gapsOut of [0, 5, 14, 30])
    for (const scale of [0.8, 1, 1.5])
        for (const look of ["float", "transparent", "capsule"]) {
            const g = windowsGap({ look, indicators: true, scale, gapsOut })
            const want = Math.round(8 * scale)
            // a gaps_out bigger than the strip can't be taken off: the zone stops at 1 and the gap is bigger
            assert.ok(Math.abs(g - want) <= 2 || g > want, `${look} gaps_out ${gapsOut} scale ${scale}: ${g}`)
        }

// what Dock.qml does must match: no edgeMargin in the zone, transparent takes its padding off
const zone = src.match(/property:\s*"exclusiveZone"\s*value:\s*([^\n]+)/)
assert.ok(zone, "the exclusiveZone Binding is there")
assert.ok(!zone[1].includes("edgeMargin"), "the zone must not add the margin the compositor already adds")
assert.ok(zone[1].includes("stripSize") && zone[1].includes("pinnedTrim"))
assert.ok(/pinnedInvisible:\s*dockWindow\.look === "transparent" \? dockWindow\.pillPaddingV : 0/.test(src))
assert.ok(/pinnedWindowGap:\s*8\b/.test(src))
console.log("dock_gap_test: all checks passed")
