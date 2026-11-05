pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.theme

Singleton {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev !== null && dev.ready && dev.isPresent

    readonly property real percent: {
        if (!present) return 0
        const p = dev.percentage
        return p > 1 ? p / 100 : p
    }

    readonly property bool charging: present
        && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: present && dev.state === UPowerDeviceState.FullyCharged
    readonly property bool low: present && !charging && !full && percent <= 0.2
    readonly property bool critical: present && !charging && !full && percent <= 0.1

    // accent when charging, red when low, otherwise normal text
    readonly property color tone: (charging || full) ? Theme.accent
                                  : (low ? Theme.danger : Theme.foreground)

    readonly property real secondsLeft: present ? (charging ? dev.timeToFull : dev.timeToEmpty) : 0

    readonly property string statusText: full ? "Fully charged" : (charging ? "Charging" : "Discharging")
    readonly property string timeText: {
        if (full || secondsLeft <= 0) return ""
        return fmt(secondsLeft) + (charging ? " to full" : " left")
    }

    function fmt(sec) {
        const m = Math.round(sec / 60)
        const h = Math.floor(m / 60)
        const mm = m % 60
        return h > 0 ? h + "h " + mm + "m" : mm + "m"
    }
}
