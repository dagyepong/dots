pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real percent: 0      // 0..1
    property bool available: false
    property string device: ""
    property real maxValue: 0
    property double lastSet: 0

    function refresh() { getProc.running = true }

    function setPercent(p) {
        percent = Math.max(0.01, Math.min(1, p))
        lastSet = Date.now()
        debounce.restart()
    }

    Process {
        id: getProc
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                // es. "intel_backlight,backlight,5000,25%,20000"
                const f = text.trim().split(",")
                if (f.length >= 5) {
                    root.device = f[0]
                    root.maxValue = parseInt(f[4]) || 0
                    root.percent = (parseInt(f[3]) || 0) / 100
                    root.available = true
                }
            }
        }
    }

    Process { id: setProc }

    Timer {
        id: debounce
        interval: 60
        onTriggered: {
            setProc.command = ["brightnessctl", "set", Math.round(root.percent * 100) + "%"]
            setProc.running = true
        }
    }

    // Direct read from sysfs, without launching processes
    FileView {
        id: bl
        path: root.device !== "" ? "/sys/class/backlight/" + root.device + "/brightness" : ""
        blockLoading: true
    }

    Timer {
        interval: 400
        running: root.available && root.maxValue > 0
        repeat: true
        onTriggered: {
            if (Date.now() - root.lastSet < 800) return
            bl.reload()
            const cur = parseInt(bl.text())
            if (!isNaN(cur)) root.percent = Math.max(0, Math.min(1, cur / root.maxValue))
        }
    }

    Component.onCompleted: refresh()
}
