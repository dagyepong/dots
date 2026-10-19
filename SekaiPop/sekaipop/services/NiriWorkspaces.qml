pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/common/functions/NiriMath.js" as NM

// Workspaces when the shell runs on niri instead of Hyprland. Bar.qml reads
// this in place of Quickshell.Hyprland while `running` is true; on Hyprland
// nothing here connects.
//
// niri keeps its own workspaces per output, numbered 1.. from the top (`idx`).
// Two connections to niri's socket (NIRI_SOCKET), no child processes:
//
//   events    asks for "EventStream" once; niri answers {"Ok":"Handled"},
//             then sends the full list and one change per line
//             (NiriMath.applyEvent)
//   requests  FocusWorkspace actions for badge clicks, by niri's global id,
//             so a click lands on its own monitor whichever one is focused
//
// A dropped connection clears the list and tries again every second.
Singleton {
    id: root

    // set by niri for every program it starts
    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""
    readonly property bool running: root.socketPath !== ""

    // niri's own workspace objects, see NiriMath.js; empty until the stream sends them
    property var workspaces: []

    // the workspace id a click asked for, null when nothing waits for the request socket
    property var pendingWorkspaceId: null

    function activeOn(output) {
        return NM.activeOn(root.workspaces, output)
    }

    function occupiedOn(output) {
        return NM.occupiedOn(root.workspaces, output)
    }

    // badge `idx` on `output`, the number the bar shows
    function focus(output, idx) {
        const id = NM.idOf(root.workspaces, output, idx)

        if (id === null) {
            console.warn("NiriWorkspaces: no workspaces known on " + output + " yet")
            return
        }

        root.pendingWorkspaceId = id

        // the request goes out once the socket is up (onConnectedChanged)
        if (!requests.connected) {
            requests.connected = true
            return
        }

        root.sendPending()
    }

    function sendPending() {
        if (!requests.connected || root.pendingWorkspaceId === null)
            return

        const action = { Action: { FocusWorkspace: { reference: { Id: root.pendingWorkspaceId } } } }

        root.pendingWorkspaceId = null

        requests.write(JSON.stringify(action) + "\n")
        requests.flush()
    }

    function handleEvent(line) {
        const message = NM.parse(line)

        if (message === null)
            return

        if (events.awaitingAck) {
            events.awaitingAck = false

            if (message.Ok !== "Handled") {
                console.warn("NiriWorkspaces: niri refused the event stream: " + line)
                events.connected = false
            }

            return
        }

        const next = NM.applyEvent(root.workspaces, message)

        if (next === null)
            return

        root.workspaces = next
    }

    Component.onCompleted: {
        if (!root.running)
            return

        events.connected = true
        requests.connected = true
    }

    Socket {
        id: events

        // true between asking for the stream and niri's first reply
        property bool awaitingAck: false

        path: root.socketPath

        onConnectedChanged: {
            if (connected) {
                eventsRetry.stop()

                awaitingAck = true
                write("\"EventStream\"\n")
                flush()
                return
            }

            // the socket dropped: the old list is not true any more
            root.workspaces = []
            eventsRetry.restart()
        }

        onError: error => {
            console.warn("NiriWorkspaces: event socket error: " + error)
            connected = false

            // a failed connect never was connected, so onConnectedChanged does not retry it
            eventsRetry.restart()
        }

        parser: SplitParser {
            onRead: data => root.handleEvent(data)
        }
    }

    Socket {
        id: requests

        path: root.socketPath

        onConnectedChanged: {
            if (connected) {
                requestsRetry.stop()
                root.sendPending()
                return
            }

            requestsRetry.restart()
        }

        onError: error => {
            console.warn("NiriWorkspaces: request socket error: " + error)
            connected = false

            requestsRetry.restart()
        }

        parser: SplitParser {
            onRead: data => {
                const reply = NM.parse(data)

                if (reply !== null && reply.Err)
                    console.warn("NiriWorkspaces: niri refused a workspace switch: " + reply.Err)
            }
        }
    }

    // the socket path holds niri's pid, so these only retry a dropped connection to
    // the same niri; a restarted niri ends the shell's wayland session anyway
    Timer {
        id: eventsRetry
        interval: 1000
        onTriggered: events.connected = true
    }

    Timer {
        id: requestsRetry
        interval: 1000
        onTriggered: requests.connected = true
    }
}
