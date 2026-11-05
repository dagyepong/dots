import QtQuick
import qs.theme

Rectangle {
    id: root

    property string label: ""
    signal clicked()

    implicitWidth: 28
    implicitHeight: 28
    radius: width / 2
    color: mouse.containsMouse ? Theme.islandHover : Theme.surfaceSoft
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: root.label
        color: Theme.foreground
        font.pixelSize: 18
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
