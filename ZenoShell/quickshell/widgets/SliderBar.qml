import QtQuick
import qs.theme

Item {
    id: root

    property real value: 0
    property string icon: "volume"
    property int iconLevel: 2
    property color track: Theme.island
    readonly property bool pressed: area.pressed
    property bool showMore: false
    signal moved(real v)
    signal more()

    implicitHeight: 22

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.track
    }

    Rectangle {
        id: fill
        height: parent.height
        width: Math.max(height, parent.width * root.value)
        radius: height / 2
        color: Theme.accent

        Behavior on width {
            enabled: !area.pressed
            NumberAnimation { duration: 80 }
        }

        Glyph {
            x: 5
            anchors.verticalCenter: parent.verticalCenter
            kind: root.icon
            level: root.iconLevel
            size: 13
            color: Theme.island
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.moved(Math.max(0, Math.min(1, mouse.x / width)))
        onPositionChanged: mouse => {
            if (pressed) root.moved(Math.max(0, Math.min(1, mouse.x / width)))
        }
    }

    // Opens the detail page of this control
    Rectangle {
        visible: root.showMore
        anchors.right: parent.right
        anchors.rightMargin: 3
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height - 6
        height: width
        radius: width / 2
        color: moreArea.containsMouse ? Theme.mix(Theme.island, Theme.foreground, 0.28) : Theme.mix(Theme.island, Theme.foreground, 0.14)

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            text: "›"
            color: Theme.foreground
            font.pixelSize: 15
            font.bold: true
        }

        MouseArea {
            id: moreArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.more()
        }
    }
}
