.pragma library

// The maths behind the Custom Image widget (desktopWidgets/ImageWidget.qml,
// services/ImageService.qml), kept free of QML so tests/image-test/image_unit.js
// can run it under node.
//
// Vocabulary:
//   frame   the rectangle the user drags and resizes (design pixels)
//   shape   the part of the frame the picture, border and shadow occupy.
//           FIT: the picture's own rectangle, centred in the frame (no empty
//           bars inside the border). FILL / CROP: the whole frame.
//   draw    where the picture is stretched to, relative to the shape. FIT: the
//           shape. FILL: "cover", centred. CROP: cover x zoom, panned.

var MIN_SIDE = 24
var MAX_ZOOM = 6
// An empty frame (a Custom Image with no picture yet: it waits on the desktop for a
// file to be dropped on it) starts this big, in design pixels.
var EMPTY_W = 320
var EMPTY_H = 240
// The picture types the widget shows (scripts/images/pick-custom-image.sh keeps the
// same list).
var PICTURE_EXTS = ["png", "jpg", "jpeg", "webp", "gif", "apng", "bmp", "svg"]
var MODES = ["fit", "fill", "crop"]
var COLORS = ["navy", "white", "mint", "cyan", "pink", "black"]
var SHADOWS = ["soft", "hard"]

function clamp(v, lo, hi) {
    v = Number(v)
    if (!isFinite(v))
        v = lo
    return Math.max(lo, Math.min(hi, v))
}

function num(v, fallback) {
    v = Number(v)
    return isFinite(v) ? v : fallback
}

function pick(list, v, fallback) {
    return list.indexOf(v) >= 0 ? v : fallback
}

function newId() {
    return "i" + Date.now().toString(36) + Math.floor(Math.random() * 46656).toString(36)
}

// A fresh record. x / y of -1 = never placed; w / h of 0 = waiting for the
// picture's size (the widget reports it, see ImageService.noteSize).
function defaults(id, path) {
    return {
        id: id, path: path,
        x: -1, y: -1, w: 0, h: 0, scale: 0, screen: "",
        nw: 0, nh: 0, reframe: false,
        mode: "fit", zoom: 1, panX: 0, panY: 0,
        roundness: 0.12,
        borderOn: false, borderWidth: 4, borderColor: "white",
        shadowOn: false, shadowKind: "soft", shadowDepth: 0.5,
        opacity: 1, lockAspect: true,
        pinned: false
    }
}

// Anything read back from disk (or handed over by a script) is cleaned here, so
// a hand-edited or older file can't put the widget into a state it can't draw.
// Returns null when there is no `path` at all. A path of "" is an EMPTY frame: it is
// kept, and drawn as a drop target until a picture is put in it.
function normalize(raw) {
    if (!raw || typeof raw !== "object" || typeof raw.path !== "string")
        return null
    var id = typeof raw.id === "string" && raw.id !== "" ? raw.id : newId()
    var d = defaults(id, raw.path)
    return {
        id: id, path: raw.path,
        x: num(raw.x, d.x), y: num(raw.y, d.y),
        w: Math.max(0, num(raw.w, 0)), h: Math.max(0, num(raw.h, 0)),
        scale: Math.max(0, num(raw.scale, 0)),
        screen: typeof raw.screen === "string" ? raw.screen : "",
        nw: Math.max(0, num(raw.nw, 0)), nh: Math.max(0, num(raw.nh, 0)),
        reframe: raw.reframe === true,
        mode: pick(MODES, raw.mode, d.mode),
        zoom: clamp(raw.zoom === undefined ? 1 : raw.zoom, 1, MAX_ZOOM),
        panX: clamp(num(raw.panX, 0), -1, 1), panY: clamp(num(raw.panY, 0), -1, 1),
        roundness: clamp(raw.roundness === undefined ? d.roundness : raw.roundness, 0, 1),
        borderOn: raw.borderOn === true,
        borderWidth: clamp(raw.borderWidth === undefined ? d.borderWidth : raw.borderWidth, 1, 24),
        borderColor: pick(COLORS, raw.borderColor, d.borderColor),
        shadowOn: raw.shadowOn === true,
        shadowKind: pick(SHADOWS, raw.shadowKind, d.shadowKind),
        shadowDepth: clamp(raw.shadowDepth === undefined ? d.shadowDepth : raw.shadowDepth, 0, 1),
        opacity: clamp(raw.opacity === undefined ? 1 : raw.opacity, 0.05, 1),
        lockAspect: raw.lockAspect !== false,
        // PINNED: drawn on the Overlay layer, in front of windows and fullscreen games, and
        // click-through. Off unless a record says so, so a frame (or a preset) saved before
        // this option existed is never pinned.
        pinned: raw.pinned === true
    }
}

