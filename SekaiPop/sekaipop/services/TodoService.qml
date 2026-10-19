pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// The desktop To-Do widget's state — tasks and where the card sits — kept
// as its own singleton (like PinnedAppsService.qml, WallpaperService.qml)
// rather than widget-local state, so anything else can add a task without
// touching TodoWidget.qml:
//
//   import qs.services
//   ...
//   TodoService.add("water the plants")
//
// TodoWidget.qml is the only thing that draws it.
//
// Tasks live in a ListModel (not a plain JS array) on purpose: editing or
// checking one task changes just that row, so the list keeps its scroll
// position and a half-typed edit isn't thrown away by an unrelated change.
//
// Persistence follows the same convention as PinnedAppsService: a tiny
// shell script (todo-state.sh) run as a Process. Saves are debounced, so
// dragging or typing doesn't hit the disk on every change.
Singleton {
    id: root

    // The tasks: rows of { title: string, done: bool }.
    property alias items: listModel

    // Kept in step with the model by recount() — a ListModel doesn't
    // notify bindings when a row's `done` flips, so these are updated by
    // hand after every change.
    property int total: 0
    property int doneCount: 0

    // False until the saved state has been read. Nothing is written
    // before then, or a fresh start would overwrite what's on disk with
    // an empty list.
    property bool loaded: false

    property bool shown: false       // off until you add it: ipc todo toggle / Edit Desktop (a first run shows only the clock)

    // The card's size. "full" is the card as it has always been; "2x2" is the footprint the
    // clock, user card and weather card share (320 x 276), so the cards line up as a set.
    // Remembered across restarts. Switch it in Settings -> Desktop, with the size key that
    // shows on the card while it is selected in Edit Desktop, or `ipc call todo size 2x2|full`.
    property string size: "full"
    readonly property bool small: root.size === "2x2"
    property real posX: -1           // -1 = never placed; widget picks a default
    property real posY: -1
    // The shell scale (ShellScale) posX / posY were saved at. They are in design
    // pixels, so the card stays on the same spot of the screen when the shell
    // is scaled up or down: the widget turns them into screen pixels with this
    // and back into design pixels with its current scale. 0 = saved before this
    // was kept (the widget adopts the current scale then, see its `settle`).
    property real posScale: 0

    ListModel { id: listModel }

    function recount() {
        let d = 0
        for (let i = 0; i < listModel.count; i++) {
            if (listModel.get(i).done)
                d++
        }
        root.total = listModel.count
        root.doneCount = d
    }

    function touch() {
        root.recount()
        root.persist()
    }

    // ===== tasks =====
    function add(title) {
        const t = String(title).trim()
        if (t === "")
            return false
        listModel.append({ title: t, done: false })
        root.touch()
        return true
    }

    function edit(index, title) {
        const t = String(title).trim()
        if (t === "" || index < 0 || index >= listModel.count)
            return
        listModel.setProperty(index, "title", t)
        root.touch()
    }

    function toggle(index) {
        if (index < 0 || index >= listModel.count)
            return
        listModel.setProperty(index, "done", !listModel.get(index).done)
        root.touch()
    }

    function remove(index) {
        if (index < 0 || index >= listModel.count)
            return
        listModel.remove(index)
        root.touch()
    }

    // Moves one task to a new position (drag-to-reorder in TodoWidget).
    // Returns whether anything moved. Only the order changes, so no recount.
    // Not saved here: a drag can hop many times, so TodoWidget calls
    // commitOrder() once, when the task is dropped.
    function move(from, to) {
        if (from === to || from < 0 || to < 0
                || from >= listModel.count || to >= listModel.count)
            return false
        listModel.move(from, to, 1)
        return true
    }

    function commitOrder() {
        root.persist()
    }

    function clearDone() {
        for (let i = listModel.count - 1; i >= 0; i--) {
            if (listModel.get(i).done)
                listModel.remove(i)
        }
        root.touch()
    }

    // ===== card =====
    function setPosition(x, y, scale) {
        if (!root.loaded)
            return
        root.posX = x
        root.posY = y
        if (typeof scale === "number" && scale > 0)
            root.posScale = scale
        saveTimer.stop()
        saver.save(root.snapshot())
    }

    function setShown(value) {
        root.shown = value
        root.persist()
    }

    // "2x2" (or "small") and "full"; anything else is "full".
    function setSize(value) {
        const v = (value === "2x2" || value === "small") ? "2x2" : "full"
        if (v === root.size)
            return
        root.size = v
        root.persist()
    }

    function toggleSize() {
        root.setSize(root.small ? "full" : "2x2")
    }

    // ===== persistence =====
    readonly property string script: Directories.script("state/todo-state.sh")

    function snapshot() {
        const items = []
        for (let i = 0; i < listModel.count; i++) {
            const it = listModel.get(i)
            items.push({ title: it.title, done: it.done })
        }
        return JSON.stringify({
            x: root.posX,
            y: root.posY,
            scale: root.posScale,
            shown: root.shown,
            size: root.size,
            items: items
        })
    }

    function restore(text) {
        try {
            const s = JSON.parse(text)
            if (typeof s.x === "number")
                root.posX = s.x
            if (typeof s.y === "number")
                root.posY = s.y
            if (typeof s.scale === "number" && s.scale > 0)
                root.posScale = s.scale
            root.shown = s.shown !== false
            root.size = s.size === "2x2" ? "2x2" : "full"
            listModel.clear()
            for (const it of (s.items ?? [])) {
                if (typeof it.title === "string" && it.title !== "")
                    listModel.append({ title: it.title, done: it.done === true })
            }
        } catch (e) {
            // No file yet (first run) or an unreadable one: start empty.
        }
        root.recount()
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

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: saver.save(root.snapshot())
    }

    // Fire-and-forget save. Queues at most one pending snapshot behind an
    // in-flight save rather than dropping it — same reasoning as
    // PinnedAppsService's `saver`, so the *last* state is what ends up on
    // disk, not whichever save happened to finish first.
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
