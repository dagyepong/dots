// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N   E   T   W   O   R   K       F   A   C   E                          │
// │   the signal as arcs · a plug on a cable                                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

Instrument {
    id: face

    line: NetworkService.connectionName
    reading: NetworkService.connectionName
    note: NetworkService.stateLine

    Arcs {
        anchors.centerIn: parent
        ink: face.ink
        size: Math.min(parent.width, parent.height)
        strength: NetworkService.strength
        connected: NetworkService.wifiConnected
        wired: NetworkService.wiredConnected
    }
}
