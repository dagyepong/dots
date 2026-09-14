// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P R E V I E W   T I L E                                                │
// │   settings option shown as a preview                                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"

// An option shown as a live miniature of the real component (a bar, a chip,
// the clock in the offered format) above its caption. Built from the same
// components, so it follows the palette and cannot go stale the way a
// screenshot would.
Rectangle {
    id: root

    property bool selected: false
    property string caption: ""
    // Fixed stage height so tiles in a row line up.
    property int stageHeight: 62

    default property alias stage: stage.data

    signal picked()

    // For previews that react to hover.
    readonly property alias hovered: mouse.containsMouse

    implicitWidth: 128
    implicitHeight: root.stageHeight + 34
    // Share a row's width evenly.
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    radius: Theme.radiusMedium
    color: root.selected ? Theme.islandSurfaceHover
        : (mouse.containsMouse ? Theme.islandSurface : "transparent")
    border.color: root.selected ? Theme.accent
        : (mouse.containsMouse ? Theme.islandBorder : Theme.islandSurfaceHover)
    border.width: 1

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

    Item {
        id: stage

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 1
        height: root.stageHeight
        clip: true
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 9
        text: root.caption
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
        font.weight: root.selected ? Font.DemiBold : Font.Normal
        color: root.selected ? Theme.accent : Theme.textMuted
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked()
    }
}
