import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// A picture on the dock's Shelf: a polaroid leaning on the wall, the picture itself in the
// window and the name written on the white strip under it (the strip gives way to the buttons
// when you point at it). Drawn by DockShelfCard.qml, which sets the size.
Item {
    id: root

    required property var item
    required property color tint
    required property bool lifted

    readonly property real margin: 6
    readonly property real stripH: 26

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

    // the card (always white, like the paper)
    Rectangle {
        id: card
        anchors.fill: parent
        radius: 4
        color: "#FFFFFF"
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true

        // the window: a dark inset with the picture in it
        Rectangle {
            id: window
            x: root.margin
            y: root.margin
            width: card.width - 2 * root.margin
            height: card.height - root.margin - root.stripH
            color: Qt.darker(root.tint, 1.4)
            border.width: 2
            border.color: Theme.line
            antialiasing: true

            Image {
                id: pic
                anchors.fill: parent
                anchors.margins: 2
                asynchronous: true
                smooth: true
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(160, 160)
                source: root.item.kind === "file" ? "file://" + root.item.value : ""
                visible: status === Image.Ready
            }

            // while it loads (or when it can't be read): a plain tinted window
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                visible: !pic.visible
                color: root.tint
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: !pic.visible
                name: "image"
                size: 20
                weight: 700
                color: Theme.line
            }
        }

        // the name, written on the strip
        Text {
            x: root.margin
            y: card.height - root.stripH
            width: card.width - 2 * root.margin
            height: root.stripH - 4
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

    // a bit of tape holding it to the wall
    Rectangle {
        x: (parent.width - width) / 2
        y: -5
        width: 26
        height: 11
        radius: 2
        rotation: 5
        color: ScrapbookTheme.tapeMint
        opacity: 0.85
        antialiasing: true
    }
}
