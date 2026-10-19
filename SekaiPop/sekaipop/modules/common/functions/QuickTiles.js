.pragma library

// The Quick Panel's button grid: which buttons exist, how big each size
// is, and how a list of them flows into rows. Shared by QuickSource.qml
// (remembers the list, refuses an add that wouldn't fit) and
// QuickPanelFace.qml (draws it), so both agree on what "full" means.
//
// A tile is { id, size } with size "small", "big" or "long" — 1, 2 or 3
// columns wide. They flow left to right, wrapping when the next one wouldn't
// fit — the same 514px the old fixed rows spanned (five columns):
//
//   small   74 wide, 75 tall. 1 column. Icon only. Microphone / Speaker: a
//           mute button (the slider is what the bigger sizes add).
//   big    200 wide. 2 columns. Most buttons: icon + name + status (75 tall).
//          Microphone / Speaker: the volume slider (97 tall).
//   long   294 wide. 3 columns. The same as big, just longer: more room for
//          the name/status, a longer slider.
//
// A row is as tall as its tallest button (so a row with a slider is 97,
// and the other buttons in it sit centred against it); the grid can grow
// until maxHeight. The default list lands exactly on the old layout, plus
// Night Light and Game Mode on a third row.

// Every button that can live on the panel. Order here is only the order
// the "add" tray lists the unused ones in.
var catalog = ["network", "bluetooth", "keepAwake", "microphone", "speaker",
               "notifications", "nightLight", "gameMode",
               "darkMode", "easyEffects", "warp", "screenSnip", "colorPicker",
               "keyboard", "powerProfile", "musicRecognition", "antiFlashbang"]

// Buttons that do something once and have no on/off of their own (Screen
// Snip, Color Picker): a click closes the panel first, then runs.
function isAction(id) {
    return id === "screenSnip" || id === "colorPicker"
}

var defaultTiles = [
    { id: "network", size: "big" },
    { id: "bluetooth", size: "big" },
    { id: "keepAwake", size: "small" },
    { id: "microphone", size: "big" },
    { id: "speaker", size: "big" },
    { id: "notifications", size: "small" },
    { id: "nightLight", size: "small" },
    { id: "gameMode", size: "small" }
]

var contentWidth = 514   // 67 .. 581 in the face's coordinates
var bigWidth = 200
var smallWidth = 74
var longWidth = 294      // big + a small's slot: long + big fills the 514 exactly
var gap = 20             // between buttons in a row
var rowGap = 12          // between rows
var baseHeight = 75
var sliderHeight = 97
var baseGridHeight = 184 // the old fixed layout: 75 + 12 + 97 — the panel's own layout assumes it
var maxHeight = 380      // beyond this the notifications card would get too short

// How many buttons a row may hold (edit mode's "Columns" setting), whatever
// their size. 5 is also the most that can physically fit — five small
// buttons fill 450 of the 514px, a sixth wouldn't — so the default of 5 is
// the old width-only flow. Fewer columns wrap sooner; widths don't change,
// so a 2-column row of two big buttons still leaves its right edge free.
var minColumns = 1
var maxColumns = 5
var defaultColumns = 5

function clampColumns(columns) {
    var c = Math.round(Number(columns))
    if (isNaN(c))
        return defaultColumns
    return Math.max(minColumns, Math.min(maxColumns, c))
}

function isSlider(id) {
    return id === "microphone" || id === "speaker"
}

function widthOf(size) {
    return size === "long" ? longWidth : (size === "big" ? bigWidth : smallWidth)
}

// How many columns a size takes.
function unitsOf(size) {
    return size === "long" ? 3 : (size === "big" ? 2 : 1)
}

function heightOf(tile) {
    return isSlider(tile.id) && tile.size !== "small" ? sliderHeight : baseHeight
}

// The size the resize badge switches the button at `index` to: small ->
// big -> long -> small, skipping any size that wouldn't fit under the row
// limit (small always does). Returns the current size when nothing else
// fits, so `nextSize(...) === current` means "can't resize".
function nextSize(tiles, index, columns) {
    var order = ["small", "big", "long"]
    var cur = tiles[index].size
    for (var step = 1; step < order.length; step++) {
        var candidate = order[(order.indexOf(cur) + step) % order.length]
        var list = tiles.map(function (t) { return { id: t.id, size: t.size } })
        list[index].size = candidate
        if (fits(list, columns))
            return candidate
    }
    return cur
}

