import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// A text (or a web link) on the dock's Shelf: a sticky note in one of the five card colours,
// leaning on the wall, with the first lines of the text on it and a folded corner. The buttons
// come up over the foot of the note when you point at it. Drawn by DockShelfCard.qml, which
// sets the size.
Item {
    id: root

    required property var item
    required property color tint
    required property bool lifted

    // hard shadow
    Rectangle {
        x: 3
        y: 3
        width: parent.width
        height: parent.height
        radius: 3
        color: Theme.lineShadow
        antialiasing: true
    }

    Rectangle {
        id: paper
        anchors.fill: parent
        radius: 3
        color: root.tint
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true

        // the glue strip along the top
        Rectangle {
            x: Theme.borderWidth + 2
            y: Theme.borderWidth + 1
            width: paper.width - 2 * (Theme.borderWidth + 2)
            height: 6
            radius: 2
            color: "white"
            opacity: 0.4
        }

        // the text: its first lines
        Text {
            x: 8
            y: 16
            width: paper.width - 16
            height: paper.height - 16 - 22
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: 4
            lineHeight: 0.95
            text: String(root.item.value).trim()
            color: "#2B2D42"
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.weight: Font.Bold
            opacity: root.lifted ? 0.35 : 1

            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }
        }

        // the folded corner
        Rectangle {
            x: paper.width - width - Theme.borderWidth
            y: paper.height - height - Theme.borderWidth
            width: 11
            height: 11
            radius: 2
            color: Qt.darker(root.tint, 1.18)
            border.width: 1.5
            border.color: Theme.line
            antialiasing: true
        }
    }
}
