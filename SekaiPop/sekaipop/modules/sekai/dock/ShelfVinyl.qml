import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// A sound on the dock's Shelf: a record in its sleeve, the black disc showing over the top of
// the sleeve. The sleeve is in the item's colour with a big circle and a music note, and the
// name along the foot (the buttons come up there when you point at it).
// Drawn by DockShelfCard.qml, which sets the size.
Item {
    id: root

    required property var item
    required property color tint
    required property bool lifted

    readonly property real sleeveTop: 16
    readonly property real disc: Math.min(width - 10, 52)

    // the disc, behind the sleeve
    Rectangle {
        x: (parent.width - width) / 2
        y: 0
        width: root.disc
        height: root.disc
        radius: width / 2
        color: "#2B2D42"
        border.width: 2
        border.color: Theme.line
        antialiasing: true

        // grooves
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 14
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.22)
            antialiasing: true
        }

        // the label in the middle
        Rectangle {
            anchors.centerIn: parent
            width: 16
            height: 16
            radius: 8
            color: root.tint
            antialiasing: true
        }
    }

    // hard shadow of the sleeve
    Rectangle {
        x: 3
        y: root.sleeveTop + 3
        width: parent.width
        height: parent.height - root.sleeveTop
        radius: 5
        color: Theme.lineShadow
        antialiasing: true
    }

    Rectangle {
        id: sleeve
        y: root.sleeveTop
        width: parent.width
        height: parent.height - root.sleeveTop
        radius: 5
        color: root.tint
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true

        // a big circle, like the cover art
        Rectangle {
            x: (sleeve.width - width) / 2
            y: 9
            width: 28
            height: 28
            radius: 14
            color: "transparent"
            border.width: 2.5
            border.color: Qt.rgba(1, 1, 1, 0.75)
            antialiasing: true

            MaterialIcon {
                anchors.centerIn: parent
                name: "music_note"
                size: 16
                weight: 700
                color: "white"
            }
        }

        Text {
            x: 5
            y: sleeve.height - height - 7
            width: sleeve.width - 10
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            maximumLineCount: 1
            text: root.item.name
            color: Theme.line
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.weight: Font.ExtraBold
            opacity: root.lifted ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }
        }
    }
}
