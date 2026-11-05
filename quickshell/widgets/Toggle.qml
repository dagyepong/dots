import QtQuick
import qs.theme

Rectangle {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 40
    implicitHeight: 22
    radius: 11
    color: checked ? Theme.accent : Theme.border
    Behavior on color { ColorAnimation { duration: 140 } }

    Rectangle {
        y: 3
        x: root.checked ? parent.width - width - 3 : 3
        width: 16
        height: 16
        radius: 8
        color: root.checked ? Theme.island : Theme.foreground
        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
