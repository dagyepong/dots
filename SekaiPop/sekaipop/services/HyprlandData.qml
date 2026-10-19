pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Window + monitor geometry straight from `hyprctl ... -j`, the same
// job illogical-impulse's own HyprlandData.qml does for its Overview
// (this is a trimmed port of it). Quickshell's Hyprland.toplevels
// already tells us *which* windows exist, but its cached copy of each
// one's position/size only refreshes on a few events; the Overview
// needs the real, current geometry to lay thumbnails out where the
// windows actually sit, so it asks hyprctl directly.
//
// Nothing is polled while the Overview is closed: Overview.qml flips
// `active` on open/close, and only while it's true do Hyprland's raw
// events (openwindow, movewindow, changefloatingmode, ...) trigger a
// refresh. Bursts of events are collapsed into one refresh by
// `debounce`, and a refresh that lands while one is still running is
// queued (`pending`) rather than dropped, so the last event always
// gets a fresh read.
//
//   import qs.services
//   HyprlandData.windowByAddress["0x55d0c0a1b2c0"]   // one client's JSON
//   HyprlandData.monitors                              // hyprctl monitors -j
Singleton {
    id: root

    property bool active: false

    property var windowList: []
    property var windowByAddress: ({})
    property var monitors: []

    onActiveChanged: {
        if (active)
            updateAll()
    }

    property bool pending: false

    function updateAll() {
        if (getClients.running || getMonitors.running) {
            root.pending = true
            return
        }
        getClients.running = true
        getMonitors.running = true
    }

    function afterFetch() {
        if (root.pending && !getClients.running && !getMonitors.running) {
            root.pending = false
            root.updateAll()
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (!root.active)
                return
            // Layer-shell and screencast events fire constantly (this
            // shell's own popups are layers) and never change a window.
            if (event.name === "openlayer" || event.name === "closelayer" || event.name === "screencast")
                return
            debounce.restart()
        }
    }

    Timer {
        id: debounce
        // Collapse bursts of Hyprland events a little more aggressively.
        // Window moves/resizes commonly emit several events in quick
        // succession; 80ms keeps the Overview responsive while avoiding
        // unnecessary duplicate `hyprctl clients/monitors -j` calls.
        interval: 80
        repeat: false
        onTriggered: root.updateAll()
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsOut
            onStreamFinished: {
                let list = []
                try {
                    list = JSON.parse(clientsOut.text)
                } catch (e) {
                    console.warn("[overview] couldn't parse hyprctl clients:", e)
                    return
                }
                const byAddress = {}
                for (const w of list)
                    byAddress[w.address] = w
                root.windowList = list
                root.windowByAddress = byAddress
            }
        }
        onExited: root.afterFetch()
    }

    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsOut
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(monitorsOut.text)
                } catch (e) {
                    console.warn("[overview] couldn't parse hyprctl monitors:", e)
                }
            }
        }
        onExited: root.afterFetch()
    }
}
