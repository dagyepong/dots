pragma Singleton
import QtQuick
import Quickshell

// Lets the bar's playful popups (SekaiPopup.qml: Calendar, Battery, Weather, Media, Discord)
// hand over to each other cleanly. When you press the next button, the
// popup that is still being swallowed is put away at once instead of
// shrinking beside the new one that is popping in. Each popup calls
// `opening()` as it starts to open; every other popup that is closed and
// still on its way out sees `serial` change and snaps away.
Singleton {
    id: root

    property int serial: 0

    function opening() {
        root.serial++
    }
}
