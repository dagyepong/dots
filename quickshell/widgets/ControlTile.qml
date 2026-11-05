import QtQuick
import qs.theme

Rectangle {
    id: root

    property string icon: "wifi"
    property int iconLevel: 3
    property string title: ""
    property string subtitle: ""
    property bool active: false
    signal clicked()

    implicitWidth: 135
    implicitHeight: 46
    radius: height / 2
    color: mouse.containsMouse ? Theme.islandHover : Theme.surfaceSoft
    Behavior on color { ColorAnimation { duration: 100 } }

    Rectangle {
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 34
        radius: 17
        color: root.active ? Theme.accent : Theme.border
        Behavior on color { ColorAnimation { duration: 140 } }

        Glyph {
            anchors.centerIn: parent
            kind: root.icon
            level: root.iconLevel
            size: 16
            color: root.active ? Theme.island : Theme.foreground
        }
    }

    Column {
        x: 48
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 48 - 10
        spacing: 1

        Text {
            width: parent.width
            text: root.title
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.subtitle
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
