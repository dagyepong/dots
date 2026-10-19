import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// A folder on the dock's Shelf: a file folder standing up, with its tab, a front flap and the
// name running up the front. Drawn by DockShelfCard.qml, which sets the size.
Item {
    id: root

    required property var item
    required property color tint
    required property bool lifted

    readonly property real tabH: 10

    // hard shadow
    Rectangle {
        x: 3
        y: 3 + root.tabH
        width: parent.width
        height: parent.height - root.tabH
        radius: 6
        color: Theme.lineShadow
        antialiasing: true
    }

    // the back panel with its tab
    Rectangle {
        x: 3
        y: 0
        width: 20
        height: root.tabH + 8
        radius: 5
        color: Qt.darker(root.tint, 1.12)
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true
    }

    Rectangle {
        id: back
        y: root.tabH
        width: parent.width
        height: parent.height - root.tabH
        radius: 6
        color: Qt.darker(root.tint, 1.12)
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true
    }

    // the front flap, a little shorter, so the back's edge shows over the top
    Rectangle {
        id: front
        x: 0
        y: root.tabH + 7
        width: parent.width
        height: parent.height - root.tabH - 7
        radius: 6
        color: root.tint
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true

        // lit edge
        Rectangle {
            x: 4
            y: 6
            width: 2
            height: Math.max(0, front.height - 20)
            radius: 1
            color: "white"
            opacity: 0.4
        }

        // a small label with the folder glyph
        Item {
            x: (front.width - width) / 2
            y: 8
            width: 24
            height: 24
            opacity: root.lifted ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }

            Rectangle {
                anchors.fill: parent
                radius: 7
                color: Theme.surface
                border.width: 2
                border.color: Theme.line
                antialiasing: true
            }

            MaterialIcon {
                anchors.centerIn: parent
                name: "folder"
                size: 16
                weight: 700
            }
        }

        // the name, up the front
        Item {
            id: titleBox
            x: (front.width - width) / 2
            y: 38
            width: 14
            height: Math.max(0, front.height - 38 - 10)
            opacity: root.lifted ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }

            Text {
                y: titleBox.height
                width: titleBox.height
                height: titleBox.width
                rotation: -90
                transformOrigin: Item.TopLeft
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                text: root.item.name
                color: Theme.line
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.ExtraBold
            }
        }
    }
}
