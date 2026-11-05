import QtQuick
import qs.theme
import qs.services

// Live audio bars (cava). Shows the progress dots if cava is not installed.
Item {
    id: root

    property bool counted: false
    property color tone: Theme.foreground

    implicitWidth: row.implicitWidth
    implicitHeight: 30

    onVisibleChanged: {
        if (visible && !counted) { Cava.users++; counted = true }
        else if (!visible && counted) { Cava.users--; counted = false }
    }
    Component.onDestruction: if (counted) Cava.users--

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 3
        visible: Cava.available

        Repeater {
            model: Cava.count

            delegate: Rectangle {
                required property int index

                anchors.verticalCenter: parent.verticalCenter
                width: 4
                height: Math.max(4, root.height * (Cava.levels[index] || 0))
                radius: 2
                color: root.tone
                opacity: 0.55 + 0.45 * (Cava.levels[index] || 0)
                Behavior on height { NumberAnimation { duration: 60 } }
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 4
        visible: !Cava.available

        Repeater {
            model: 10

            delegate: Rectangle {
                required property int index

                anchors.verticalCenter: parent.verticalCenter
                width: 4; height: 4
                radius: 2
                color: root.tone
                opacity: index < Math.round(Media.progress * 10) ? 0.9 : 0.25
            }
        }
    }
}
