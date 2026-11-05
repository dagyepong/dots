pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.services

Singleton {
    id: root

    property bool on: false                  // mode state: does NOT depend on the daemon
    property string profile: ""              // current system profile (informational only)
    property string previousProfile: "balanced"
    property real previousBrightness: -1
    property bool previousBluetooth: false

    // Less work for the GPU (like Game Mode, but without touching gaps and corners)
    readonly property string luaSaving:
        "hl.config({ animations = { enabled = false }, "
        + "decoration = { blur = { enabled = false }, shadow = { enabled = false } } })"

    readonly property string kdlSaving:
        "animations { off; }\n"
        + "window-rule { background-effect { blur false; } }"

    function refresh() { getProc.running = true }

    function setProfile(p) {
        setProc.command = ["sh", "-c", "powerprofilesctl set \"$1\"", "sh", p]
        setProc.running = true
    }

    function reportError() {
        Toast.push({
            kind: "notification",
            app: "Eco Mode",
            summary: "Power profile not applied",
            body: "powerprofilesctl not responding: check power-profiles-daemon",
            tone: "danger",
            duration: 9000
        })
    }

    function set(enable) {
        if (enable === on) return
        on = enable

        if (enable) {
            previousProfile = (profile !== "" && profile !== "power-saver") ? profile : "balanced"
            previousBrightness = Brightness.available ? Brightness.percent : -1

            if (GameMode.on) GameMode.set(false)       // one at a time
            setProfile("power-saver")
            if (previousBrightness > 0.35) Brightness.setPercent(0.35)

            // Bluetooth off (and remember it to turn it back on later)
            const bt = Bluetooth.defaultAdapter
            previousBluetooth = bt ? bt.enabled : false
            if (bt && bt.enabled) bt.enabled = false
            applyTimer.restart()
        } else {
            applyTimer.stop()
            setProfile(previousProfile)
            if (previousBrightness > 0) Brightness.setPercent(previousBrightness)

            // Bluetooth: turn it back on only if it was on before
            const bt2 = Bluetooth.defaultAdapter
            if (previousBluetooth && bt2) bt2.enabled = true
            Compositor.tweakReset()
        }
    }

    function toggle() { set(!on) }

    // Wait a moment (Game Mode, if it was on, is reloading the config)
    Timer {
        id: applyTimer
        interval: 400
        onTriggered: Compositor.tweak(root.luaSaving, root.kdlSaving)
    }

    Process {
        id: getProc
        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.profile = text.trim()
        }
    }

    Process {
        id: setProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) root.reportError()
            root.refresh()
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
