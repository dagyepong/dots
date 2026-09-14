// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S U N S E T   S E R V I C E                                            │
// │   night light · runs hyprsunset while enabled                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Night light through hyprsunset, which sets the gamma ramp. Unlike a screen
// shader, that stays out of screenshots and survives `hyprctl reload`.
//
// The shell owns the process: running means on, and the compositor restores
// the ramp when the client disconnects. Temperature changes go through
// `hyprctl hyprsunset` rather than a restart, which would flash daylight,
// coalesced to 120 ms while a slider is dragged.
Singleton {
    id: root

    // 6500 K is a no-op in hyprsunset, so the cool end stops short of it.
    readonly property int warmest: 2500
    readonly property int coolest: 6000

    readonly property string icon: root.on ? "󰃜" : "󰃝"

    readonly property int temperature: SettingsService.nightTemperature

    // hyprsunset is optional; checked once so the tile can say it is missing.
    property bool available: false

    readonly property bool on: root.filter.running

    readonly property string detail: {
        if (!root.available)
            return "Needs hyprsunset"
        return root.on ? `${root.temperature} K` : "Daylight"
    }

    readonly property Process probe: Process {
        command: ["sh", "-c", "command -v hyprsunset"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.available = text.trim() !== ""
        }
    }

    // Bound to the setting, which also restores it at login. `shell.qml`
    // touches this singleton at startup so that happens before anything
    // opens the control centre.
    readonly property Process filter: Process {
        command: ["hyprsunset", "--temperature", String(root.temperature)]
        running: SettingsService.nightLight && root.available

        // Exited on its own, usually because another client already holds
        // the gamma ramp. Turn the setting off to match, and say so.
        onExited: {
            if (!SettingsService.nightLight)
                return
            SettingsService.set("nightLight", false)
            OsdService.requested(root.icon, "Night light stopped", -1)
        }
    }

    onTemperatureChanged: {
        if (root.on)
            root.retune.restart()
    }

    readonly property Timer retune: Timer {
        interval: 120
        onTriggered: Quickshell.execDetached(
            ["hyprctl", "hyprsunset", "temperature", String(root.temperature)])
    }

    function toggle(): void {
        if (!root.available)
            return
        SettingsService.set("nightLight", !SettingsService.nightLight)
    }
}
