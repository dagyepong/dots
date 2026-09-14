// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A U D I O   S E R V I C E                                              │
// │   default sink volume and mute · reactive, via pipewire                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Volume state for the default output.
//
// Pipewire pushes changes, so nothing here polls and the OSD reacts on the
// same frame the key is pressed. A sink has to be bound through a tracker
// before its audio properties are readable.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: root.sink !== null && root.sink.ready

    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool sourceReady: root.source !== null && root.source.ready
    readonly property bool sourceMuted: root.sourceReady ? root.source.audio.muted : false
    readonly property string sourceIcon: root.sourceMuted ? "󰍭" : "󰍬"

    // Pipewire reports a 0–1 factor; everything above the service speaks
    // percent.
    readonly property int volume: root.ready ? Math.round(root.sink.audio.volume * 100) : 0
    readonly property bool muted: root.ready ? root.sink.audio.muted : false

    readonly property string icon: {
        if (!root.ready || root.muted)
            return "󰝟"
        if (root.volume === 0)
            return "󰕿"
        return root.volume < 50 ? "󰖀" : "󰕾"
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    function setVolume(percent: int): void {
        if (!root.ready)
            return
        root.sink.audio.volume = Math.max(0, Math.min(100, percent)) / 100
    }

    function toggleMute(): void {
        if (!root.ready)
            return
        root.sink.audio.muted = !root.sink.audio.muted
    }

    function toggleSourceMute(): void {
        if (!root.sourceReady)
            return
        root.source.audio.muted = !root.source.audio.muted
    }
}
