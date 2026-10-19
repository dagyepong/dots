pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

// ===== volume / mic =====
// ===== brightness =====
// ===== gamma =====
// ===== showing it =====
Singleton {
    id: root

    // ===== what's showing =====
    property bool open: false
    property string kind: "volume"   // "volume" | "mic" | "brightness" | "gamma"
    property int hideDelay: 1600

    // Which monitor OSDPopup.qml should show on — decided fresh every
    // time show() is called (not continuously tracked), the same "decide
    // once per prompt" rule PolkitPrompt.qml uses, just stored here
    // instead of latched locally in each window, so the popup can stay
    // one persistent window per screen (see OSDPopup.qml) rather than
    // being torn down and recreated on every open/close.
    property string targetMonitorName: ""

    function show(newKind) {
        kind = newKind
        targetMonitorName = root.focusedMonitorName()
        open = true
        hideTimer.restart()
    }

    function hide() {
        hideTimer.stop()
        open = false
    }

    Timer {
        id: hideTimer
        interval: root.hideDelay
        onTriggered: root.open = false
    }

    // ===== volume / mic =====
    readonly property real volumeStep: 0.05   // 5%, matches the usual key step

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource].filter(n => n)
    }

    readonly property var sinkAudio: Pipewire.defaultAudioSink?.audio ?? null
    readonly property var sourceAudio: Pipewire.defaultAudioSource?.audio ?? null

    readonly property real speakerVolume: sinkAudio ? sinkAudio.volume * 100 : 0
    readonly property bool speakerMuted: sinkAudio ? sinkAudio.muted : true
    readonly property real micVolume: sourceAudio ? sourceAudio.volume * 100 : 0
    readonly property bool micMuted: sourceAudio ? sourceAudio.muted : true

    // Guards against showing the OSD once for the initial binding as
    // PipeWire connects (both onVolumeChanged/onMutedChanged can fire
    // once during startup as sinkAudio first resolves).
    property bool settledOnce: false
    Timer {
        interval: 400
        running: true
        onTriggered: root.settledOnce = true
    }

    Connections {
        target: root.sinkAudio
        function onVolumeChanged() {
            if (root.settledOnce)
                root.show("volume")
        }
        function onMutedChanged() {
            if (root.settledOnce)
                root.show("volume")
        }
    }

    Connections {
        target: root.sourceAudio
        function onMutedChanged() {
            if (root.settledOnce)
                root.show("mic")
        }
    }

    function volumeUp() {
        if (!root.sinkAudio)
            return
        root.sinkAudio.muted = false
        root.sinkAudio.volume = Math.min(1.0, root.sinkAudio.volume + root.volumeStep)
    }

    function volumeDown() {
        if (!root.sinkAudio)
            return
        root.sinkAudio.volume = Math.max(0.0, root.sinkAudio.volume - root.volumeStep)
    }

    function toggleMute() {
        if (root.sinkAudio)
            root.sinkAudio.muted = !root.sinkAudio.muted
    }

    function toggleMicMute() {
        if (root.sourceAudio)
            root.sourceAudio.muted = !root.sourceAudio.muted
    }

    // ===== brightness =====
    property real brightness: 100
    property int brightnessRawMax: 100
    property bool brightnessDdc: false
    property string brightnessBus: ""

    property var ddcMonitors: []
    property bool ddcDetected: false
    property bool ddcDetecting: false

    function focusedMonitorName() {
        return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    }

    function ensureBackendDetected(then) {
        if (root.ddcDetected) {
            then()
            return
        }
        if (root.ddcDetecting)
            return
        root.ddcDetecting = true
        ddcDetectProc.pendingCallback = then
        ddcDetectProc.running = true
    }

    Process {
        id: ddcDetectProc
        property var pendingCallback: null
        command: ["ddcutil", "detect", "--brief"]
        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => {
                if (!data.startsWith("Display "))
                    return
                const lines = data.split("\n").map(l => l.trim())
                const connLine = lines.find(l => l.startsWith("DRM connector:"))
                const busLine = lines.find(l => l.startsWith("I2C bus:"))
                if (!connLine || !busLine)
                    return
                root.ddcMonitors.push({
                    name: connLine.split("-").slice(1).join("-"),
                    busNum: busLine.split("/dev/i2c-")[1]
                })
            }
        }
        onExited: {
            root.ddcDetected = true
            root.ddcDetecting = false
            const cb = pendingCallback
            pendingCallback = null
            if (cb)
                cb()
        }
    }

    function resolveBackend() {
        const name = root.focusedMonitorName()
        const match = root.ddcMonitors.find(m => m.name === name)
        root.brightnessDdc = !!match
        root.brightnessBus = match ? match.busNum : ""
    }

    // True once `brightness`/`brightnessRawMax` reflect a real reading
    // rather than the property's plain default (100/100) — so the very
    // first brightnessUp()/Down() of a session adjusts from the real
    // current value instead of blindly from 100.
    property bool brightnessSynced: false

    // Reads the current value and, once the read actually lands
    // (brightnessRead is async — ddcutil especially takes a moment),
    // calls `then`. Pass no argument to just refresh in the background.
    function refreshBrightness(then) {
        brightnessRead.pendingCallback = then || null
        brightnessRead.command = root.brightnessDdc
            ? ["ddcutil", "-b", root.brightnessBus, "getvcp", "10", "--brief"]
            : ["sh", "-c", "echo \"$(brightnessctl g 2>/dev/null) $(brightnessctl m 2>/dev/null)\""]
        brightnessRead.running = true
    }

    Process {
        id: brightnessRead
        property var pendingCallback: null
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/)
                const [current, max] = root.brightnessDdc ? [parts[3], parts[4]] : [parts[0], parts[1]]
                const c = parseFloat(current)
                const m = parseFloat(max)
                if (!isNaN(c) && !isNaN(m) && m > 0) {
                    root.brightnessRawMax = m
                    root.brightness = Math.round((c / m) * 100)
                    root.brightnessSynced = true
                }
                const cb = brightnessRead.pendingCallback
                brightnessRead.pendingCallback = null
                if (cb)
                    cb()
            }
        }
    }

    function applyBrightness(percent) {
        root.brightness = Math.max(0, Math.min(100, Math.round(percent)))
        settleBrightness.restart()
        root.show("brightness")
    }

    Timer {
        id: settleBrightness
        interval: 80
        onTriggered: {
            if (brightnessSet.running)
                settleBrightness.restart()
            else
                brightnessSet.running = true
        }
    }

    Process {
        id: brightnessSet
        command: {
            if (root.brightnessDdc) {
                const raw = Math.max(1, Math.round((root.brightness / 100) * root.brightnessRawMax))
                return ["ddcutil", "-b", root.brightnessBus, "setvcp", "10", String(raw)]
            }
            const pct = Math.round(root.brightness)
            return ["brightnessctl", "--class", "backlight", "s", (pct <= 0 ? "1" : pct + "%"), "--quiet"]
        }
    }

    // Backend known + a real reading in hand, then apply `delta` (or
    // jump straight to `absolute` when that's set instead) on top of it.
    function withRealBrightness(delta, absolute) {
        root.resolveBackend()
        if (root.brightnessSynced) {
            root.applyBrightness(absolute !== undefined ? absolute : root.brightness + delta)
            return
        }
        root.refreshBrightness(() => {
            root.applyBrightness(absolute !== undefined ? absolute : root.brightness + delta)
        })
    }

    function brightnessUp() {
        ensureBackendDetected(() => root.withRealBrightness(5, undefined))
    }

    function brightnessDown() {
        ensureBackendDetected(() => root.withRealBrightness(-5, undefined))
    }

    function setBrightness(percent) {
        ensureBackendDetected(() => root.withRealBrightness(0, percent))
    }

    // ===== gamma =====
    property real gamma: 100
    readonly property real gammaStep: 5
    readonly property real gammaMin: 10   // below this the screen is unusably dark
    property bool gammaSynced: false

    // Reads hyprsunset's current gamma once, then calls `then`. Anything
    // that doesn't parse (hyprsunset not running yet, hyprctl missing)
    // leaves the default of 100 — "unchanged".
    function withRealGamma(then) {
        if (root.gammaSynced) {
            then()
            return
        }
        gammaRead.pendingCallback = then
        gammaRead.running = true
    }

    Process {
        id: gammaRead
        property var pendingCallback: null
        command: ["sh", "-c", "timeout 2 hyprctl hyprsunset gamma 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const g = parseFloat(text.trim())
                if (!isNaN(g) && g > 0)
                    root.gamma = Math.max(root.gammaMin, Math.min(100, Math.round(g)))
                root.gammaSynced = true
                const cb = gammaRead.pendingCallback
                gammaRead.pendingCallback = null
                if (cb)
                    cb()
            }
        }
    }

    // The Quick Panel's gamma bar can change the same value, so the cached
    // reading is dropped after a quiet moment and the next key re-reads it.
    Timer {
        id: gammaStale
        interval: 3000
        onTriggered: root.gammaSynced = false
    }

    function applyGamma(percent) {
        root.gamma = Math.max(root.gammaMin, Math.min(100, Math.round(percent)))
        gammaStale.restart()
        settleGamma.restart()
        root.show("gamma")
    }

    Timer {
        id: settleGamma
        interval: 80
        onTriggered: {
            if (gammaSet.running)
                settleGamma.restart()
            else
                gammaSet.running = true
        }
    }

    Process {
        id: gammaSet
        command: ["sh", "-c",
            "pidof hyprsunset >/dev/null || { setsid hyprsunset >/dev/null 2>&1 & sleep 0.6; }; hyprctl hyprsunset gamma "
            + Math.round(root.gamma)]
    }

    function gammaUp() {
        root.withRealGamma(() => root.applyGamma(root.gamma + root.gammaStep))
    }

    function gammaDown() {
        root.withRealGamma(() => root.applyGamma(root.gamma - root.gammaStep))
    }

    function setGamma(percent) {
        root.withRealGamma(() => root.applyGamma(percent))
    }

    IpcHandler {
        target: "osd"

        function volumeUp(): void { root.volumeUp() }
        function volumeDown(): void { root.volumeDown() }
        function toggleMute(): void { root.toggleMute() }
        function toggleMicMute(): void { root.toggleMicMute() }
        function brightnessUp(): void { root.brightnessUp() }
        function brightnessDown(): void { root.brightnessDown() }
        function gammaUp(): void { root.gammaUp() }
        function gammaDown(): void { root.gammaDown() }
        function setGamma(percent: int): void { root.setGamma(percent) }
        function hide(): void { root.hide() }
    }
}
