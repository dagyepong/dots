pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    property int percentage: 0
    property bool muted: true

    readonly property PwNode sink: Pipewire.ready ? Pipewire.defaultAudioSink : null
    readonly property bool sinkReady: sink && sink.ready && sink.audio

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    function sync() {
        if (!root.sinkReady)
            return;

        const vol = root.sink.audio.volume;
        if (vol !== undefined && !isNaN(vol)) {
            root.percentage = Math.round(
                Math.max(0, Math.min(1.5, vol)) * 100
            );
        }

        root.muted = root.sink.audio.muted ?? true;
    }

    Connections {
        target: sinkReady ? sink.audio : null

        function onVolumeChanged() { root.sync(); }
        function onMutedChanged() { root.sync(); }
    }

    Connections {
        target: Pipewire

        function onDefaultAudioSinkChanged() {
            Qt.callLater(root.sync)
        }
    }

    onSinkReadyChanged: {
        if (sinkReady) {
            sync()
        }
    }

    Component.onCompleted: {
        console.log("[VolumeMonitor] loaded");
    }
}
