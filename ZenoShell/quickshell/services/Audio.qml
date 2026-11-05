pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property real maxVolume: 1.2           // boost up to 120%

    // ---------- Output ----------
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false

    // ---------- Microphone ----------
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micReady: source !== null && source.audio !== null
    readonly property real micVolume: micReady ? source.audio.volume : 0
    readonly property bool micMuted: micReady ? source.audio.muted : false

    // Hardware audio outputs (not individual apps)
    readonly property var sinks: {
        const v = Pipewire.nodes.values
        const out = []
        for (let i = 0; i < v.length; i++)
            if (v[i].isSink && !v[i].isStream) out.push(v[i])
        return out
    }

    // Audio inputs (microphones)
    readonly property var sources: {
        const v = Pipewire.nodes.values
        const out = []
        for (let i = 0; i < v.length; i++) {
            const n = v[i]
            if (!n.isSink && !n.isStream && n.audio !== null) out.push(n)
        }
        return out
    }

    // Apps that are playing audio: recognized by the node class
    readonly property var apps: {
        const v = Pipewire.nodes.values
        const out = []
        for (let i = 0; i < v.length; i++) {
            const n = v[i]
            if (n.audio === null) continue

            const p = n.properties
            const cls = p ? (p["media.class"] || "") : ""

            if (cls !== "") {
                if (cls !== "Stream/Output/Audio") continue
            } else if (!n.isStream || n.isSink) {
                continue                        // class not available: fall back to the flags
            }
            out.push(n)
        }
        return out
    }

    // Bind all nodes: needed to be able to read their volume and properties
    readonly property var tracked: {
        const v = Pipewire.nodes.values
        const out = []
        for (let i = 0; i < v.length; i++) out.push(v[i])
        return out
    }

    function clamp(v) { return Math.max(0, Math.min(maxVolume, v)) }

    function setVolume(v) {
        if (ready) sink.audio.volume = clamp(v)
    }

    function toggleMute() {
        if (ready) sink.audio.muted = !sink.audio.muted
    }

    function setMicVolume(v) {
        if (micReady) source.audio.volume = clamp(v)
    }

    function toggleMicMute() {
        if (micReady) source.audio.muted = !source.audio.muted
    }

    function setDefault(node) {
        Pipewire.preferredDefaultAudioSink = node
    }

    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node
    }

    // Diagnostics: writes to the log all PipeWire nodes the shell sees
    function dump() {
        const v = Pipewire.nodes.values
        console.log("--- PipeWire nodes:", v.length)
        for (let i = 0; i < v.length; i++) {
            const n = v[i]
            const p = n.properties
            console.log("node", n.id, "|", n.name,
                        "| stream:", n.isStream,
                        "| sink:", n.isSink,
                        "| audio:", n.audio !== null,
                        "| classe:", p ? p["media.class"] : "(n/d)")
        }
        console.log("--- recognized apps:", apps.length)
    }

    PwObjectTracker {
        objects: root.tracked
    }

    // Default output and input always bound: the volume follows changes made from outside too
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n !== null)
    }
}
