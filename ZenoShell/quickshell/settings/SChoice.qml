import QtQuick
import qs.theme

// Segmented buttons: pick one value
Rectangle {
    id: root

    property var model: []           // [{ id, label }]
    property string current: ""
    property color base: Theme.island      // color of the track (on a card of the same color, pass another one)
    signal picked(string id)

    implicitWidth: row.implicitWidth + 6
    implicitHeight: 30
    radius: 15
    color: root.base

    Row {
        id: row
        x: 3
        y: 3
        spacing: 2

        Repeater {
            model: root.model

            delegate: Rectangle {
                required property var modelData
                readonly property bool on: root.current === modelData.id

                width: label.implicitWidth + 24
                height: 24
                radius: 12
                color: on ? Theme.accent : (mouse.containsMouse ? Theme.islandHover : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData.label
                    color: parent.on ? Theme.island : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: parent.on
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(modelData.id)
                }
            }
        }
    }
}
