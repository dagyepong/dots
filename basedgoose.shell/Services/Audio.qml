pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.ready ? Pipewire.defaultAudioSink : null
    readonly property PwNode source: Pipewire.ready ? Pipewire.defaultAudioSource : null

    readonly property bool sinkReady: sink && sink.ready && sink.audio
    readonly property bool sourceReady: source && source.ready && source.audio

    readonly property bool muted: sinkReady ? (sink.audio.muted ?? false) : false

    readonly property real volume: {
        if (!sinkReady) return 0
        const vol = sink.audio.volume
        if (vol === undefined || vol === null || isNaN(vol)) return 0
        return Math.max(0, Math.min(1, vol))
    }

    readonly property int percentage: Math.round(volume * 100)

    readonly property bool sourceMuted: sourceReady ? (source.audio.muted ?? false) : false
    readonly property real sourceVolume: sourceReady ? (source.audio.volume ?? 0) : 0
    readonly property int sourcePercentage: Math.round(sourceVolume * 100)

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    PwObjectTracker {
        objects: root.source ? [root.source] : []
    }

    function setVolume(newVolume) {
        if (!Pipewire.ready || !sinkReady)
            return

        sink.audio.muted = false
        sink.audio.volume = Math.max(0, Math.min(1, newVolume))
    }

    function toggleMute() {
        if (!Pipewire.ready || !sinkReady)
            return

        sink.audio.muted = !sink.audio.muted
    }

    function increaseVolume() {
        setVolume(volume + 0.05)
    }

    function decreaseVolume() {
        setVolume(volume - 0.05)
    }

    function setSourceVolume(newVolume) {
        if (!Pipewire.ready || !sourceReady)
            return

        source.audio.muted = false
        source.audio.volume = Math.max(0, Math.min(1, newVolume))
    }

    function toggleSourceMute() {
        if (!Pipewire.ready || !sourceReady)
            return

        source.audio.muted = !source.audio.muted
    }
}
