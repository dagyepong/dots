import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

// "Identify": for a few seconds each screen shows its name in large text
Scope {
    Variants {
        model: Displays.identifying ? Quickshell.screens : []

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "shell-identify"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                anchors.centerIn: parent
                width: label.implicitWidth + 80
                height: label.implicitHeight + 50
                radius: 30
                color: Theme.island
                border.width: 2
                border.color: Theme.accent

                Column {
                    id: label
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.modelData.name
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 56
                        font.bold: true
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.modelData.width + "×" + win.modelData.height
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                    }
                }
            }
        }
    }
}
