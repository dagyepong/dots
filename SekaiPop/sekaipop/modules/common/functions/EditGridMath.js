.pragma library

// The maths behind Edit Desktop's alignment grid (services/EditGrid.qml draws
// nothing; EditGuides.qml draws it). Pure functions on plain numbers, in
// DESIGN pixels (the same space the widget cards' x / y / width / height are
// in), so it can be unit-tested with node: tests/grid-test/grid_unit.js.
//
// A "rect" is { id, x, y, w, h }. `room` is { w, h }: the screen as the cards
// see it (real size / the monitor's UI scale).
//
// What a widget has, on each axis, is three lines:
//
//     x:  left  (L)     centre (C)     right (R)
//     y:  top   (T)     centre (C)     bottom (B)
//
// Two widgets are "aligned" when one of their lines is the same. Edges only
// pair with edges and centres with centres: a widget's middle lining up with
// another's edge is not what anyone is after.

// One cell of the grid. 20 divides 1920 x 1080 exactly (96 x 54 cells), and
// the other common sizes (2560 x 1440, 3840 x 2160) too. (It used to be 40;
// every second line here is one of the old ones.)
var CELL = 20

// Every MAJOR-th line is drawn stronger, with a big diamond where two meet:
// 8 x 20 = a bar every 160 px, the same spacing the old 40-px grid had.
var MAJOR = 8

// How close (design px) an edge has to come to be pulled onto something.
// Widgets win over the grid when both are in range. The grid's pull is under
// half a cell, so there is still free room between two lines.
var PULL_WIDGET = 10
var PULL_GRID = 7

// Two lines count as the same when they are this close (design px).
var TOL = 1.0

// How far a guide line runs past the widgets it joins.
var OVERHANG = 22

function near(a, b) {
    return Math.abs(a - b) <= TOL
}

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v))
}

// ===== snapping =====

function targets(axis, others, room) {
    var edges = []
    var centres = []
    var size = axis === "x" ? room.w : room.h
    // The screen: its edges and its middle.
    edges.push(0)
    edges.push(size)
    centres.push(size / 2)
    for (var i = 0; i < others.length; i++) {
        var o = others[i]
        var p = axis === "x" ? o.x : o.y
        var s = axis === "x" ? o.w : o.h
        edges.push(p)
        edges.push(p + s)
        centres.push(p + s / 2)
    }
    return { edges: edges, centres: centres }
}

// One pull. Returns { pos, kind } with kind "widget", "grid" or "" (nothing in
// reach).
function snapOnce(pos, size, tg, maxPos) {
    var best = null
    var i
    var d

    // Another widget's (or the screen's) lines first.
    for (i = 0; i < tg.edges.length; i++) {
        d = tg.edges[i] - pos
        if (Math.abs(d) <= PULL_WIDGET && (best === null || Math.abs(d) < Math.abs(best)))
            best = d
        d = tg.edges[i] - (pos + size)
        if (Math.abs(d) <= PULL_WIDGET && (best === null || Math.abs(d) < Math.abs(best)))
            best = d
    }
    for (i = 0; i < tg.centres.length; i++) {
        d = tg.centres[i] - (pos + size / 2)
        if (Math.abs(d) <= PULL_WIDGET && (best === null || Math.abs(d) < Math.abs(best)))
            best = d
    }
    if (best !== null)
        return { pos: clamp(pos + best, 0, maxPos), kind: "widget" }

    // Then the grid: whichever of the two edges is nearer a grid line.
    var edgesNow = [pos, pos + size]
    for (i = 0; i < edgesNow.length; i++) {
        d = Math.round(edgesNow[i] / CELL) * CELL - edgesNow[i]
        if (Math.abs(d) <= PULL_GRID && (best === null || Math.abs(d) < Math.abs(best)))
            best = d
    }
    if (best !== null)
        return { pos: clamp(pos + best, 0, maxPos), kind: "grid" }

    return { pos: pos, kind: "" }
}

// Where `pos` (a widget's left or top, `size` long) ends up on one axis.
//
// A pull can carry the widget into reach of something that pulls harder (a
// grid pull that lands it 8 px from the screen's edge, say). So it pulls again
// until it stops: the answer is a place that pulls nothing further, and
// snapping the answer again changes nothing. That is what lets EditChrome.qml
// run it on whatever position the drag just left the card in.
function snapAxis(pos, size, tg, maxPos) {
    var cur = pos
    var kind = ""
    for (var i = 0; i < 4; i++) {
        var r = snapOnce(cur, size, tg, maxPos)
        if (r.kind === "" || Math.abs(r.pos - cur) < 1e-9) {
            if (kind === "")
                kind = r.kind
            break
        }
        // The kind that matters is the one it settled on.
        kind = r.kind
        cur = r.pos
    }
    return { pos: cur, kind: kind }
}

// Snaps a dragged rect. Returns { x, y, kindX, kindY }.
function snap(rect, others, room) {
    var tx = targets("x", others, room)
    var ty = targets("y", others, room)
    var sx = snapAxis(rect.x, rect.w, tx, Math.max(0, room.w - rect.w))
    var sy = snapAxis(rect.y, rect.h, ty, Math.max(0, room.h - rect.h))
    return { x: sx.pos, y: sy.pos, kindX: sx.kind, kindY: sy.kind }
}

// ===== the grid lines a rect sits on =====

