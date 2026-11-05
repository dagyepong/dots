import QtQuick
import qs.theme

Item {
    id: root

    property real value: 0
    property real maxValue: 1.2
    property string icon: "volume"
    property int iconLevel: 2
    readonly property bool pressed: area.pressed
    signal moved(real v)

    implicitHeight: 22

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.island
    }

    Rectangle {
        id: fill

        height: parent.height
        width: Math.max(height, parent.width * Math.min(root.value, root.maxValue) / root.maxValue)
        radius: height / 2
        color: root.value > 1.0005 ? Theme.danger : Theme.accent

        Behavior on width {
            enabled: !area.pressed
            NumberAnimation { duration: 80 }
        }
        Behavior on color { ColorAnimation { duration: 120 } }

        Glyph {
            x: 5
            anchors.verticalCenter: parent.verticalCenter
            kind: root.icon
            level: root.iconLevel
            size: 13
            color: Theme.island
        }
    }

    // 100% tick
    Rectangle {
        x: root.width / root.maxValue - 1
        y: 4
        width: 2
        height: parent.height - 8
        radius: 1
        color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.35)
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        function valueAt(x) {
            let v = Math.max(0, Math.min(1, x / width)) * root.maxValue
            if (Math.abs(v - 1.0) < 0.035) v = 1.0      // si "aggancia" al 100%
            return v
        }

        onPressed: mouse => root.moved(valueAt(mouse.x))
        onPositionChanged: mouse => { if (pressed) root.moved(valueAt(mouse.x)) }
    }
}
