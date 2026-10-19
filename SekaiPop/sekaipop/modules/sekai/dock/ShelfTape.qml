import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// A video on the dock's Shelf: a video tape standing spine out. A dark case, a coloured band at
// each end, "VHS" at the top and a white label with the name running up it. Drawn by
// DockShelfCard.qml, which sets the size.
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
        radius: 4
        color: Theme.lineShadow
        antialiasing: true
    }

    Rectangle {
        id: shell
        anchors.fill: parent
        radius: 4
        color: "#3A3D5C"
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true

        // a coloured band at each end
        Repeater {
            model: [Theme.borderWidth + 2, shell.height - Theme.borderWidth - 8]

            Rectangle {
                required property real modelData

                x: Theme.borderWidth + 2
                y: modelData
                width: shell.width - 2 * (Theme.borderWidth + 2)
                height: 6
                radius: 2
                color: root.tint
            }
        }

        // lit edge
        Rectangle {
            x: 3
            y: 16
            width: 2
            height: Math.max(0, shell.height - 32)
            radius: 1
            color: "white"
            opacity: 0.25
        }

        Text {
            x: (shell.width - width) / 2
            y: 15
            text: "VHS"
            color: "white"
            opacity: root.lifted ? 0 : 0.85
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.weight: Font.ExtraBold

            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }
        }

        // the white label, with the name up it
        Rectangle {
            id: label
            x: (shell.width - width) / 2
            y: 30
            width: 14
            height: Math.max(0, shell.height - 30 - 18)
            radius: 3
            color: "#FFFFFF"
            border.width: 1.5
            border.color: Theme.line
            antialiasing: true
            opacity: root.lifted ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }

            Text {
                y: label.height
                width: label.height
                height: label.width
                rotation: -90
                transformOrigin: Item.TopLeft
                verticalAlignment: Text.AlignVCenter
                leftPadding: 4
                rightPadding: 4
                elide: Text.ElideRight
                maximumLineCount: 1
                text: root.item.name
                color: "#2B2D42"
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.weight: Font.ExtraBold
            }
        }
    }
}
