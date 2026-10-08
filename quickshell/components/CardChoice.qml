// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C A R D   C H O I C E                                                  │
// │   one of several on a card · a mark on the one chosen                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import QtQuick.Layouts

import "../theme"

// One option of a list on a card — an output, an input — in the height of a
// row. The chosen one is marked in the accent; a click on another is `picked`.
Item {
    id: root

    property string text: ""
    property bool chosen: false

    signal picked()

    Layout.fillWidth: true
    Layout.preferredHeight: Theme.cardRow

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -8
        anchors.rightMargin: -8
        radius: Theme.radiusSmall
        color: Theme.surfaceHoverIn(QsWindow.window)
        opacity: mouse.containsMouse && !root.chosen ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
    }

    Text {
        anchors.left: parent.left
        anchors.right: check.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: root.chosen ? Font.DemiBold : Font.Normal
        color: root.chosen ? Theme.text : Theme.textMuted
    }

    Text {
        id: check

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.chosen
        text: "󰄬"
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeRegular
        color: Theme.accent
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.chosen ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: {
            if (!root.chosen)
                root.picked()
        }
    }
}
