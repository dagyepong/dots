pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import "../modules/common/functions/ImageMath.js" as IM

// The Custom Image widget's state: every picture the user has put on the desktop,
// and whether they are shown at all. Unlike the clock or the user card there can
// be any number of these, so this holds a list, and ImageWidget.qml is made once
// per entry (shell.qml: a Variants over `ids`).
//
//   import qs.services
//   ...
//   ImageService.addEmpty("")                   // a frame on the desktop at once; files are
//                                               // dropped on it (ImageWidget's DropArea)
//   ImageService.drop(id, urls, text)           // what a drop on frame `id` carries
//   ImageService.update(id, { opacity: 0.5 })
//   ImageService.setShown(false)                // hides all of them
//
// What one entry holds (ImageMath.defaults / normalize are the source of truth):
//
//   path           the copy of the picture in ~/.local/share/sekaipop/custom-images/
//                  (any still format, or a GIF / animated WebP / APNG; the file is
//                  never re-encoded, so it keeps moving). "" = an EMPTY frame: it is
//                  on the desktop already, drawn as a drop target, and the first
//                  picture dropped on it (or chosen for it) fills it
//   x y w h        the frame, in design pixels of the shell scale `scale` (so a
//   scale screen   picture stays on the same spot and the same share of the screen
//                  when the UI scale changes); `screen` = the monitor it was dropped on
//   nw nh          the picture's own size, learned the first time it loads
//   mode           fit | fill | crop         zoom panX panY: the crop
//   roundness      0..1 of the largest radius the shape allows
//   borderOn / borderWidth / borderColor    shadowOn / shadowKind / shadowDepth
//   opacity        0.05..1                   lockAspect: keep the ratio while resizing
//   pinned         true = drawn in FRONT of windows and games (Overlay layer) and clicks
//                  pass through it; off unless the record says so (an old frame or preset
//                  never has it). Right-click a picture on the desktop to pin it; undo it
//                  from the desktop menu ("Unpin images"), Edit Desktop's panel, or
//                  `ipc call image unpin`
//
// Persistence is the same convention as UserCardService: a tiny shell script
// (image-state.sh) run as a Process. A new position or size is saved straight
// away; everything else is debounced.
Singleton {
    id: root

    // False until the saved state has been read. Nothing is written before then, or
    // a fresh start would overwrite what is on disk with an empty list.
    property bool loaded: false

    property bool shown: true        // ipc: image toggle / show / hide

    // The entries, in the order they were added, and the same by id. A change to one
    // entry replaces only that entry's object, so an ImageWidget that reads its own
    // record sees a new object only when ITS picture changed.
    property var items: []
    property var byId: ({})
    // Just the ids. Re-assigned only when a picture is added or removed (never when
    // one is edited), so the Variants in shell.qml keeps every window it has.
    property var ids: []

    readonly property int count: root.items.length

    // Is any picture pinned? (The desktop menu shows "Unpin images" only then.)
    readonly property bool anyPinned: root.items.some(r => r.pinned)

    // True a moment after the saved pictures have been read. A picture that is made
    // before that was already there (it simply appears); one made after it was just
    // added (it pops in, see ImageWidget).
    property bool settled: false

    Timer {
        interval: 1500
        running: root.loaded
        onTriggered: root.settled = true
    }

    function rec(id) {
        return root.byId[id] ?? null
    }

    function commit(list, structural) {
        const map = {}
        for (const r of list)
            map[r.id] = r
        root.items = list
        root.byId = map
        if (structural)
            root.ids = list.map(r => r.id)
    }

    // Is any picture on this monitor? (Edit Desktop's shelf asks.)
    function countOn(screenName) {
        let n = 0
        for (const r of root.items) {
            if (r.screen === screenName)
                n++
        }
        return n
    }

    // ===== editing =====
    // `now`: save at once instead of after the debounce (a drop, a resize).
    function update(id, patch, now) {
        const old = root.byId[id]
        if (!old)
            return
        const next = IM.normalize(Object.assign({}, old, patch, { id: id }))
        if (!next)
            return
        root.commit(root.items.map(r => r.id === id ? next : r), false)
        if (now === true)
            root.saveNow()
        else
            root.persist()
    }

    // Where a picture sits and how big it is: saved straight away (no wait), so a
    // reload right after you drop it can't beat the save.
    function setGeometry(id, x, y, w, h, screen, scale) {
        if (!root.loaded)
            return
        const patch = { x: x, y: y, w: w, h: h }
        if (typeof scale === "number" && scale > 0)
            patch.scale = scale
        if (typeof screen === "string" && screen !== "")
            patch.screen = screen
        root.update(id, patch, true)
    }

    // Pin a picture in front of everything (or take it back to the desktop). Saved at once.
    function setPinned(id, on) {
        const r = root.byId[id]
        // An empty frame is a drop target; it is never pinned.
        if (!r || (on === true && r.path === ""))
            return
        root.update(id, { pinned: on === true }, true)
    }

    function togglePinned(id) {
        const r = root.byId[id]
        if (r)
            root.setPinned(id, !r.pinned)
    }

    // Every picture at once (ipc: image pin / unpin). Empty frames are never pinned: there is
    // nothing to show, and the drop target must stay reachable.
    function setAllPinned(on) {
        if (!root.loaded)
            return
        root.commit(root.items.map(r => IM.normalize(Object.assign({}, r, { pinned: on === true && r.path !== "" }))), false)
        root.saveNow()
    }

    function setShown(value) {
        root.shown = value
        root.persist()
    }

    function add(path, screen) {
        if (!root.loaded || typeof path !== "string" || path === "")
            return ""
        const r = IM.normalize({ id: IM.newId(), path: path, screen: typeof screen === "string" ? screen : "" })
        if (!r)
            return ""
        root.shown = true
        root.commit(root.items.concat([r]), true)
        root.saveNow()
        // Added from Edit Desktop's shelf: it is the one to edit now.
        if (EditMode.active)
            EditMode.select("image:" + r.id)
        return r.id
    }

    // The monitor's size in design pixels (what the widget calls roomW x roomH).
    function roomFor(screenName) {
        for (const s of Quickshell.screens) {
            if (s.name === screenName) {
                const k = ShellScale.forScreen(s)
                return { w: k > 0 ? s.width / k : s.width, h: k > 0 ? s.height / k : s.height }
            }
        }
        return { w: 0, h: 0 }
    }

    // A frame with no picture in it, on the desktop at once: it is the drop target
    // (the shelf's Image tile, Settings, `ipc call image add`). Nothing is asked first.
    //
    // `px` / `py` (optional, real window pixels from the monitor's top-left, what a click on
    // the desktop reports): PIN the frame there, centred on the pointer and kept on the
    // screen. Without them it goes to the middle. (Nothing passes them now that the desktop menu
    // has no "Pin image" row; kept for scripts.)
    function addEmpty(screen, px, py) {
        if (!root.loaded)
            return ""
        const home = EditMode.homeScreen(typeof screen === "string" ? screen : "")
        const room = root.roomFor(home)
        const r = IM.emptyFrame(IM.newId(), home, room.w, room.h)
        if (!r)
            return ""
        if (typeof px === "number" && typeof py === "number" && room.w > 0 && room.h > 0) {
            let k = 1
            for (const s of Quickshell.screens) {
                if (s.name === home)
                    k = ShellScale.forScreen(s)
            }
            if (!(k > 0))
                k = 1
            const p = IM.keepOn(px / k - r.w / 2, py / k - r.h / 2, r.w, r.h, room.w, room.h)
            r.x = Math.round(p.x)
            r.y = Math.round(p.y)
            r.scale = k
        }
        root.shown = true
        root.commit(root.items.concat([r]), true)
        root.saveNow()
        // Added from Edit Desktop's shelf: it is the one to edit now.
        if (EditMode.active)
            EditMode.select("image:" + r.id)
        return r.id
    }

    // Another copy of the same picture, a little down and right of it (they share
    // one file; the file is only deleted when the last one using it goes).
    function duplicate(id) {
        const old = root.byId[id]
        if (!old)
            return ""
        const c = IM.normalize(Object.assign({}, old, {
            id: IM.newId(),
            x: old.x >= 0 ? old.x + 28 : -1,
            y: old.y >= 0 ? old.y + 28 : -1
        }))
        root.commit(root.items.concat([c]), true)
        root.saveNow()
        return c.id
    }

    function remove(id) {
        const old = root.byId[id]
        if (!old)
            return
        root.commit(root.items.filter(r => r.id !== id), true)
        root.saveNow()
        root.forget(old.path)
    }

    // Wearing a desktop preset (DesktopPresetService.wearFrames): the frames become the
    // preset's. `list` is the preset's frame records; `where` maps a picture's file name to
    // the path it has now (the preset's own copy, put back in the data folder). A frame whose
    // picture could not be put back is left out; an empty frame needs none. The pictures the
    // old frames used and the new ones do not are deleted (the preset keeps its own copy).
    function wearFrames(list, where) {
        if (!root.loaded)
            return
        const seen = {}
        const next = []
        for (const raw of list) {
            if (!raw || typeof raw !== "object")
                continue
            const rec = Object.assign({}, raw)
            if (typeof rec.path === "string" && rec.path !== "") {
                const now = where[rec.path.slice(rec.path.lastIndexOf("/") + 1)]
                if (typeof now !== "string")
                    continue
                rec.path = now
            }
            const r = IM.normalize(rec)
            if (r && !seen[r.id]) {
                seen[r.id] = true
                next.push(r)
            }
        }
        const old = root.items
        root.commit(next, true)
        root.saveNow()
        for (const r of old)
            root.forget(r.path)
    }

    function resetPosition(id) {
        root.update(id, { x: -1, y: -1 }, true)
    }

    function resetAllPositions() {
        root.commit(root.items.map(r => IM.normalize(Object.assign({}, r, { x: -1, y: -1 }))), false)
        root.saveNow()
    }

    // The widget reports the picture's own size once it has loaded. This gives a new
    // picture its first frame (its own ratio), and a replaced one the new ratio
    // (same width). Nothing else ever rewrites a frame behind the user's back.
    function noteSize(id, nw, nh, roomW, roomH) {
        const r = root.byId[id]
        if (!r || !(nw > 0) || !(nh > 0))
            return
        if (r.nw > 0 && r.w > 0 && !r.reframe)
            return
        const patch = { nw: nw, nh: nh, reframe: false }
        if (!(r.w > 0) || !(r.h > 0)) {
            const s = IM.initialSize(nw, nh, roomW, roomH)
            patch.w = s.w
            patch.h = s.h
        } else if (r.reframe) {
            const f = IM.originalRatio({ x: Math.max(0, r.x), y: Math.max(0, r.y), w: r.w, h: r.h }, nw, nh, roomW, roomH)
            patch.w = f.w
            patch.h = f.h
        }
        root.update(id, patch, true)
    }

    // ===== the picture files =====
    // Pictures only come in by drag and drop (or `ipc call image addPath`): there is no file
    // chooser. The script copies a picture into the data folder and deletes the copies.
    readonly property string pickScript: Directories.script("images/pick-custom-image.sh")

    readonly property bool busy: importer.running || importer.waiting || root.importQueue.length > 0

    // A picture that is already on disk (ipc: image addPath <file>).
    function addPath(file, screenName) {
        if (typeof file !== "string" || file === "")
            return
        root.enqueue(file, "", typeof screenName === "string" ? screenName : "", "", 0)
    }

    function replacePath(id, path) {
        const old = root.byId[id]
        if (!old)
            return
        root.update(id, { path: path, nw: 0, nh: 0, reframe: true, zoom: 1, panX: 0, panY: 0 }, true)
        root.forget(old.path)
    }

    // ===== dropping files =====
    // A file dropped on a frame: the first picture goes INTO that frame (fills an empty
    // one, replaces the picture of a full one: the frame keeps its spot and width, and
    // takes the picture's ratio); every further picture in the same drop becomes a new
    // frame of its own, stepping down and right of it. Anything that is not a picture
    // (a folder, a text file, a web address) is skipped, and the frame says so.
    //
    //   id      the frame it was dropped on
    //   urls    the drop's url list (strings), or [] when it only carried text
    //   text    the drop's plain text, used when there are no urls
    function drop(id, urls, text) {
        const sorted = IM.sortDrop(urls, text)
        if (sorted.skipped > 0 || sorted.files.length === 0)
            root.reject(id, Math.max(1, sorted.skipped))
        const there = root.byId[id] ?? null
        for (let i = 0; i < sorted.files.length; i++)
            root.enqueue(sorted.files[i], (i === 0 && there) ? id : "", there ? there.screen : "", there ? id : "", i)
    }

    // The widget flashes a note on the frame whose id is `rejectId` each time
    // `rejectTick` changes (`rejectCount` = how many things were not pictures).
    property string rejectId: ""
    property int rejectCount: 0
    property int rejectTick: 0

    function reject(id, count) {
        root.rejectId = id
        root.rejectCount = count
        root.rejectTick = root.rejectTick + 1
    }

    // The copies are made one after the other (a queue, not one slot: a drop of ten
    // pictures must not lose nine). A job: { file, target, screen, like, step }.
    //   target  the frame the picture goes into ("" = a new frame)
    //   like    the frame a new one is put beside ("" = the middle of the screen)
    property var importQueue: []

    function enqueue(file, target, screenName, like, step) {
        root.importQueue = root.importQueue.concat([{ file: file, target: target, screen: screenName, like: like, step: step }])
        root.pumpImport()
    }

    function pumpImport() {
        if (importer.running || importer.waiting || root.importQueue.length === 0)
            return
        importer.job = root.importQueue[0]
        importer.file = importer.job.file
        root.importQueue = root.importQueue.slice(1)
        importer.waiting = true
        importer.running = true
    }

    // The copy is made: it goes into its frame, or becomes a new one.
    function landed(job, path) {
        if (job.target !== "" && root.byId[job.target]) {
            root.replacePath(job.target, path)
            return
        }
        const like = job.like !== "" ? (root.byId[job.like] ?? null) : null
        if (!like) {
            root.add(path, job.screen)
            return
        }
        const by = 28 * Math.max(1, job.step)
        const c = IM.normalize({
            id: IM.newId(), path: path, screen: like.screen, scale: like.scale,
            x: like.x >= 0 ? like.x + by : -1,
            y: like.y >= 0 ? like.y + by : -1
        })
        if (!c)
            return
        root.shown = true
        root.commit(root.items.concat([c]), true)
        root.saveNow()
    }

    Process {
        id: importer

        property var job: null
        property string file: ""
        // Started, and its answer not read yet: the next job waits for it, so the answer
        // is never matched with the wrong job. (`job` and `file` are left as they were
        // when it finishes: the command of a process that is still ending is not touched.)
        property bool waiting: false

        command: ["sh", root.pickScript, "import", importer.file]
        stdout: StdioCollector {
            onStreamFinished: {
                const job = importer.waiting ? importer.job : null
                const path = text.trim()
                importer.waiting = false
                if (job) {
                    if (path === "")
                        root.reject(job.like !== "" ? job.like : job.target, 1)
                    else
                        root.landed(job, path)
                }
                root.pumpImport()
            }
        }
        onExited: root.pumpImport()
    }

    // ===== deleting the copies =====
    // A queue, not one slot: removing several pictures one after the other must not
    // drop one (its file would stay behind for good).
    property var forgetQueue: []

    function forget(path) {
        if (path === "")
            return                          // an empty frame has no file
        for (const r of root.items) {
            if (r.path === path)
                return                      // another picture still uses this file
        }
        root.forgetQueue = root.forgetQueue.concat([path])
        root.pumpForget()
    }

    function pumpForget() {
        if (forgetter.running || root.forgetQueue.length === 0)
            return
        forgetter.path = root.forgetQueue[0]
        root.forgetQueue = root.forgetQueue.slice(1)
        forgetter.running = true
    }

    Process {
        id: forgetter

        property string path: ""

        command: ["sh", root.pickScript, "remove", forgetter.path]
        onExited: root.pumpForget()
    }

    // ===== persistence =====
    readonly property string script: Directories.script("state/image-state.sh")

    function snapshot() {
        return JSON.stringify({ version: 1, shown: root.shown, items: root.items })
    }

    function restore(text) {
        try {
            const s = JSON.parse(text)
            const seen = {}
            const list = []
            for (const raw of (Array.isArray(s.items) ? s.items : [])) {
                const r = IM.normalize(raw)
                if (r && !seen[r.id]) {
                    seen[r.id] = true
                    list.push(r)
                }
            }
            root.shown = s.shown !== false
            root.commit(list, true)
        } catch (e) {
            // No file yet (first run) or an unreadable one: no pictures.
        }
        root.loaded = true
    }

    // Runs once, at startup.
    Process {
        running: true
        command: ["sh", root.script, "load"]
        stdout: StdioCollector {
            onStreamFinished: root.restore(text)
        }
    }

    function persist() {
        if (root.loaded)
            saveTimer.restart()
    }

    function saveNow() {
        if (!root.loaded)
            return
        saveTimer.stop()
        saver.save(root.snapshot())
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: saver.save(root.snapshot())
    }

    // Fire-and-forget save. Queues at most one pending snapshot behind an in-flight
    // save rather than dropping it, so the *last* state is what ends up on disk
    // (same reasoning as UserCardService's `saver`).
    Process {
        id: saver

        property var pending: null

        function save(json) {
            if (saver.running) {
                saver.pending = json
                return
            }
            saver.pending = null
            saver.exec(["sh", root.script, "save", json])
        }

        onExited: {
            if (saver.pending !== null) {
                const json = saver.pending
                saver.pending = null
                saver.exec(["sh", root.script, "save", json])
            }
        }
    }
}