// A first size for a picture: its own aspect ratio, the long side at most
// `target` (420) and at most 40% of the screen's short side, and at least 160
// (a tiny icon is not left unreadably small), never below MIN_SIDE.
function initialSize(nw, nh, roomW, roomH, target) {
    if (!(nw > 0) || !(nh > 0))
        return { w: 240, h: 240 }
    var short = Math.min(roomW > 0 ? roomW : 1e9, roomH > 0 ? roomH : 1e9)
    var cap = Math.max(160, Math.min(target || 420, short * 0.4))
    var long = Math.max(nw, nh)
    var k = Math.max(160, Math.min(cap, long)) / long
    return { w: Math.max(MIN_SIDE, Math.round(nw * k)), h: Math.max(MIN_SIDE, Math.round(nh * k)) }
}

// A new empty frame's record: EMPTY_W x EMPTY_H (less on a small screen), never
// placed (x / y -1: the middle of the screen, see ImageWidget.place).
function emptyFrame(id, screen, roomW, roomH) {
    var short = Math.min(roomW > 0 ? roomW : 1e9, roomH > 0 ? roomH : 1e9)
    var k = Math.min(1, short * 0.5 / EMPTY_H)
    return normalize({
        id: id, path: "", screen: screen,
        w: Math.max(MIN_SIDE, Math.round(EMPTY_W * k)), h: Math.max(MIN_SIDE, Math.round(EMPTY_H * k))
    })
}

// "file:///home/me/My%20Pics/a.png" -> "/home/me/My Pics/a.png". Anything that is
// not a local file (a web address, junk) gives "".
function localPath(url) {
    var u = String(url === undefined || url === null ? "" : url).trim()
    if (u.indexOf("file://") !== 0)
        return u.charAt(0) === "/" ? u : ""
    u = u.substring(7)
    // file://localhost/path and file:///path both end up as /path.
    if (u.indexOf("localhost/") === 0)
        u = u.substring(9)
    try {
        u = decodeURIComponent(u)
    } catch (e) {
        return ""
    }
    return u.charAt(0) === "/" ? u : ""
}

// Is this file name one of the picture types the widget shows?
function isPicture(name) {
    var n = String(name === undefined || name === null ? "" : name)
    var dot = n.lastIndexOf(".")
    if (dot < 0 || n.lastIndexOf("/") > dot)
        return false
    return PICTURE_EXTS.indexOf(n.substring(dot + 1).toLowerCase()) >= 0
}

// What a drop carries -> { files: [local paths of pictures, in order, no repeats],
// skipped: how many of the things dropped were not one }. `urls` is the drop's url
// list; `text` its plain text (some file managers send the paths only as text, one
// per line, "#" lines are comments in a text/uri-list).
function sortDrop(urls, text) {
    var raw = []
    var i
    if (urls && urls.length > 0) {
        for (i = 0; i < urls.length; i++)
            raw.push(String(urls[i]))
    } else if (typeof text === "string" && text !== "") {
        var lines = text.split(/\r?\n/)
        for (i = 0; i < lines.length; i++) {
            var l = lines[i].trim()
            if (l !== "" && l.charAt(0) !== "#")
                raw.push(l)
        }
    }
    var files = [], seen = {}, skipped = 0
    for (i = 0; i < raw.length; i++) {
        var p = localPath(raw[i])
        if (p === "" || !isPicture(p)) {
            skipped++
        } else if (!seen[p]) {
            seen[p] = true
            files.push(p)
        }
    }
    return { files: files, skipped: skipped }
}

// The shape rectangle inside the frame (frame-relative).
function shapeRect(fw, fh, nw, nh, mode) {
    if (mode !== "fit" || !(nw > 0) || !(nh > 0) || !(fw > 0) || !(fh > 0))
        return { x: 0, y: 0, w: Math.max(0, fw), h: Math.max(0, fh) }
    var s = Math.min(fw / nw, fh / nh)
    var w = nw * s, h = nh * s
    return { x: (fw - w) / 2, y: (fh - h) / 2, w: w, h: h }
}