function gridHits(rect, room) {
    var xs = []
    var ys = []
    var cand
    var i
    cand = [rect.x, rect.x + rect.w]
    for (i = 0; i < cand.length; i++) {
        var gx = Math.round(cand[i] / CELL) * CELL
        if (Math.abs(gx - cand[i]) <= 0.5 && gx > 0 && gx < room.w)
            xs.push(gx)
    }
    cand = [rect.y, rect.y + rect.h]
    for (i = 0; i < cand.length; i++) {
        var gy = Math.round(cand[i] / CELL) * CELL
        if (Math.abs(gy - cand[i]) <= 0.5 && gy > 0 && gy < room.h)
            ys.push(gy)
    }
    var corners = []
    for (var a = 0; a < xs.length; a++)
        for (var b = 0; b < ys.length; b++)
            corners.push({ x: xs[a], y: ys[b] })
    return { xs: xs, ys: ys, corners: corners }
}

// ===== alignment =====

function relations(rect, others, room) {
    var lines = []
    var sizes = []
    var all = others.concat([{ id: "@screen", x: 0, y: 0, w: room.w, h: room.h, screen: true }])
    var axes = ["x", "y"]

    for (var ai = 0; ai < axes.length; ai++) {
        var ax = axes[ai]
        var vertical = ax === "x"
        var mp = vertical ? rect.x : rect.y
        var ms = vertical ? rect.w : rect.h
        // The rect's own three lines on this axis.
        var mine = [
            { side: vertical ? "L" : "T", v: mp, c: false },
            { side: "C", v: mp + ms / 2, c: true },
            { side: vertical ? "R" : "B", v: mp + ms, c: false }
        ]

        for (var mi = 0; mi < mine.length; mi++) {
            var m = mine[mi]
            var group = []
            var same = false
            for (var oi = 0; oi < all.length; oi++) {
                var o = all[oi]
                var op = vertical ? o.x : o.y
                var os = vertical ? o.w : o.h
                var theirs = m.c
                    ? [{ side: "C", v: op + os / 2 }]
                    : (o.screen ? [] : [
                        { side: vertical ? "L" : "T", v: op },
                        { side: vertical ? "R" : "B", v: op + os }
                    ])
                for (var ti = 0; ti < theirs.length; ti++) {
                    if (near(m.v, theirs[ti].v)) {
                        group.push(o)
                        if (theirs[ti].side === m.side)
                            same = true
                        break
                    }
                }
            }
            if (group.length === 0)
                continue

            // The line runs over every widget it joins (the screen: all of it).
            var from = vertical ? rect.y : rect.x
            var to = from + (vertical ? rect.h : rect.w)
            var ids = [rect.id]
            var dots = [{ x: vertical ? m.v : rect.x + rect.w / 2, y: vertical ? rect.y + rect.h / 2 : m.v }]
            var hasScreen = false
            for (var gi = 0; gi < group.length; gi++) {
                var g = group[gi]
                if (g.screen) {
                    hasScreen = true
                    continue
                }
                ids.push(g.id)
                var gf = vertical ? g.y : g.x
                var gt = gf + (vertical ? g.h : g.w)
                from = Math.min(from, gf)
                to = Math.max(to, gt)
                dots.push({ x: vertical ? m.v : g.x + g.w / 2, y: vertical ? g.y + g.h / 2 : m.v })
            }
            if (hasScreen) {
                from = 0
                to = vertical ? room.h : room.w
            } else {
                from = Math.max(0, from - OVERHANG)
                to = Math.min(vertical ? room.h : room.w, to + OVERHANG)
            }

            var kind = m.c ? "center" : (same ? "edge" : "flush")
            var label = m.c ? "CENTER" : (same ? sideName(m.side) : "FLUSH")
            if (m.c && hasScreen && group.length === 1)
                label = "SCREEN CENTER"

            lines.push({
                key: (vertical ? "v" : "h") + ":" + m.side + ":" + Math.round(m.v * 10),
                axis: vertical ? "v" : "h",
                pos: m.v,
                from: from,
                to: to,
                kind: kind,
                label: label,
                side: m.side,
                ids: ids,
                dots: dots
            })
        }
    }

    // Same size.
    var wIds = [rect.id]
    var hIds = [rect.id]
    for (var k = 0; k < others.length; k++) {
        if (near(others[k].w, rect.w))
            wIds.push(others[k].id)
        if (near(others[k].h, rect.h))
            hIds.push(others[k].id)
    }
    if (wIds.length > 1)
        sizes.push({ axis: "w", value: rect.w, ids: wIds })
    if (hIds.length > 1)
        sizes.push({ axis: "h", value: rect.h, ids: hIds })

    return { lines: lines, sizes: sizes }
}

function sideName(side) {
    if (side === "L") return "LEFT"
    if (side === "R") return "RIGHT"
    if (side === "T") return "TOP"
    if (side === "B") return "BOTTOM"
    return "CENTER"
}

// ===== the guides' slots =====

function assignSlots(prev, lines, n) {
    var next = []
    var byKey = {}
    var used = {}
    var i
    for (i = 0; i < n; i++)
        next.push(null)
    for (i = 0; i < lines.length; i++)
        byKey[lines[i].key] = lines[i]
    for (i = 0; i < n; i++) {
        if (prev && prev[i] && byKey[prev[i].key]) {
            next[i] = byKey[prev[i].key]
            used[prev[i].key] = true
        }
    }
    var j = 0
    for (i = 0; i < lines.length; i++) {
        if (used[lines[i].key])
            continue
        while (j < n && next[j] !== null)
            j++
        if (j < n)
            next[j] = lines[i]
    }
    return next
}

// A cheap fingerprint, so a bound property is only re-assigned when the
// guides really changed (re-assigning rebuilds whatever draws them).
function sig(lines) {
    var s = []
    for (var i = 0; i < lines.length; i++)
        s.push(lines[i].key + "@" + Math.round(lines[i].from) + "-" + Math.round(lines[i].to))
    return s.join("|")
}
