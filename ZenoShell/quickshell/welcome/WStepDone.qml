import QtQuick
import qs.theme
import qs.services
import qs.widgets
import qs.settings

// Last step
Item {
    id: root

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 80
        width: 96; height: 96; radius: 48
        color: Theme.accent

        Text {
            anchors.centerIn: parent
            text: "✓"
            color: Theme.island
            font.pixelSize: 54
            font.bold: true
        }

        SequentialAnimation on scale {
            running: Welcome.last
            loops: 1
            NumberAnimation { from: 0.6; to: 1.12; duration: 320; easing.type: Easing.OutCubic }
            NumberAnimation { to: 1.0; duration: 220; easing.type: Easing.OutBack }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 200
        text: "You are all set"
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 38
        font.bold: true
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 254
        width: Math.min(620, parent.width - 120)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: "Open the launcher with Alt+R, Settings with Alt+O. If you want to see this tour again: Settings, then About, then “Review the tour”."
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 15
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 350
        spacing: 12

        SButton {

            base: Theme.surfaceSoft
            label: "Open Settings"
            onClicked: { Welcome.finish(); Settings.show("appearance") }
        }
    }
}
