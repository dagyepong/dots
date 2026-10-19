pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import "../modules/common/functions/NotesMath.js" as NM

// The desktop Sticky Notes' state: every note's text, colour, place, size and
// whether it is pinned. One singleton (like TodoService.qml) so anything else can
// add a note without touching the widget:
//
//   import qs.services
//   NotesService.add("buy milk")
//
// StickyNotesWidget.qml / StickyNote.qml are the only things that draw it.
//
// Notes live in a ListModel (not a JS array) so typing in one note, or dragging
// another, changes just that row: no note is rebuilt, so a half-typed text, the
// cursor and the keyboard focus survive everything else. The row's roles are named
// nid / body / tint / nx / ny / nw / nh / nz / pinned (not id / x / y / width ...) so
// they can never be mixed up with an Item's own properties inside a delegate.
//
// A ListModel does not tell bindings when a row's value changes through get(), so
// `rev` is bumped after every change that something computed from get() (the
// widget's input mask) has to notice.
//
// Persistence follows TodoService: a tiny script (notes-state.sh) run as a Process.
// Text is saved a moment after you stop typing, a drop (move / resize) is saved at
// once, so a reload right after you let go can not beat the save.
//
// Per preset: the notes on the desktop belong to the desktop preset that is worn
// (`setName`), and every OTHER preset keeps its own notes in `sets`. Wearing a preset
// (DesktopPresetService.wear -> switchSet) puts the worn one's notes away and brings that
// preset's own back, so each preset has its own notes and an edit only changes the preset
// you are wearing. A preset that has no notes of its own yet (one saved before this, or
// never worn since) keeps the notes you have and from then on owns that copy, so nothing is
// lost on the first switch. Saving a preset (adoptSet) gives it the notes you have. Not like
// the To-Do, whose tasks are the same under every preset.
//
// "Pinned" = the note floats above your windows (the widget draws pinned notes in a
// second layer-shell window on the Top layer); the others rest on the desktop, under
// them, like the other desktop widgets.
Singleton {
    id: root

    property alias items: listModel

    // Kept by recount().
    property int count: 0
    property int pinnedCount: 0
    // See the header.
    property int rev: 0

    // False until the saved state has been read. Nothing is written before then, or a
    // fresh start would overwrite what is on disk with an empty list.
    property bool loaded: false

    // The widget's own switch. False for a first run and after the last note has been
    // deleted, so turning it on (Settings, the Edit Desktop shelf) makes a first note.
    property bool shown: false
    // On the desktop right now: switched on and something to show.
    readonly property bool active: root.shown && root.count > 0

    // The shell scale the positions were saved at. They are in design pixels, so the
    // notes stay on the same spot of the screen when the shell is scaled: `fit()`
    // turns them into the current scale (the notes keep their top-left corner).
    property real posScale: 0

    // The preset the notes on the desktop belong to ("" = none yet), and the notes of
    // every other preset: { <preset name>: { shown, notes: [...] } } (the same note
    // objects snapshot() makes). See the header.
    property string setName: ""
    property var sets: ({})

    // The screen as the notes see it, as last reported by a widget layer (design
    // pixels). Where a new note is put.
    property real roomW: 0
    property real roomH: 0

    // The note that was just made: it pops in and takes the keyboard.
    property string freshId: ""

    // A note is being dragged or resized: the layers do not re-fit meanwhile.
    property bool interacting: false

    readonly property int maxNotes: NM.MAX_NOTES

    ListModel { id: listModel }

    property int idSeq: 0

    function newId() {
        root.idSeq++
        return Date.now().toString(36) + root.idSeq.toString(36)
    }

    function recount() {
        let p = 0
        for (let i = 0; i < listModel.count; i++) {
            if (listModel.get(i).pinned)
                p++
        }
        root.count = listModel.count
        root.pinnedCount = p
        root.rev++
    }

    function touch() {
        root.recount()
        root.persist()
    }

    function indexOf(id) {
        for (let i = 0; i < listModel.count; i++) {
            if (listModel.get(i).nid === id)
                return i
        }
        return -1
    }

    // ===== notes =====
    // Returns the new note's id, or "" when there are already maxNotes.
    function add(body) {
        if (!root.loaded || listModel.count >= NM.MAX_NOTES)
            return ""
        const rw = root.roomW > 0 ? root.roomW : 1280
        const rh = root.roomH > 0 ? root.roomH : 720
        const spot = NM.cascade(listModel.count, rw, rh)
        const zs = []
        for (let i = 0; i < listModel.count; i++)
            zs.push(listModel.get(i).nz)
        const id = root.newId()
        listModel.append({
            nid: id,
            body: String(body ?? "").slice(0, NM.MAX_CHARS),
            tint: NM.nextTint(listModel.count),
            nx: spot.x,
            ny: spot.y,
            nw: spot.w,
            nh: spot.h,
            nz: NM.topZ(zs),
            pinned: false
        })
        root.freshId = id
        root.shown = true
        root.touch()
        return id
    }

    function setText(id, body) {
        const i = root.indexOf(id)
        if (i < 0)
            return
        listModel.setProperty(i, "body", String(body).slice(0, NM.MAX_CHARS))
        root.persist()
    }

    function setColor(id, tint) {
        const i = root.indexOf(id)
        if (i < 0 || !NM.validTint(tint))
            return
        listModel.setProperty(i, "tint", tint)
        root.touch()
    }

    function setPinned(id, value) {
        const i = root.indexOf(id)
        if (i < 0)
            return
        listModel.setProperty(i, "pinned", value === true)
        root.touch()
    }

    function togglePinned(id) {
        const i = root.indexOf(id)
        if (i >= 0)
            root.setPinned(id, !listModel.get(i).pinned)
    }

    function remove(id) {
        const i = root.indexOf(id)
        if (i < 0)
            return
        listModel.remove(i)
        // Nothing left: the widget switches itself off, so its switches read "off" and
        // turning it on makes a first note again.
        if (listModel.count === 0)
            root.shown = false
        root.touch()
    }

    // One above the others. Only written when it is not already the top one.
    function raise(id) {
        const i = root.indexOf(id)
        if (i < 0)
            return
        const mine = listModel.get(i).nz
        let top = 0
        let covered = false
        for (let k = 0; k < listModel.count; k++) {
            const z = listModel.get(k).nz
            top = Math.max(top, z)
            if (k !== i && z >= mine)
                covered = true
        }
        if (!covered)
            return
        listModel.setProperty(i, "nz", top + 1)
        root.rev++
        root.persist()
    }

    // ===== place and size =====
    // Live, while a note is dragged or resized: updates the row (so the note and the
    // input mask follow) but writes nothing; commit() does, once, on release.
    function setGeometry(id, x, y, w, h) {
        const i = root.indexOf(id)
        if (i < 0)
            return
        listModel.setProperty(i, "nx", x)
        listModel.setProperty(i, "ny", y)
        listModel.setProperty(i, "nw", w)
        listModel.setProperty(i, "nh", h)
        root.rev++
    }

    function geometryOf(id) {
        const i = root.indexOf(id)
        if (i < 0)
            return null
        const n = listModel.get(i)
        return { x: n.nx, y: n.ny, w: n.nw, h: n.nh }
    }

    function commit() {
        if (!root.loaded)
            return
        saveTimer.stop()
        saver.save(root.snapshot())
    }

    // Called by a widget layer once the window, the monitor and the scale have settled
    // (and again when any of them changes): follows a changed shell scale, then keeps
    // every note on screen. `ui` is the monitor's scale, `roomW` x `roomH` the screen
    // in design pixels.
    function fit(roomW, roomH, ui) {
        if (!root.loaded || roomW <= 0 || roomH <= 0 || root.interacting)
            return
        root.roomW = roomW
        root.roomH = roomH
        let changed = false
        if (ui > 0) {
            if (root.posScale <= 0) {
                root.posScale = ui
                changed = true
            } else if (Math.abs(root.posScale - ui) > 0.0001) {
                const k = root.posScale / ui
                for (let i = 0; i < listModel.count; i++) {
                    listModel.setProperty(i, "nx", listModel.get(i).nx * k)
                    listModel.setProperty(i, "ny", listModel.get(i).ny * k)
                }
                root.posScale = ui
                changed = true
            }
        }
        for (let i = 0; i < listModel.count; i++) {
            const n = listModel.get(i)
            const r = NM.fit({ x: n.nx, y: n.ny, w: n.nw, h: n.nh }, roomW, roomH)
            if (r.x !== n.nx || r.y !== n.ny || r.w !== n.nw || r.h !== n.nh) {
                listModel.setProperty(i, "nx", r.x)
                listModel.setProperty(i, "ny", r.y)
                listModel.setProperty(i, "nw", r.w)
                listModel.setProperty(i, "nh", r.h)
                changed = true
            }
        }
        if (changed) {
            root.rev++
            root.persist()
        }
    }

    // Puts every note back in a tidy cascade (`ipc call notes arrange`), for a pile that
    // has got out of hand. Keeps text, colour, size and pins.
    function arrange(roomW, roomH) {
        if (!root.loaded || roomW <= 0 || roomH <= 0)
            return
        for (let i = 0; i < listModel.count; i++) {
            const n = listModel.get(i)
            const s = NM.cascade(i, roomW, roomH)
            const r = NM.fit({ x: s.x, y: s.y, w: n.nw, h: n.nh }, roomW, roomH)
            listModel.setProperty(i, "nx", r.x)
            listModel.setProperty(i, "ny", r.y)
            listModel.setProperty(i, "nz", i + 1)
        }
        root.rev++
        root.commit()
    }

    function setShown(value) {
        if (!root.loaded)
            return
        if (value && listModel.count === 0) {
            root.add("")
            return
        }
        root.shown = value && listModel.count > 0
        root.persist()
    }

    // ===== persistence =====
    readonly property string script: Directories.script("state/notes-state.sh")

    // The notes on the desktop as plain objects.
    function currentNotes() {
        const notes = []
        for (let i = 0; i < listModel.count; i++) {
            const n = listModel.get(i)
            notes.push({
                id: n.nid,
                body: n.body,
                tint: n.tint,
                x: n.nx,
                y: n.ny,
                w: n.nw,
                h: n.nh,
                z: n.nz,
                pinned: n.pinned
            })
        }
        return notes
    }

    // Replaces the notes on the desktop with `notes` (the shape currentNotes() makes).
    function fill(notes) {
        listModel.clear()
        for (const n of notes) {
            listModel.append({
                nid: n.id,
                body: n.body,
                tint: n.tint,
                nx: n.x,
                ny: n.y,
                nw: n.w,
                nh: n.h,
                nz: n.z,
                pinned: n.pinned
            })
        }
    }

    function snapshot() {
        return JSON.stringify({
            shown: root.shown,
            scale: root.posScale,
            notes: root.currentNotes(),
            setName: root.setName,
            sets: root.sets
        })
    }

    function restore(text) {
        const p = NM.parse(String(text))
        root.fill(p.notes)
        // A first run (no file) starts switched off; a saved file keeps its switch,
        // but a widget with no notes is off whatever the file says.
        root.shown = String(text).trim() !== "" && p.shown && listModel.count > 0
        root.posScale = p.scale
        root.setName = p.setName
        root.sets = p.sets
        root.recount()
        root.loaded = true
    }

    // ===== one set of notes per preset =====
    // Puts the notes of the preset that is worn away under its name (no-op while the notes
    // belong to no preset yet: they then go to the first preset that is worn or saved).
    function stashCurrent() {
        if (root.setName === "")
            return
        const next = Object.assign({}, root.sets)
        next[root.setName] = { shown: root.shown, notes: root.currentNotes() }
        root.sets = next
    }

    // Wearing the preset `name`: its own notes come back; a preset with none yet keeps the
    // notes on the desktop and owns that copy from now on (see the header).
    function switchSet(name) {
        if (!root.loaded || typeof name !== "string" || name === "" || name === root.setName)
            return
        root.stashCurrent()
        const next = Object.assign({}, root.sets)
        const mine = next[name]
        if (mine) {
            delete next[name]
            root.fill(mine.notes)
            root.shown = mine.shown && listModel.count > 0
        }
        root.sets = next
        root.setName = name
        root.freshId = ""
        root.recount()
        root.commit()
    }

    // Saving the desktop as the preset `name`: it owns the notes on the desktop now (the
    // worn preset, if it is another one, keeps its own).
    function adoptSet(name) {
        if (!root.loaded || typeof name !== "string" || name === "" || name === root.setName)
            return
        root.stashCurrent()
        const next = Object.assign({}, root.sets)
        delete next[name]
        root.sets = next
        root.setName = name
        root.commit()
    }

    // The preset was renamed: its notes go with it.
    function renameSet(oldName, newName) {
        if (!root.loaded || oldName === newName || newName === "")
            return
        const next = Object.assign({}, root.sets)
        if (next[oldName] !== undefined) {
            next[newName] = next[oldName]
            delete next[oldName]
            root.sets = next
        }
        if (root.setName === oldName)
            root.setName = newName
        root.commit()
    }

    // The preset was deleted: its notes go too. If they are the ones on the desktop they
    // stay there, belonging to no preset until the next one is worn or saved.
    function dropSet(name) {
        if (!root.loaded || name === "")
            return
        if (root.sets[name] !== undefined) {
            const next = Object.assign({}, root.sets)
            delete next[name]
            root.sets = next
        }
        if (root.setName === name)
            root.setName = ""
        root.commit()
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

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: saver.save(root.snapshot())
    }

    // Fire-and-forget save. Queues at most one pending snapshot behind an in-flight
    // save rather than dropping it (same as TodoService's `saver`), so the LAST state
    // is what ends up on disk.
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
