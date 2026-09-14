// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C A R D                                                                │
// │   the surface every control centre section sits on                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"

// The rounded surface every control centre section uses. `bare` drops the
// surface and keeps the contents, for module details shown directly on the
// island.
Rectangle {
    id: root

    default property alias content: inner.data
    property int padding: 14
    property bool bare: false

    radius: Theme.radiusMedium
    color: root.bare ? "transparent" : Theme.islandSurface
    border.color: Theme.islandBorder
    border.width: root.bare ? 0 : 1

    Behavior on color { ColorAnimation { duration: Theme.paletteTransition } }

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: root.padding
    }
}
