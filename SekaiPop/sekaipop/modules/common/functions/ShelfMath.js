.pragma library

// What each thing on the dock's Shelf looks like, and where it stands (DockShelfCard.qml).
// The look depends on what was put down:
//
//   folder          a folder              (a directory)
//   image           a polaroid            (png jpg gif webp bmp svg)
//   video           a video tape          (mp4 mkv webm mov avi ...)
//   audio           a record in its sleeve (mp3 flac wav ogg opus m4a ...)
//   archive         a box                 (zip tar gz xz zst 7z rar)
//   note            a sticky note         (text, and web links)
//   book            a book                (every other file: documents, code, ...)
//
// Each kind has its own width and height; the books and the folders also vary a little in height
// by the item's id, so a thing keeps its look (no random). The things stand in a row on a plank
// and, when the row is full, the next ones stand on a plank of their own (a "shelf").

const IMAGE = /\.(png|jpe?g|gif|webp|bmp|svg)$/i
const VIDEO = /\.(mp4|m4v|mkv|webm|mov|avi|flv|wmv|mpe?g|ogv|3gp|ts|vob)$/i
const AUDIO = /\.(mp3|flac|wav|ogg|oga|opus|m4a|aac|wma|aiff?|mid|midi|ape)$/i
const ARCHIVE = /\.(zip|tar|gz|tgz|bz2|xz|zst|7z|rar|lz4|cab)$/i
const CODE = /\.(js|ts|jsx|tsx|py|rs|go|c|h|cpp|hpp|java|kt|qml|sh|lua|rb|php|css|html|json|ya?ml|toml|nix)$/i
const PDF = /\.pdf$/i

// px: w is the width, hMax the tallest, `step` how much shorter the other (seed % 4) are.
// buttons: "column" up the spine (22 px each) or a "row" along the foot (18 px each).
const SPEC = {
    book:    { w: 36, hMax: 120, step: 8, buttons: "column", lean: 0 },
    folder:  { w: 46, hMax: 112, step: 6, buttons: "column", lean: 0 },
    video:   { w: 30, hMax: 112, step: 0, buttons: "column", lean: 0 },
    image:   { w: 64, hMax: 88,  step: 0, buttons: "row",    lean: 2 },
    audio:   { w: 62, hMax: 84,  step: 0, buttons: "row",    lean: 0 },
    archive: { w: 62, hMax: 78,  step: 0, buttons: "row",    lean: 0 },
    note:    { w: 56, hMax: 84,  step: 0, buttons: "row",    lean: 2 }
}

// A number from the item's id, so a thing keeps its colour and height (never random per paint).
function seedOf(id) {
    let h = 7
    const t = String(id)
    for (let i = 0; i < t.length; i++)
        h = (h * 31 + t.charCodeAt(i)) % 1000003
    return h
}

function isImage(path) {
    return IMAGE.test(String(path))
}

// "folder" | "image" | "video" | "audio" | "archive" | "note" | "book"
function kindOf(item) {
    if (!item || item.kind !== "file")
        return "note"
    if (item.dir === true)
        return "folder"
    const p = String(item.value)
    if (IMAGE.test(p)) return "image"
    if (VIDEO.test(p)) return "video"
    if (AUDIO.test(p)) return "audio"
    if (ARCHIVE.test(p)) return "archive"
    return "book"
}

// The glyph on a book / folder / sleeve / box.
function iconOf(item) {
    switch (kindOf(item)) {
    case "folder": return "folder"
    case "video": return "movie"
    case "audio": return "music_note"
    case "archive": return "folder_zip"
    case "image": return "image"
    case "note": return "notes"
    }
    const p = String(item.value)
    if (PDF.test(p)) return "picture_as_pdf"
    if (CODE.test(p)) return "code"
    return "description"
}

function specOf(kind) {
    return SPEC[kind] || SPEC.book
}

function heightOf(kind, seed) {
    const s = specOf(kind)
    return s.step === 0 ? s.hMax : s.hMax - (seed % 4) * s.step
}

// The tilt a thing rests at (the polaroid and the note lean a little, either way).
function restTilt(kind, seed) {
    return specOf(kind).lean * ((seed % 3) - 1)
}

// Puts the items in order on shelves of `listW` px, `gap` px between things. Each shelf is a
// list of { item, kind, seed, x, w, h }. A thing never splits across two shelves; one that is
// wider than the shelf would still get a shelf of its own. No items: no shelves.
function pack(items, listW, gap) {
    const shelves = []
    let row = []
    let x = 0
    for (const item of items) {
        const kind = kindOf(item)
        const seed = seedOf(item.id)
        const w = specOf(kind).w
        if (row.length > 0 && x + w > listW) {
            shelves.push(row)
            row = []
            x = 0
        }
        row.push({ item: item, kind: kind, seed: seed, x: x, w: w, h: heightOf(kind, seed) })
        x += w + gap
    }
    if (row.length > 0)
        shelves.push(row)
    return shelves
}
