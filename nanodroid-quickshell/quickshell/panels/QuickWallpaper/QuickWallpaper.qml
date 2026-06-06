import "../../core"
import "../../services"
import "../../widgets"
import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    id: root
    model: Quickshell.screens

    Loader {
        required property var modelData
        active: GlobalStates.quickWallpaperOpen

        sourceComponent: PanelWindow {
            id: panelWindow
            screen: modelData
            exclusiveZone: 0
            WlrLayershell.namespace: "nandoroid:quickwallpaper"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.20)
                opacity: content.openProgress
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.quickWallpaperOpen = false
            }

            QuickWallpaperContent {
                id: content
                anchors.centerIn: parent
                screenWidth: panelWindow.width
                screenHeight: panelWindow.height
                onClosed: GlobalStates.quickWallpaperOpen = false
            }
        }
    }
}
