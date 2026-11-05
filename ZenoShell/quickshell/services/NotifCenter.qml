pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.services

Singleton {
    id: root

    property bool dnd: false          // Do Not Disturb: no toasts, notifications stay in the list
    property double dndUntil: 0       // expected end (ms), 0 = until you turn it off
    property int dndMinutes: 0        // chosen duration (0 = no end)
    property int suppressed: 0        // notifications received while it was active
    property int tick: 0
    property bool unread: false

    readonly property string dndText: {
        tick
        if (!dnd) return "Off"
        if (dndUntil === 0) return "On"
        const m = Math.max(1, Math.ceil((dndUntil - Date.now()) / 60000))
        const t = m >= 60 ? Math.floor(m / 60) + " h" + (m % 60 ? " " + (m % 60) + " min" : "") : m + " min"
        return "On · " + t + " left"
    }

    function setDnd(on, minutes) {
        const was = dnd
        dnd = on
        dndMinutes = on ? (minutes || 0) : 0
        dndUntil = (on && minutes > 0) ? Date.now() + minutes * 60000 : 0
        tick++
        if (on) {
            if (!was) suppressed = 0
            dndTimer.restart()
        } else {
            dndTimer.stop()
            if (was && suppressed > 0) {
                Toast.push({
                    kind: "notification",
                    app: "Notifications",
                    summary: suppressed === 1 ? "1 notification while you were away"
                                              : suppressed + " notifications while you were away",
                    body: "They are in the control center",
                    tone: "accent",
                    duration: 5000
                })
            }
            suppressed = 0
        }
    }

    function toggleDnd() { setDnd(!dnd, 0) }

    Timer {
        id: dndTimer
        interval: 15000
        repeat: true
        onTriggered: {
            root.tick++
            if (root.dnd && root.dndUntil > 0 && Date.now() >= root.dndUntil) root.setDnd(false, 0)
        }
    }

    readonly property var list: server.trackedNotifications
    readonly property int count: server.trackedNotifications.values.length

    function clearAll() {
        const vals = server.trackedNotifications.values
        const arr = []
        for (let i = 0; i < vals.length; i++) arr.push(vals[i])
        for (let i = 0; i < arr.length; i++) arr[i].dismiss()
        unread = false
    }

    NotificationServer {
        id: server

        keepOnReload: true
        bodySupported: true
        actionsSupported: false
        imageSupported: false

        onNotification: notification => {
            notification.tracked = true

            const critical = notification.urgency === NotificationUrgency.Critical
            if (root.dnd && !critical) {          // Do Not Disturb: no toast and no dot
                root.suppressed++
                return
            }

            root.unread = true
            Toast.push({
                kind: "notification",
                app: notification.appName || "?",
                summary: notification.summary,
                body: notification.body,
                tone: critical ? "danger" : "accent",
                duration: notification.expireTimeout > 0 ? notification.expireTimeout * 1000
                                                         : (critical ? 10000 : 5000)
            })
        }
    }
}
