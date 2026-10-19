pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// The desktop clock widget's state — where the card sits, whether it's
// shown, and whether it reads 12h or 24h — kept as its own
// singleton (like TodoService.qml) so anything else can flip it without
// touching ClockWidget.qml:
//
//   import qs.services
//   ...
//   ClockService.toggleFormat()
//
// ClockWidget.qml is the only thing that draws it. The time itself is not
// stored here: the widget reads it from a SystemClock.
//
// Persistence is the same convention as TodoService: a tiny shell script
// (clock-state.sh) run as a Process. Position is saved straight away, the
// rest is debounced.
Singleton {
    id: root

    // False until the saved state has been read. Nothing is written before
    // then, or a fresh start would overwrite what's on disk with defaults.
    property bool loaded: false

    property bool shown: true        // ipc: clock toggle / show / hide
    property bool use24h: false      // double-click on the card / ipc: clock toggleFormat
    // Which look the clock has: 0 Keys, 1 Tower, 2 Sticker, 3 Stack (see
    // ClockWidget.qml). The button that shows when you hover the clock, and
    // ipc: clock nextDesign / setDesign <n>, change it. A first run starts on
    // Stack (the sticker time on end, on the right edge: see ClockWidget.place);
    // what you pick afterwards is remembered.
    property int design: 3
    readonly property int designCount: 4
    property real posX: -1           // -1 = never placed; widget picks a default
    property real posY: -1
    // The shell scale (ShellScale) posX / posY were saved at. They are in design
    // pixels, so the card stays on the same spot of the screen when the shell
    // is scaled up or down: the widget turns them into screen pixels with this
    // and back into design pixels with its current scale. 0 = saved before this
    // was kept (the widget adopts the current scale then, see its `settle`).
    property real posScale: 0
    // The monitor (output name, e.g. "DP-1") the card was last dropped on.
    // Quickshell.screens has no guaranteed order, and after the Refresh
    // button's `hyprctl reload` + hard reload the "first screen" can be a
    // different one than before, so the card is pinned to this one instead.
    // Empty = never dropped yet (the widget uses the first screen).
    property string screenName: ""

    // ===== card =====
    function setPosition(x, y, screen, scale) {
        if (!root.loaded)
            return
        root.posX = x
        root.posY = y
        if (typeof scale === "number" && scale > 0)
            root.posScale = scale
        if (typeof screen === "string" && screen !== "")
            root.screenName = screen
        saveTimer.stop()
        saver.save(root.snapshot())
    }

    function setShown(value) {
        root.shown = value
        root.persist()
    }

    function setUse24h(value) {
        root.use24h = value
        root.persist()
    }

    function toggleFormat() {
        root.setUse24h(!root.use24h)
    }

    function setDesign(value) {
        const n = Math.round(Number(value))
        if (!isFinite(n))
            return
        root.design = Math.max(0, Math.min(root.designCount - 1, n))
        root.persist()
    }

    function cycleDesign() {
        root.setDesign((root.design + 1) % root.designCount)
    }

    // ===== persistence =====
    readonly property string script: Directories.script("state/clock-state.sh")

    function snapshot() {
        return JSON.stringify({
            x: root.posX,
            y: root.posY,
            scale: root.posScale,
            screen: root.screenName,
            shown: root.shown,
            use24h: root.use24h,
            design: root.design
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
            if (typeof s.screen === "string")
                root.screenName = s.screen
            root.shown = s.shown !== false
            root.use24h = s.use24h === true
            if (typeof s.design === "number")
                root.design = Math.max(0, Math.min(root.designCount - 1, Math.round(s.design)))
        } catch (e) {
            // No file yet (first run) or an unreadable one: keep the defaults.
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

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: saver.save(root.snapshot())
    }

    // Fire-and-forget save. Queues at most one pending snapshot behind an
    // in-flight save rather than dropping it, so the *last* state is what
    // ends up on disk (same reasoning as TodoService's `saver`).
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
