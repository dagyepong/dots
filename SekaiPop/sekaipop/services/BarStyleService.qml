pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Which look the top bar has. One value for the whole shell (every
// monitor's bar follows it), remembered across restarts. Transparent is the
// default until a style has been picked.
//
//   float        the rounded, outlined bar, inset from the screen edges
//                by Theme.barFloatInset (the gap outside the workspaces)
//   straight     no rounding, edge to edge: the left and right ends are
//                pushed off screen so only the top and bottom of the bar
//                show
//   transparent  no bar background at all: the pills sit straight on the
//                wallpaper
//   capsule      a slim, fully rounded bar (36 px) with a thick rim and a
//                hard shadow. Its pills are redrawn to match: the
//                workspaces are ringed dots (the active one a wide pill)
//                and every other module is a flat chip. Flat bars only: on
//                a bar standing on the left or right edge it draws as Float
//
// The Settings Panel (Bar -> Style) calls setStyle(). From a keybind:
//   qs -c sekaipop ipc call barstyle cycle
//   qs -c sekaipop ipc call barstyle set capsule
//   qs -c sekaipop ipc call barstyle get
Singleton {
    id: root

    readonly property var names: ["float", "straight", "transparent", "capsule"]

    property string style: "transparent"

    // 0 = float, 1 = straight, 2 = transparent (the default), 3 = capsule — what the bar binds to.
    readonly property int index: Math.max(0, root.names.indexOf(root.style))

    // Set once the user (or IPC) has picked something this session, so
    // the startup load below can't land late and undo it.
    property bool touched: false

    function setStyle(name) {
        if (root.names.indexOf(name) < 0)
            return
        root.touched = true
        if (root.style === name)
            return
        root.style = name
        saver.save(name)
    }

    function cycle() {
        root.setStyle(root.names[(root.index + 1) % root.names.length])
    }

    // ===== persistence =====
    readonly property string script: Directories.script("state/barstyle-state.sh")

    // Runs once, at startup.
    Process {
        running: true
        command: ["sh", root.script, "load"]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim()
                if (!root.touched && root.names.indexOf(name) >= 0)
                    root.style = name
            }
        }
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
        target: "barstyle"

        function set(name: string): void {
            root.setStyle(name)
        }

        function cycle(): void {
            root.cycle()
        }

        function get(): string {
            return root.style
        }
    }
}
