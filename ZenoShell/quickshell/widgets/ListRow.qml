import QtQuick
import qs.theme

Rectangle {
    id: root

    property string icon: "wifi"
    property int iconLevel: 3
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property bool active: false
    property bool locked: false
    property real extraHeight: 0

    // Children declared inside the row go in the area below (e.g. password field)
    default property alias extra: extraItem.data
    signal clicked()

    implicitHeight: 46 + extraHeight
    radius: 16
    color: mouse.containsMouse ? Theme.islandHover : Theme.surfaceSoft
    clip: true

    Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 100 } }

    Rectangle {
        x: 6; y: 6
        width: 34; height: 34
        radius: 17
        color: root.active ? Theme.accent : Theme.border

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
        y: 23 - height / 2
        width: parent.width - 48 - 90
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

    Text {
        anchors.right: parent.right
        anchors.rightMargin: root.locked ? 32 : 14
        y: 23 - height / 2
        text: root.trailing
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }

    Glyph {
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 23 - height / 2
        kind: "lock"
        size: 12
        color: Theme.muted
        visible: root.locked
    }

    MouseArea {
        id: mouse
        width: parent.width
        height: 46
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Item {
        id: extraItem
        y: 46
        width: parent.width
        height: root.extraHeight
    }
}