// -> { slots, rows, height }
// slots[i] = { x, y, w, rowH, oy, row } for tiles[i]: x and y are the row's
// left edge and top, measured from the grid's top-left; w is how wide the
// button is drawn; oy is how far down inside the row the button itself
// sits (centres it against a taller neighbour, or with `topAlign` lines it
// up with it, see below); rowH is the row's height.
//
// `topAlign` (the Quick Panel's 2D look): a button next to a volume slider is
// level with the slider's pill instead of centred against the whole slider
// (pill + its bar underneath), which put a round button (the bell next to the
// Microphone and Speaker) 11px lower than the pills beside it. The round
// ones keep the 2px they sit low in any row.
//
// Responsive: a row that is full — every row but the last, or the last one
// when it holds `columns` buttons — stretches its buttons (in proportion to
// their size) to fill the whole 514px. Two big buttons in a 2-column row are
// 247 wide each, five small ones in a 5-column row 86.8 (rounded). The last
// row, when it has room left, keeps the natural widths.
function pack(tiles, columns, topAlign) {
    var cols = clampColumns(columns === undefined ? maxColumns : columns)
    var slots = []
    var rowHeights = []
    var rowMembers = []
    var x = 0
    var row = 0
    var inRow = 0   // buttons so far in this row
    for (var i = 0; i < tiles.length; i++) {
        var w = widthOf(tiles[i].size)
        if (x > 0 && (x + w > contentWidth || inRow >= cols)) {
            row++
            x = 0
            inRow = 0
        }
        slots.push({ x: 0, w: w, row: row })
        rowMembers[row] = (rowMembers[row] || [])
        rowMembers[row].push(i)
        rowHeights[row] = Math.max(rowHeights[row] || 0, heightOf(tiles[i]))
        x += w + gap
        inRow++
    }
    for (var r0 = 0; r0 < rowMembers.length; r0++) {
        var members = rowMembers[r0]
        var n = members.length
        var baseSum = 0
        for (var m = 0; m < n; m++)
            baseSum += slots[members[m]].w
        var full = r0 < rowMembers.length - 1 || n >= cols
        var factor = full ? (contentWidth - gap * (n - 1)) / baseSum : 1
        var done = 0      // base width handled so far
        var used = 0      // drawn width handed out so far
        var rx = 0
        for (var k = 0; k < n; k++) {
            var slot = slots[members[k]]
            done += slot.w
            var drawn = Math.round(done * factor) - used
            used += drawn
            slot.x = rx
            slot.w = drawn
            rx += drawn + gap
        }
    }
    var rowY = []
    var y = 0
    for (var r = 0; r < rowHeights.length; r++) {
        rowY.push(y)
        y += rowHeights[r] + rowGap
    }
    for (var j = 0; j < slots.length; j++) {
        var rh = rowHeights[slots[j].row]
        var th = heightOf(tiles[j])
        slots[j].y = rowY[slots[j].row]
        slots[j].rowH = rh
        // The round buttons sit 2px low in a plain row (as in the Figma
        // frames); in a taller row everything is just centred.
        slots[j].oy = topAlign
            ? (tiles[j].size === "small" ? 2 : 0)
            : Math.floor((rh - th) / 2)
              + (rh === baseHeight && tiles[j].size === "small" ? 2 : 0)
    }
    return { slots: slots, rows: rowHeights.length, height: rowHeights.length === 0 ? 0 : y - rowGap }
}

function fits(tiles, columns) {
    return pack(tiles, columns).height <= maxHeight
}

// Turn whatever was read from disk into a safe list: known ids only, no
// repeats, valid sizes, and never taller than the panel can spare.
function sanitize(list, columns) {
    var seen = {}
    var out = []
    for (var i = 0; i < list.length; i++) {
        var t = list[i]
        if (!t || catalog.indexOf(t.id) < 0 || seen[t.id])
            continue
        seen[t.id] = true
        out.push({ id: t.id, size: (t.size === "big" || t.size === "long") ? t.size : "small" })
    }
    while (out.length > 0 && !fits(out, columns))
        out.pop()
    return out
}
