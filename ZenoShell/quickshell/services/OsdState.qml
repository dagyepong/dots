pragma Singleton

import QtQuick
import Quickshell
import qs.services

// What the volume / brightness OSD shows. Every style draws it in its own way (osd/*.qml, and the
// Attached Dashboard turns its bar into the OSD), but they all read it from here.
Singleton {
    id: root

    property string kind: "volume"     // volume | brightness
    property bool shown: false
    property bool armed: false         // no OSD while the shell is loading

    readonly property real volume: Audio.muted ? 0 : Math.min(1, Audio.volume)
    readonly property real brightness: Brightness.percent
    readonly property real value: kind === "volume" ? volume : brightness
    readonly property string icon: kind === "volume" ? "volume" : "sun"
    readonly property int iconLevel: (kind === "volume" && Audio.muted) ? 0 : (value > 0.5 ? 2 : 1)

    function show(k) {
        if (!armed || !Settings.osdEnabled || UiState.controlOpen || Lid.recent) return
        kind = k
        shown = true
        hideTimer.restart()
    }

    Timer { interval: 2000; running: true; onTriggered: root.armed = true }
    Timer { id: hideTimer; interval: Settings.osdMs; onTriggered: root.shown = false }

    Connections {
        target: Audio
        function onVolumeChanged() { root.show("volume") }
        function onMutedChanged()  { root.show("volume") }
    }

    Connections {
        target: Brightness
        function onPercentChanged() { root.show("brightness") }
    }
}
