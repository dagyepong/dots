pragma Singleton

import QtQuick
import Quickshell
import qs.services
import Quickshell.Io

Singleton {
    id: root

    property bool pinned: false       // pinned (qs ipc call system toggle)
    property bool peek: false         // temporary appearance (qs ipc call system show)
    property bool edgeOpen: false     // mouse on the edge or the panel
    property bool edgeHot: false
    property string screen: ""        // monitor to show it on

    readonly property bool shown: pinned || peek || edgeOpen
    property int users: 0              // other views (dashboard) that need live readings
    readonly property bool polling: shown || users > 0

    property real cpu: 0              // 0..1
    property real ramUsed: 0          // byte
    property real ramTotal: 1
    property real diskUsed: 0
    property real diskTotal: 1
    property real netDown: 0          // byte/s
    property real netUp: 0

    readonly property real ram: ramTotal > 0 ? ramUsed / ramTotal : 0
    readonly property real disk: diskTotal > 0 ? diskUsed / diskTotal : 0

    property var prevCpu: null
    property var prevNet: null
    property double prevTime: 0

    function fmtRate(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/s"
        if (b >= 1024) return Math.round(b / 1024) + " KB/s"
        return Math.round(b) + " B/s"
    }

    // Called from the hot area on the edge (and from the panel itself)
    function setEdge(hovered, screenName) {
        if (hovered) {
            screen = screenName
            edgeHot = true
            edgeOpen = true
            closeTimer.stop()
        } else {
            edgeHot = false
            closeTimer.restart()
        }
    }

    function show(ms) {
        screen = Compositor.focusedMonitor
        peek = true
        peekTimer.interval = ms
        peekTimer.restart()
    }

    function togglePin() {
        if (pinned) {
            pinned = false
            peek = false
        } else {
            screen = Compositor.focusedMonitor
            pinned = true
        }
    }

    function hide() {
        pinned = false
        peek = false
        edgeOpen = false
        peekTimer.stop()
    }

    // When it reappears, readings restart from zero (no fake spikes)
    onPollingChanged: {
        prevCpu = null
        prevNet = null
    }

    Timer {
        id: closeTimer
        interval: 260
        onTriggered: if (!root.edgeHot) root.edgeOpen = false
    }

    Timer {
        id: peekTimer
        onTriggered: root.peek = false
    }

    function parse(text) {
        const now = Date.now()
        const lines = text.split("\n")

        for (let i = 0; i < lines.length; i++) {
            const f = lines[i].trim().split(/\s+/)
            if (f.length < 2) continue

            if (f[0] === "cpu") {
                const n = f.slice(1).map(Number)
                const total = n.slice(0, 8).reduce((a, b) => a + b, 0)
                const idle = n[3] + n[4]
                if (prevCpu) {
                    const dt = total - prevCpu.total
                    const di = idle - prevCpu.idle
                    if (dt > 0) cpu = Math.max(0, Math.min(1, 1 - di / dt))
                }
                prevCpu = { total: total, idle: idle }
            } else if (f[0] === "memtotal") {
                ramTotal = parseFloat(f[1]) * 1024
            } else if (f[0] === "memavail") {
                ramUsed = Math.max(0, ramTotal - parseFloat(f[1]) * 1024)
            } else if (f[0] === "net") {
                const rx = parseFloat(f[1])
                const tx = parseFloat(f[2])
                if (prevNet && now > prevTime) {
                    const s = (now - prevTime) / 1000
                    netDown = Math.max(0, (rx - prevNet.rx) / s)
                    netUp = Math.max(0, (tx - prevNet.tx) / s)
                }
                prevNet = { rx: rx, tx: tx }
                prevTime = now
            } else if (f[0] === "disk") {
                diskTotal = parseFloat(f[1])
                diskUsed = parseFloat(f[2])
            }
        }
    }

    Process {
        id: proc
        command: ["sh", Quickshell.shellPath("scripts/sysstats.sh")]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    // Reads data only while the panel is visible
    Timer {
        interval: 1000
        running: root.polling
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!proc.running) proc.running = true
    }
}
