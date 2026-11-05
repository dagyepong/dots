pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Brightness of external monitors via ddcutil (only if installed and supported)
Singleton {
    id: root

    property bool detected: false
    property bool installed: true
    property var bus: ({})          // "DP-1" -> ddcutil display number
    property var levels: ({})       // "DP-1" -> 0..1
    property var maxes: ({})        // "DP-1" -> maximum value (usually 100)
    property var queue: []
    property string pendingName: ""
    property bool dirty: false

    function has(name) { return bus[name] !== undefined }

    function refresh() {
        if (!detected) {
            if (!detectProc.running) detectProc.running = true
        } else {
            readAll()
        }
    }

    function readAll() {
        queue = Object.keys(bus)
        nextRead()
    }

    function nextRead() {
        if (readProc.running || queue.length === 0) return
        const n = queue.shift()
        readProc.tag = n
        readProc.command = ["sh", "-c", "ddcutil --display " + bus[n] + " getvcp 10 --brief 2>/dev/null"]
        readProc.running = true
    }

    function setLevel(name, v) {
        if (!has(name)) return
        const l = Object.assign({}, levels)
        l[name] = Math.max(0, Math.min(1, v))
        levels = l
        pendingName = name
        debounce.restart()
    }

    function flush() {
        if (setProc.running) { dirty = true; return }
        const n = pendingName
        if (!has(n)) return
        const max = maxes[n] || 100
        setProc.command = ["sh", "-c", "ddcutil --display " + bus[n] + " setvcp 10 "
                           + Math.round(levels[n] * max) + " --noverify 2>/dev/null"]
        setProc.running = true
    }

    // ddcutil is slow (about a second): waits until you finish dragging
    Timer {
        id: debounce
        interval: 450
        onTriggered: root.flush()
    }

    Process {
        id: detectProc
        command: ["sh", "-c",
            "command -v ddcutil >/dev/null 2>&1 || { echo NOTINSTALLED; exit 0; }; ddcutil detect --brief 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.indexOf("NOTINSTALLED") >= 0) { root.installed = false; return }
                const b = {}
                const parts = text.split(/\n(?=Display \d+)/)
                for (let i = 0; i < parts.length; i++) {
                    const d = /^Display (\d+)/.exec(parts[i].trim())
                    const c = /DRM[_ ]connector:\s+card\d+-(\S+)/.exec(parts[i])
                    if (d && c) b[c[1]] = parseInt(d[1])
                }
                root.bus = b
            }
        }

        onExited: {
            root.detected = true
            root.readAll()
        }
    }

    Process {
        id: readProc
        property string tag: ""

        stdout: StdioCollector {
            onStreamFinished: {
                // es. "VCP 10 C 55 100"
                const m = /VCP\s+10\s+\w+\s+(\d+)\s+(\d+)/.exec(text)
                if (!m) return
                const max = parseInt(m[2]) || 100
                const l = Object.assign({}, root.levels)
                const x = Object.assign({}, root.maxes)
                l[readProc.tag] = parseInt(m[1]) / max
                x[readProc.tag] = max
                root.levels = l
                root.maxes = x
            }
        }

        onExited: root.nextRead()
    }

    Process {
        id: setProc
        onExited: {
            if (root.dirty) {
                root.dirty = false
                root.flush()
            }
        }
    }
}
