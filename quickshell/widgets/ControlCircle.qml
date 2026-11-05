import QtQuick
import qs.theme

Rectangle {
    id: root

    property string icon: "lock"
    property bool active: false
    signal clicked()

    implicitWidth: 46
    implicitHeight: 46
    radius: width / 2
    color: active ? Theme.accent : (mouse.containsMouse ? Theme.islandHover : Theme.surfaceSoft)
    Behavior on color { ColorAnimation { duration: 140 } }

    Glyph {
        anchors.centerIn: parent
        kind: root.icon
        size: 17
        color: root.active ? Theme.island : Theme.foreground
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
