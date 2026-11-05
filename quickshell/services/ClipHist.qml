pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var items: []              // [{id, raw, preview, isImage, w, h}]
    property var ready: ({})            // id -> true when the thumbnail exists
    property var pendingThumbs: []
    property bool available: false
    property bool active: false         // true while the page is visible (refreshes the list)

    readonly property string thumbDir: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-clip"

    function refresh() {
        if (available && !listProc.running) listProc.running = true
    }

    function paste(id) {
        Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/clip-paste.sh"), String(id)])
    }

    function remove(raw) {
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "sh", raw])
        afterDelete.restart()
    }

    function wipe() {
        Quickshell.execDetached(["cliphist", "wipe"])
        items = []
    }

    // Are the required tools present?
    Process {
        command: ["sh", "-c", "command -v cliphist >/dev/null && command -v wl-paste >/dev/null"]
        running: true
        onExited: exitCode => root.available = (exitCode === 0)
    }

    // Saves everything you copy (text and images)
    Process {
        command: ["wl-paste", "--type", "text", "--watch", "cliphist", "store"]
        running: root.available
    }

    Process {
        command: ["wl-paste", "--type", "image", "--watch", "cliphist", "store"]
        running: root.available
    }

    // List of the latest items
    Process {
        id: listProc
        command: ["sh", "-c", "cliphist list | head -n 40"]

        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                const wanted = []
                const lines = text.split("\n")

                for (let i = 0; i < lines.length; i++) {
                    const ln = lines[i]
                    const t = ln.indexOf("\t")
                    if (t < 0) continue

                    const id = ln.slice(0, t)
                    const prev = ln.slice(t + 1)
                    const m = /^\[\[ binary data [^\]]*? (png|jpe?g|webp|bmp|gif) (\d+)x(\d+) \]\]$/.exec(prev)

                    out.push({
                        id: id,
                        raw: ln,
                        preview: prev,
                        isImage: !!m,
                        w: m ? parseInt(m[2]) : 0,
                        h: m ? parseInt(m[3]) : 0
                    })

                    if (m && !root.ready[id] && wanted.length < 8) wanted.push(id)
                }

                root.items = out

                if (wanted.length > 0 && !thumbProc.running) {
                    root.pendingThumbs = wanted
                    thumbProc.command = ["sh", Quickshell.shellPath("scripts/clip-thumbs.sh"), root.thumbDir]
                                        .concat(wanted)
                    thumbProc.running = true
                }
            }
        }
    }

    // Image thumbnails
    Process {
        id: thumbProc
        onExited: {
            const next = Object.assign({}, root.ready)
            for (let i = 0; i < root.pendingThumbs.length; i++) next[root.pendingThumbs[i]] = true
            root.ready = next
        }
    }

    Timer {
        interval: 1500
        running: root.active
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: afterDelete
        interval: 300
        onTriggered: root.refresh()
    }
}
