pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/capture.sh")

    property bool recording: false          // true also when paused
    property bool paused: false
    property int seconds: 0                 // recorded time (pause doesn't count)
    property double activeMs: 0
    property double lastTick: 0
    property string lastState: "idle"

    // ---- Settings for the next recording (right-click menu on the pill) ----
    property string audioMode: "mic"      // off | mic | system | both
    property string micName: ""           // "" = microfono predefinito
    property string outName: ""           // "" = focused monitor (applies to screen recording)

    readonly property bool usesMic: audioMode === "mic" || audioMode === "both"
    readonly property string micTarget: micName !== "" ? micName : "@DEFAULT_SOURCE@"
    property bool micMuted: false

    // ---- Recording finished: the file name is needed ----
    property string pendingPath: ""
    property string pendingScreen: ""
    property string handledPath: ""
    readonly property bool naming: pendingPath !== ""

    function two(n) { return (n < 10 ? "0" : "") + n }

    readonly property string timeText: {
        const h = Math.floor(seconds / 3600)
        const m = Math.floor((seconds % 3600) / 60)
        const s = seconds % 60
        return h > 0 ? h + ":" + two(m) + ":" + two(s) : m + ":" + two(s)
    }

    function open() {
        UiState.captureScreen = Compositor.focusedMonitor
        UiState.launcherOpen = false
        UiState.powerOpen = false
        UiState.wallpaperOpen = false
        UiState.recMenuOpen = false
        UiState.captureOpen = true
    }

    function close() { UiState.captureOpen = false }

    // If recording, stops the recording, otherwise opens/closes the menu
    function toggle() {
        if (recording) stopRecording()
        else if (UiState.captureOpen) close()
        else open()
    }

    function run(action) {
        close()
        const args = ["sh", script, action]
        // Recordings receive the screen, audio mode and microphone chosen in the menu
        if (action.indexOf("rec-") === 0) {
            args.push(outName)
            args.push(audioMode)
            args.push(micName)
        }
        Quickshell.execDetached(args)
    }

    // wf-recorder closes the file cleanly only on SIGINT (the script does it)
    function stopRecording() {
        Quickshell.execDetached(["sh", script, "stop"])
        // Do not depend only on the status poll: for a while after Stop, also look for the finished file
        fallbackTries = 0
        fallbackTimer.restart()
    }

    function pauseRecording()  { Quickshell.execDetached(["sh", script, "pause"]) }
    function resumeRecording() { Quickshell.execDetached(["sh", script, "resume"]) }

    function togglePause() {
        if (!recording) return
        if (paused) resumeRecording()
        else pauseRecording()
    }

    // Mute the microphone while recording (the file continues, with silence)
    function toggleMicMute() {
        micMuted = !micMuted
        Quickshell.execDetached(["pactl", "set-source-mute", micTarget, "toggle"])
    }

    // After recording: save with the chosen name ("" = keep the one with date and time)
    function finishNaming(name) {
        if (pendingPath === "") return
        const p = pendingPath
        handledPath = p
        pendingPath = ""
        Quickshell.execDetached(["sh", script, "rename", p, name])
    }

    function offer(p) {
        if (p === "" || pendingPath !== "" || p === handledPath) return
        console.log("Capture: file to name:", p)
        pendingScreen = Compositor.focusedMonitor
        pendingPath = p
    }

    function onStatus(text) {
        const lines = text.split("\n")
        const st = lines[0].trim()
        const rec = st === "rec" || st === "paused"
        const now = Date.now()

        if (st !== lastState) {
            console.log("Capture:", lastState, "->", st, JSON.stringify((lines[1] || "").trim()))
            lastState = st
        }

        if (rec && !recording) { activeMs = 0; lastTick = now }
        if (rec) {
            if (st === "rec" && lastTick > 0) activeMs += now - lastTick
            lastTick = now
            seconds = Math.floor(activeMs / 1000)
            if (usesMic && st === "rec" && !muteProc.running) muteProc.running = true
        }

        const ended = recording && !rec
        recording = rec
        paused = st === "paused"

        if (!rec) {
            offer((lines[1] || "").trim())
            // Safety net: if the state file did not arrive, look for the latest video
            if (ended) { fallbackTries = 0; fallbackTimer.restart() }
        }
    }

    // Every second: is it recording? is it paused? is there a file to rename?
    Process {
        id: pollProc
        command: ["sh", root.script, "status"]

        stdout: StdioCollector {
            onStreamFinished: root.onStatus(text)
        }
    }

    Process {
        id: latestProc
        command: ["sh", root.script, "latest"]

        stdout: StdioCollector {
            onStreamFinished: root.offer(text.trim())
        }
    }

    // Safety net: after Stop (or when the state changed to "idle") ask for the latest file a few times,
    // every 2 s, until the name prompt has been offered. Merging the parts after a pause can take a while.
    property int fallbackTries: 0

    Timer {
        id: fallbackTimer
        interval: 2000
        repeat: true
        onTriggered: {
            root.fallbackTries++
            if (root.pendingPath !== "" || root.fallbackTries > 12) {
                stop()
                return
            }
            if (!root.recording && !latestProc.running) latestProc.running = true
        }
    }

    // Real mute state (LC_ALL=C: pactl's answer is not translated)
    Process {
        id: muteProc
        command: ["env", "LC_ALL=C", "pactl", "get-source-mute", root.micTarget]

        stdout: StdioCollector {
            onStreamFinished: root.micMuted = /yes/i.test(text)
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: if (!pollProc.running) pollProc.running = true
    }
}