// Where the picture is stretched to, relative to the shape. panX / panY run
// -1..1: -1 shows the left / top edge, 0 is centred, 1 shows the right / bottom.
function drawRect(sw, sh, nw, nh, mode, zoom, panX, panY) {
    if (mode === "fit" || !(nw > 0) || !(nh > 0))
        return { x: 0, y: 0, w: sw, h: sh }
    var cover = Math.max(sw / nw, sh / nh)
    var z = mode === "crop" ? clamp(zoom, 1, MAX_ZOOM) : 1
    var w = nw * cover * z, h = nh * cover * z
    var px = mode === "crop" ? clamp(panX, -1, 1) : 0
    var py = mode === "crop" ? clamp(panY, -1, 1) : 0
    return { x: -(w - sw) / 2 * (1 + px), y: -(h - sh) / 2 * (1 + py), w: w, h: h }
}

// Dragging the picture by (dx, dy) design pixels in CROP mode: the picture
// follows the pointer, so the pan moves the other way. Returns the new pan.
function panBy(sw, sh, nw, nh, zoom, panX, panY, dx, dy) {
    var r = drawRect(sw, sh, nw, nh, "crop", zoom, 0, 0)
    var ox = (r.w - sw) / 2, oy = (r.h - sh) / 2
    return {
        panX: ox > 0.5 ? clamp(panX - dx / ox, -1, 1) : 0,
        panY: oy > 0.5 ? clamp(panY - dy / oy, -1, 1) : 0
    }
}

// Resizing the frame by one of its corners; the opposite corner stays put.
//   start    { x, y, w, h } when the drag began
//   corner   "nw" | "ne" | "sw" | "se"
//   dx, dy   how far the pointer has moved since then (design pixels)
//   o        { lock, aspect (w / h to keep; default start's), roomW, roomH }
function resize(start, corner, dx, dy, o) {
    o = o || {}
    var east = corner.charAt(1) === "e", south = corner.charAt(0) === "s"
    var sx = east ? 1 : -1, sy = south ? 1 : -1
    var roomW = o.roomW > 0 ? o.roomW : 1e9, roomH = o.roomH > 0 ? o.roomH : 1e9
    var maxW = east ? roomW - start.x : start.x + start.w
    var maxH = south ? roomH - start.y : start.y + start.h
    maxW = Math.max(MIN_SIDE, maxW)
    maxH = Math.max(MIN_SIDE, maxH)
    var w = start.w + sx * dx, h = start.h + sy * dy
    if (o.lock) {
        var aspect = o.aspect > 0 ? o.aspect : start.w / start.h
        var k = Math.max(w / start.w, h / start.h)
        w = start.w * k
        h = w / aspect
        var lo = Math.max(MIN_SIDE, MIN_SIDE * aspect)
        var hi = Math.min(maxW, maxH * aspect)
        w = clamp(w, Math.min(lo, hi), Math.max(lo, hi))
        h = w / aspect
    } else {
        w = clamp(w, MIN_SIDE, maxW)
        h = clamp(h, MIN_SIDE, maxH)
    }
    return {
        x: east ? start.x : start.x + start.w - w,
        y: south ? start.y : start.y + start.h - h,
        w: w, h: h
    }
}

// The frame with the picture's own aspect ratio, keeping its width (or the
// largest that still fits the room).
function originalRatio(frame, nw, nh, roomW, roomH) {
    if (!(nw > 0) || !(nh > 0))
        return { x: frame.x, y: frame.y, w: frame.w, h: frame.h }
    var a = nw / nh
    var w = frame.w, h = w / a
    var maxH = Math.max(MIN_SIDE, (roomH > 0 ? roomH : 1e9) - frame.y)
    if (h > maxH) {
        h = maxH
        w = h * a
    }
    return { x: frame.x, y: frame.y, w: Math.max(MIN_SIDE, w), h: Math.max(MIN_SIDE, h) }
}

// Keeps a frame on the screen (top-left corner first).
function keepOn(x, y, w, h, roomW, roomH) {
    return {
        x: Math.max(0, Math.min(x, Math.max(0, roomW - w))),
        y: Math.max(0, Math.min(y, Math.max(0, roomH - h)))
    }
}

// Long side to decode a still picture at: enough for the frame (times zoom) on
// this screen, in 256 px steps so a resize doesn't reload it on every step.
function decodeSide(w, h, texel, zoom, limit) {
    var need = Math.max(w, h) * Math.max(0.1, texel) * Math.max(1, zoom) * 1.25
    var step = Math.ceil(need / 256) * 256
    return Math.max(256, Math.min(limit || 4096, step))
}

// Where a new copy of a picture lands: down-right of the original.
function cascade(x, y, w, h, roomW, roomH, by) {
    return keepOn(x + (by || 28), y + (by || 28), w, h, roomW, roomH)
}
