// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C A R O U S E L   T I L E                                              │
// │   carousel tile · position and scale from distance to centre             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

// A `Carousel` delegate: position, size and centred state come from the
// parent strip. Content is laid out once at rest size and scaled up when
// centred.
Item {
    id: root

    required property int index
    required property var modelData

    readonly property var strip: root.parent

    readonly property real distance: root.index - root.strip.position
    readonly property bool centred: root.index === root.strip.current
    readonly property bool hovered: mouse.containsMouse

    width: root.strip.tileWidth
    height: root.strip.tileHeight
    x: (root.strip.width - root.width) / 2 + root.strip.offsetOf(root.distance)
    y: (root.strip.height - root.height) / 2
    scale: root.strip.scaleOf(root.distance)
    visible: Math.abs(root.distance) < root.strip.reach
    // Tiles nearer the centre stack on top, so a sliding neighbour never
    // overlaps the centred tile.
    z: -Math.abs(root.distance)

    MouseArea {
        id: mouse

        anchors.fill: parent
        z: 1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.strip.press(root.index)
    }
}
