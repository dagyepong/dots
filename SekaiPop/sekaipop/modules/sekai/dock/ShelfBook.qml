import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// A document (or any file with no look of its own) on the dock's Shelf: a book standing on
// the plank. A spine in one of the five card colours, three white bands, a small label with the
// file's icon and the name running up the spine. Drawn by DockShelfCard.qml, which sets the size.
Item {
    id: root

    required property var item
    required property string icon
    required property color tint
    required property bool lifted

    // hard shadow, like every sticker
    Rectangle {
        x: 3
        y: 3
        width: parent.width
        height: parent.height
        radius: 6
        color: Theme.lineShadow
        antialiasing: true
    }

    Rectangle {
        id: spineBody
        anchors.fill: parent
        radius: 6
        color: root.tint
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true

        // two bands near the top and one near the foot, like a real spine
        Repeater {
            model: [8, 14, spineBody.height - 15]

            Rectangle {
                required property real modelData

                x: 3
                y: modelData
                width: spineBody.width - 6
                height: 3
                radius: 1.5
                color: "white"
                opacity: 0.6
            }
        }

        // lit edge on the left
        Rectangle {
            x: 3
            y: 22
            width: 2
            height: Math.max(0, spineBody.height - 40)
            radius: 1
            color: "white"
            opacity: 0.35
        }

        // what it is: an icon on a small label
        Item {
            x: (spineBody.width - width) / 2
            y: 22
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
                name: root.icon
                size: 16
                weight: 700
            }
        }

        // the name, running up the spine
        Item {
            id: titleBox
            x: (spineBody.width - width) / 2
            y: 54
            width: 14
            height: Math.max(0, spineBody.height - 54 - 22)
            opacity: root.lifted ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }

            Text {
                x: 0
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
