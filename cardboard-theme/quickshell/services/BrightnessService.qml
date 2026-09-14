// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B R I G H T N E S S   S E R V I C E                                    │
// │   backlight level · watched on sysfs, set through brightnessctl          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Backlight level, watched on sysfs so the OSD also reacts to the hardware
// brightness keys. The device (intel_backlight, amdgpu_bl0, …) is discovered
// once at startup.
Singleton {
    id: root

    property string device: ""
    property int raw: 0
    property int maximum: 0

    readonly property bool available: root.maximum > 0
    readonly property int percent: root.available ? Math.round(root.raw / root.maximum * 100) : 0

    readonly property string icon: {
        if (root.percent < 34)
            return "󰃞"
        return root.percent < 67 ? "󰃟" : "󰃠"
    }

    readonly property Process discovery: Process {
        command: ["sh", "-c", "ls -1 /sys/class/backlight/ 2>/dev/null | head -1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim()
                if (name !== "")
                    root.device = name
            }
        }
    }

    readonly property FileView maxView: FileView {
        path: root.device === "" ? "" : `/sys/class/backlight/${root.device}/max_brightness`
        onLoaded: root.maximum = parseInt(text().trim()) || 0
    }

    readonly property FileView levelView: FileView {
        path: root.device === "" ? "" : `/sys/class/backlight/${root.device}/brightness`
        watchChanges: true
        onLoaded: root.raw = parseInt(text().trim()) || 0
        onFileChanged: reload()
    }

    // sysfs isn't user-writable; brightnessctl ships the udev rule that
    // allows it.
    readonly property Process setter: Process {}

    function setPercent(value: int): void {
        if (!root.available)
            return
        const clamped = Math.max(1, Math.min(100, value))
        root.setter.command = ["brightnessctl", "--quiet", "set", `${clamped}%`]
        root.setter.running = true
    }
}
