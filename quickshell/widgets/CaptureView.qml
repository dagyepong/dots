import QtQuick
import qs.theme
import qs.services

Item {
    id: root

    property int sel: 0

    readonly property var actions: [
        { id: "shot-area",   label: "Area",   icon: "area" },
        { id: "shot-window", label: "Window", icon: "window" },
        { id: "shot-screen", label: "Screen", icon: "screen" },
        { id: "rec-area",    label: "Area",   icon: "record" },
        { id: "rec-screen",  label: "Screen", icon: "record" }
    ]

    function reset() {
        sel = 0
        keys.forceActiveFocus()
    }

    function activate(i) {
        Capture.run(actions[i].id)
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Right) {
                root.sel = (root.sel + 1) % root.actions.length
                event.accepted = true
            } else if (event.key === Qt.Key_Left) {
                root.sel = (root.sel + root.actions.length - 1) % root.actions.length
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.activate(root.sel)
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                Capture.close()
                event.accepted = true
            }
        }
    }

    Text {
        x: 24; y: 20
        text: "Capture"
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 15
        font.bold: true
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 24
        y: 24
        text: "← →  ·  Enter  ·  Esc"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }

    Text {
        x: 18
        y: 50
        width: 3 * 78 + 2 * 11
        horizontalAlignment: Text.AlignHCenter
        text: "SCREENSHOT"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 9
        font.bold: true
    }

    Text {
        x: 18 + 3 * 89
        y: 50
        width: 2 * 78 + 11
        horizontalAlignment: Text.AlignHCenter
        text: "VIDEO"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 9
        font.bold: true
    }

    Row {
        x: (root.width - width) / 2
        y: 68
        spacing: 11

        Repeater {
            model: root.actions

            delegate: Rectangle {
                id: tile

                required property var modelData
                required property int index

                readonly property bool selected: root.sel === index
                readonly property bool isRec: modelData.id.indexOf("rec-") === 0

                width: 78
                height: 86
                radius: 22
                color: selected ? Theme.islandHover : Theme.surfaceSoft
                border.width: selected ? 1.5 : 0
                border.color: isRec ? Theme.danger : Theme.accent
                Behavior on color { ColorAnimation { duration: 120 } }

                Rectangle {
                    x: (parent.width - width) / 2
                    y: 12
                    width: 38; height: 38
                    radius: 19
                    color: tile.selected ? (tile.isRec ? Theme.danger : Theme.accent) : Theme.border
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Glyph {
                        anchors.centerIn: parent
                        kind: tile.modelData.icon
                        size: 18
                        color: tile.selected ? Theme.island : (tile.isRec ? Theme.danger : Theme.foreground)
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 60
                    text: tile.modelData.label
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: root.sel = tile.index
                    onClicked: root.activate(tile.index)
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 168
        text: "Screenshots go to the clipboard and ~/Screenshots · Videos to ~/Videos/Recordings"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 9
    }
}
