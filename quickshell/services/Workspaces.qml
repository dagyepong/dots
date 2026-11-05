pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    property bool shown: false
    property bool pinned: false        // pinned until you close it
    property bool paused: false        // mouse over: stays open
    property bool armed: false         // no flash in the first seconds after startup
    property string screen: ""         // monitor to show it on
    property int previousId: 1
    property int currentId: 1
    property int flashSerial: 0        // changes on every appearance: the view restarts from the old workspace

    // Existing workspaces on the given monitor (Hyprland or niri, Compositor handles it)
    function idsFor(screenName) {
        return Compositor.workspaceIdsFor(screenName)
    }

    function flash(ms) {
        screen = Compositor.focusedMonitor
        shown = true
        flashSerial++
        if (pinned || paused) return
        hideTimer.interval = ms
        hideTimer.restart()
    }

    function togglePin() {
        pinned = !pinned
        if (pinned) {
            screen = Compositor.focusedMonitor
            shown = true
            flashSerial++
            hideTimer.stop()
        } else {
            hideTimer.interval = 700
            hideTimer.restart()
        }
    }

    onPausedChanged: {
        if (paused) {
            hideTimer.stop()
        } else if (shown && !pinned) {
            hideTimer.interval = 900
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        onTriggered: root.shown = false
    }

    Timer {
        interval: 2500
        running: true
        onTriggered: root.armed = true
    }

    Connections {
        target: Compositor

        function onFocusedWorkspaceIdChanged() {
            const id = Compositor.focusedWorkspaceId
            if (id <= 0) return
            root.previousId = root.currentId
            root.currentId = id
            if (root.armed && root.previousId !== root.currentId) root.flash(1600)
        }
    }

    Component.onCompleted: {
        const id = Compositor.focusedWorkspaceId
        if (id > 0) {
            currentId = id
            previousId = id
        }
    }
}
