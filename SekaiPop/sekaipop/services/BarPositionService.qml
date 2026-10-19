pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Which screen edge the bar sits on. One value for the whole shell (every
// monitor's bar follows it), remembered across restarts.
//
//   top, bottom   the bar lies flat: workspaces on the left, clock on
//                 the right (the layout it always had)
//   left, right   the bar stands up: workspaces at the top, clock at the
//                 bottom, every widget stacked in a column
//
// The Settings Panel (Bar -> Position) calls setPosition(). From a
// keybind:
//   qs -c sekaipop ipc call barposition cycle
//   qs -c sekaipop ipc call barposition set left
//   qs -c sekaipop ipc call barposition get
Singleton {
    id: root

    // The order the button steps through.
    readonly property var names: ["top", "right", "bottom", "left"]

    property string position: "top"

    readonly property int index: Math.max(0, root.names.indexOf(root.position))

    // True for left / right: the bar stands up.
    readonly property bool vertical: root.position === "left" || root.position === "right"

    // How thick a bar on the given edge is, in design pixels (before the
    // per-monitor scale). Bar.qml asks for its own edge's value (a bar
    // window never changes edge once it exists, see shell.qml), so a bar
    // that is on its way out can't be resized by the new position.
    function thicknessFor(name) {
        return (name === "left" || name === "right") ? 74 : 63
    }

    // How thick the bar is on the current edge. Popups, the dock and the
    // OSD keep clear of it.
    readonly property int thickness: root.thicknessFor(root.position)

    // True once the saved edge has been read (or there is nothing saved,
    // or reading it failed). shell.qml doesn't create any bar before
    // this, so the bar is built once on the right edge instead of being
    // built on "top" and then moved.
    property bool loaded: false

    // Set once the user (or IPC) has picked something this session, so
    // the startup load below can't land late and undo it.
    property bool touched: false

    function setPosition(name) {
        if (root.names.indexOf(name) < 0)
            return
        root.touched = true
        if (root.position === name)
            return
        root.position = name
        saver.save(name)
    }

    function cycle() {
        root.setPosition(root.names[(root.index + 1) % root.names.length])
    }

    // ===== persistence =====
    readonly property string script: Directories.script("state/barposition-state.sh")

    // Runs once, at startup.
    Process {
        running: true
        command: ["sh", root.script, "load"]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim()
                if (!root.touched && root.names.indexOf(name) >= 0)
                    root.position = name
                root.loaded = true
            }
        }
    }

    // Safety net: if the load above never reports back (no `sh`, a stuck
    // read), start with whatever edge is set rather than having no bar.
    Timer {
        interval: 1500
        running: !root.loaded
        onTriggered: root.loaded = true
    }

    Process {
        id: saver

        property string pending: ""

        function save(name) {
            if (saver.running) {
                saver.pending = name
                return
            }
            saver.pending = ""
            saver.exec(["sh", root.script, "save", name])
        }

        onExited: {
            if (saver.pending !== "") {
                const name = saver.pending
                saver.pending = ""
                saver.exec(["sh", root.script, "save", name])
            }
        }
    }

    IpcHandler {
        target: "barposition"

        function set(name: string): void {
            root.setPosition(name)
        }

        function cycle(): void {
            root.cycle()
        }

        function get(): string {
            return root.position
        }
    }
}
