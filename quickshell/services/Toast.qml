pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    property var current: null          // {kind, app, summary, body, tone, duration}
    property string screen: ""
    property bool paused: false
    property int lastLevel: 100         // last battery threshold already reported

    readonly property bool active: current !== null

    function push(item) {
        screen = Compositor.focusedMonitor
        current = item
        paused = false
        hideTimer.interval = item.duration || 5000
        hideTimer.restart()
    }

    function dismiss() {
        hideTimer.stop()
        current = null
        paused = false
    }

    // Mouse over the toast: stays open
    onPausedChanged: {
        if (paused) hideTimer.stop()
        else if (current !== null) hideTimer.restart()
    }

    Timer {
        id: hideTimer
        onTriggered: root.dismiss()
    }

    // ---------- Low battery warning (20%, 10%, 5%) ----------
    function checkBattery() {
        if (!Battery.present) return
        const p = Math.round(Battery.percent * 100)

        if (Battery.charging || Battery.full || p > 25) {
            lastLevel = 100
            return
        }

        const levels = [5, 10, 20]
        let hit = -1
        for (let i = 0; i < levels.length; i++) {
            if (p <= levels[i]) { hit = levels[i]; break }
        }
        if (hit < 0 || hit >= lastLevel) return

        lastLevel = hit
        push({
            kind: "battery",
            app: "Battery",
            summary: "Battery at " + p + "%",
            body: Battery.timeText !== "" ? Battery.timeText : "Plug in the charger",
            tone: "danger",
            duration: hit <= 5 ? 12000 : 8000
        })
    }

    Connections {
        target: Battery
        function onPercentChanged()  { root.checkBattery() }
        function onChargingChanged() { root.checkBattery() }
        function onPresentChanged()  { root.checkBattery() }
    }
}
