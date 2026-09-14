// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S Y S T E M   S E R V I C E                                            │
// │   radios and power profile · the state nothing else pushes               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Wi-Fi, Bluetooth and the power profile have no push interface reachable
// from here, so they are polled, only while a panel holds a subscribe().
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/system.py")
    readonly property int pollInterval: 4000

    property int watchers: 0

    property bool wifi: false
    property bool bluetooth: false
    property string powerProfile: ""

    // False until the first successful read, so the UI can hold back rather
    // than showing a plausible-looking default.
    property bool ready: false

    readonly property bool performanceMode: root.powerProfile === "performance"

    readonly property Process statusProcess: Process {
        command: [root.script, "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.ingest(text)
        }
    }

    readonly property Process actionProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: root.ingest(text)
        }
    }

    readonly property Timer pollTimer: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }

    function ingest(text: string): void {
        if (!text || text.trim() === "")
            return
        let state
        try {
            state = JSON.parse(text)
        } catch (error) {
            console.warn("Cannot parse the system state:", error)
            return
        }

        // A null field means the tool behind it is missing; keep the last
        // known value rather than snapping the control to a wrong one.
        if (state.wifi !== null) root.wifi = state.wifi
        if (state.bluetooth !== null) root.bluetooth = state.bluetooth
        if (state.powerProfile) root.powerProfile = state.powerProfile
        root.ready = true
    }

    function refresh(): void {
        root.statusProcess.running = true
    }

    // Pair with release().
    function subscribe(): void {
        root.watchers += 1
        root.refresh()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function toggle(target: string): void {
        // Toggling Bluetooth swaps the audio sink; that volume change is not
        // worth an OSD.
        if (target === "bluetooth")
            OsdService.suppressAudio()
        root.actionProcess.command = [root.script, "toggle", target]
        root.actionProcess.running = true
    }
}
