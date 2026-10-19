import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// An archive on the dock's Shelf: a cardboard box with a lid, a strip of tape down the middle
// and a white label with the name (the buttons come up over the label when you point at it).
// Drawn by DockShelfCard.qml, which sets the size.
Item {
    id: root

    required property var item
    required property color tint
    required property bool lifted

    readonly property color kraft: "#E3BD8A"
    readonly property real lidH: 18

    // hard shadow
    Rectangle {
        x: 3
        y: 3
        width: parent.width
        height: parent.height
        radius: 5
        color: Theme.lineShadow
        antialiasing: true
    }

    Rectangle {
        id: body
        x: 3
        y: root.lidH - 4
        width: parent.width - 6
        height: parent.height - root.lidH + 4
        radius: 5
        color: root.kraft
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true

        // the tape, running down the middle
        Rectangle {
            x: (body.width - width) / 2
            y: 4
            width: 12
            height: body.height - 4 - Theme.borderWidth
            color: Qt.rgba(1, 1, 1, 0.55)
        }

        // the label
        Rectangle {
            id: label
            x: (body.width - width) / 2
            y: body.height - height - 8
            width: body.width - 14
            height: 20
            radius: 4
            color: "#FFFFFF"
            border.width: 1.5
            border.color: Theme.line
            antialiasing: true

            Text {
                anchors.fill: parent
                anchors.margins: 2
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                maximumLineCount: 1
                text: root.item.name
                color: "#2B2D42"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.Bold
                opacity: root.lifted ? 0 : 1

                Behavior on opacity {
                    NumberAnimation { duration: 100 }
                }
            }
        }

        MaterialIcon {
            x: (body.width - width) / 2
            y: 9
            name: "folder_zip"
            size: 20
            weight: 700
            color: Theme.line
        }
    }

    // the lid, a little wider than the box
    Rectangle {
        id: lid
        x: 0
        y: 0
        width: parent.width
        height: root.lidH
        radius: 5
        color: Qt.darker(root.kraft, 1.08)
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true

        Rectangle {
            x: 6
            y: 5
            width: lid.width - 12
            height: 2
            radius: 1
            color: "white"
            opacity: 0.45
        }

        Rectangle {
            x: (lid.width - width) / 2
            y: Theme.borderWidth
            width: 12
            height: lid.height - 2 * Theme.borderWidth
            color: Qt.rgba(1, 1, 1, 0.55)
        }
    }
}
