// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D E T A I L   C H O I C E                                              │
// │   one of a list to choose from on a control-centre page                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import Quickshell
import "../../theme"

// A row with a name, lit and checked when it is the one in use; its name lines
// up with a `LevelRow`'s, past where the mark would be.
Rectangle {
    id: root

    property string text: ""
    property bool chosen: false

    signal picked()

    width: parent ? parent.width : 0
    height: Theme.detailRow
    radius: Theme.radiusSmall
    color: root.chosen || pick.containsMouse ? Theme.surfaceHoverIn(QsWindow.window) : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

    Text {
        x: 30
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 64
        elide: Text.ElideRight
        text: root.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeRegular - 1
        color: Theme.text
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: root.chosen
        text: "󰄬"
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeRegular
        color: Theme.accent
    }

    MouseArea {
        id: pick

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked()
    }
}
