pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    // ---- Settings ----
    readonly property bool enabled: true             // locks the screen when the lid closes
    readonly property bool screenOff: true           // turns off the backlight with the lid closed
    readonly property int suspendAfterMinutes: 5    // 0 = never suspend

    property bool closed: false
    property bool recent: false                      // true for a few seconds after every close/open
    property bool backlightOff: false

    function update(t) {
        if (t.trim() === "") return                  // no lid sensor: do nothing
        const c = /closed/i.test(t)
        if (c === closed) return

        closed = c
        recent = true
        recentTimer.restart()

        if (c) {
            // Lock first, then (once the lockscreen is drawn) the screen turns off
            UiState.lockTest = false
            UiState.locked = true
            if (screenOff) offTimer.restart()
            if (suspendAfterMinutes > 0) suspendTimer.restart()
        } else {
            offTimer.stop()
            suspendTimer.stop()
            if (backlightOff) {
                Quickshell.execDetached(["brightnessctl", "-r"])
                backlightOff = false
            }
        }
    }

    // Prevents logind from suspending when the lid closes
    Process {
        command: ["sh", Quickshell.shellPath("scripts/lid-inhibit.sh")]
        running: root.enabled
    }

    // Lid state (one read per second)
    Process {
        id: poll
        command: ["sh", "-c", "cat /proc/acpi/button/lid/*/state 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.update(text)
        }
    }

    Timer {
        interval: 1000
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!poll.running) poll.running = true
    }

    Timer {
        id: recentTimer
        interval: 4000
        onTriggered: root.recent = false
    }

    Timer {
        id: offTimer
        interval: 900
        onTriggered: {
            if (!root.closed) return
            Quickshell.execDetached(["brightnessctl", "-s", "set", "0"])
            root.backlightOff = true
        }
    }

    Timer {
        id: suspendTimer
        interval: Math.max(1, root.suspendAfterMinutes) * 60000
        onTriggered: if (root.closed) Quickshell.execDetached(["systemctl", "suspend"])
    }
}
