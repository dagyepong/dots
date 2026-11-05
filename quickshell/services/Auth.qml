pragma Singleton

import QtQuick
import Quickshell
import qs.services
import Quickshell.Services.Polkit

Singleton {
    id: root

    property string screen: ""          // monitor to show the prompt on

    readonly property var flow: agent.flow
    readonly property bool active: flow !== null && flow !== undefined && !flow.isCompleted

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: {
            root.screen = Compositor.focusedMonitor
        }
    }
}
