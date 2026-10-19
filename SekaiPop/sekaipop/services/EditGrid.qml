pragma Singleton
import QtQuick
import Quickshell
import "../modules/common/functions/EditGridMath.js" as GM

// Edit Desktop's alignment grid: the state every part of it shares. One
// singleton, like EditMode, because the pieces live in different windows: each
// widget's own window knows where ITS card is (EditChrome.qml reports it and
// does the snapping), and one overlay window per monitor (EditGuides.qml)
// draws the grid and the guides above all of them.
//
// The story it tells, in order (`phase`):
//
//   idle      nothing shown.
//   drag      a card is being moved. The grid is up (EditGuides fades it in the
//             moment the drag starts), the card is pulled onto grid lines and
//             onto other widgets' lines (GM.snap), and guides for what it lines
//             up with right now are drawn lightly.
//   confirm   released. For ~1 s the guides are drawn at full strength with
//             their names (LEFT, TOP, CENTER ...), same-size widgets get a
//             bracket, and the widgets that line up with it flare.
//   fade      the guides and the grid ease out. Then idle.
//
// The maths is in EditGridMath.js (unit-tested with node, see
// tests/grid-test/). This file only keeps the state and the clock.
//
//   EditGrid.report(id, x, y, w, h, present)   every widget, always, while editing
//   EditGrid.begin(id)                          a drag started
//   EditGrid.snap(id, x, y, w, h, roomW, roomH) -> { x, y }   (call on every move)
//   EditGrid.end(id, x, y, w, h, roomW, roomH)  the drag ended
Singleton {
    id: root

    // ===== knobs =====
    property bool gridAlwaysOn: false

    // How long the confirmation stays at full strength, and how long the
    // fade-out takes (the overlay's own animations use `fadeMs`).
    readonly property int holdMs: 1000
    readonly property int fadeMs: 340
    // The four side lines of the dropped card live shorter than the rest of
    // the confirmation: this long at full strength, then a quick fade (the
    // overlay's own animation, 160 ms).
    readonly property int railMs: 380

    readonly property real cell: GM.CELL
    readonly property int major: GM.MAJOR
    readonly property int slotCount: 6

    // ===== state =====
    property string phase: "idle"
    property string dragId: ""

    // The guides. `slots` is a fixed-length array (entries are a line or null);
    // see GM.relations for what a line has.
    property var slots: [null, null, null, null, null, null]
    // Same-size brackets (confirm only): [{ axis: "w" | "h", value, ids, rects }]
    property var sizeMarks: []
    // The grid lines the dragged card sits on, and the corners they make.
    property var hits: ({ xs: [], ys: [], corners: [] })
    // Where the card was dropped, { x, y, w, h } (null while nothing is). The
    // overlay draws a line along each of its four sides while the phase is
    // confirm.
    property var dropRect: null
    // True from the drop until railMs is up.
    property bool railsLive: false

    // Bumped on release; the guides do their little stamp on it.
    property int confirmSerial: 0
    // Who lined up with the card that was just dropped (the card itself is not
    // in it): EditChrome.qml flares on `matchSerial`.
    property var matchedIds: ({})
    property int matchSerial: 0

    // ===== where the cards are =====
    property var rectsById: ({})

    function report(id, x, y, w, h, present) {
        if (id === "")
            return
        if (!present || w < 2 || h < 2) {
            delete root.rectsById[id]
            return
        }
        root.rectsById[id] = { id: id, x: x, y: y, w: w, h: h }
    }

    function othersOf(id) {
        const out = []
        for (const k in root.rectsById) {
            if (k !== id)
                out.push(root.rectsById[k])
        }
        return out
    }

    // ===== a drag =====
    function begin(id) {
        holdTimer.stop()
        fadeTimer.stop()
        root.dragId = id
        root.slots = [null, null, null, null, null, null]
        root.sizeMarks = []
        root.hits = { xs: [], ys: [], corners: [] }
        root.matchedIds = ({})
        root.dropRect = null
        railTimer.stop()
        root.railsLive = false
        // (forget what the last drag drew, or an identical first frame is skipped)
        root.liveSig = ""
        root.hitSig = ""
        root.phase = "drag"
    }

    // Where a card dragged to (x, y) really goes. Also updates the live
    // guides, so call it for every move, with the card's size.
    function snap(id, x, y, w, h, roomW, roomH) {
        const room = { w: roomW, h: roomH }
        const others = root.othersOf(id)
        const s = GM.snap({ id: id, x: x, y: y, w: w, h: h }, others, room)
        if (root.phase === "drag" && root.dragId === id)
            root.refreshLive({ id: id, x: s.x, y: s.y, w: w, h: h }, others, room)
        return { x: s.x, y: s.y }
    }

    property string liveSig: ""
    property string hitSig: ""

    function refreshLive(rect, others, room) {
        const rel = GM.relations(rect, others, room)
        const sig = GM.sig(rel.lines)
        if (sig !== root.liveSig) {
            root.liveSig = sig
            root.slots = GM.assignSlots(root.slots, rel.lines, root.slotCount)
        }
        const h = GM.gridHits(rect, room)
        const hs = h.xs.join(",") + "/" + h.ys.join(",")
        if (hs !== root.hitSig) {
            root.hitSig = hs
            root.hits = h
        }
    }

    function end(id, x, y, w, h, roomW, roomH) {
        if (root.phase !== "drag" || root.dragId !== id)
            return
        const room = { w: roomW, h: roomH }
        const others = root.othersOf(id)
        const rect = { id: id, x: x, y: y, w: w, h: h }
        const rel = GM.relations(rect, others, room)

        root.liveSig = GM.sig(rel.lines)
        root.slots = GM.assignSlots(root.slots, rel.lines, root.slotCount)

        const hh = GM.gridHits(rect, room)
        root.hitSig = hh.xs.join(",") + "/" + hh.ys.join(",")
        root.hits = hh

        // Same-size brackets, with the rectangles they hug.
        const marks = []
        for (const z of rel.sizes) {
            const rs = []
            for (const zid of z.ids) {
                if (zid === id)
                    rs.push(rect)
                else if (root.rectsById[zid])
                    rs.push(root.rectsById[zid])
            }
            marks.push({ axis: z.axis, value: z.value, ids: z.ids, rects: rs, mine: id })
        }
        root.sizeMarks = marks

        // Everybody who took part, for the flare.
        const m = {}
        for (const l of rel.lines) {
            for (const lid of l.ids) {
                if (lid !== id)
                    m[lid] = true
            }
        }
        for (const z of rel.sizes) {
            for (const zid of z.ids) {
                if (zid !== id)
                    m[zid] = true
            }
        }
        root.matchedIds = m

        // The four side lines are drawn on every drop, so every drop gets the
        // full second.
        root.dropRect = { x: x, y: y, w: w, h: h }
        root.railsLive = true
        railTimer.interval = root.railMs
        railTimer.restart()
        root.phase = "confirm"
        root.confirmSerial = root.confirmSerial + 1
        if (Object.keys(m).length > 0)
            root.matchSerial = root.matchSerial + 1
        holdTimer.interval = root.holdMs
        holdTimer.restart()
    }

    function reset() {
        holdTimer.stop()
        fadeTimer.stop()
        root.phase = "idle"
        root.dragId = ""
        root.liveSig = ""
        root.hitSig = ""
        root.slots = [null, null, null, null, null, null]
        root.sizeMarks = []
        root.hits = { xs: [], ys: [], corners: [] }
        root.matchedIds = ({})
        root.dropRect = null
        railTimer.stop()
        root.railsLive = false
    }

    Timer {
        id: railTimer
        interval: root.railMs
        onTriggered: root.railsLive = false
    }

    Timer {
        id: holdTimer
        interval: root.holdMs
        onTriggered: {
            root.phase = "fade"
            fadeTimer.restart()
        }
    }

    Timer {
        id: fadeTimer
        interval: root.fadeMs + 40
        onTriggered: root.reset()
    }

    // Done (or anything that ends the mode) wipes it all at once.
    Connections {
        target: EditMode

        function onActiveChanged() {
            if (!EditMode.active) {
                root.rectsById = ({})
                root.reset()
            }
        }
    }
}
