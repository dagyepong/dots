pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Audio spectrum for the music card. Needs "cava" (pacman -S cava); without it the views fall back to the progress dots.
Singleton {
    id: root

    readonly property int count: 10
    property var levels: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]     // 0..1
    property bool available: false
    property int users: 0                                    // views that show the spectrum right now

    readonly property bool running: available && users > 0 && Media.playing

    function parse(line) {
        const f = line.split(";")
        const out = []
        for (let i = 0; i < count; i++) {
            const v = parseFloat(f[i])
            out.push(isNaN(v) ? 0 : Math.max(0, Math.min(1, v / 100)))
        }
        levels = out
    }

    onRunningChanged: if (!running) levels = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    Process {
        running: true
        command: ["sh", "-c", "command -v cava"]
        stdout: StdioCollector {
            onStreamFinished: root.available = text.trim() !== ""
        }
    }

    Process {
        running: root.running
        command: ["cava", "-p", Quickshell.shellPath("scripts/cava.conf")]
        stdout: SplitParser {
            onRead: line => root.parse(line)
        }
    }
}
