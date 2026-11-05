import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.widgets

// Classic: a horizontal pill that rises from the bottom edge, in the middle.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property bool mine: Style.current === "classic"
    readonly property bool on: mine && OsdState.shown

    anchors { bottom: true }
    margins { bottom: 10 }

    implicitWidth: 320
    implicitHeight: 64
    color: "transparent"
    visible: mine && (OsdState.shown || pill.opacity > 0)

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-osd"

    mask: Region {}

    Rectangle {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter
        y: win.on ? parent.height - height - 4 : parent.height + 4
        width: 280
        height: 44
        radius: height / 2
        color: Theme.island
        border.width: 1
        border.color: Theme.border
        opacity: win.on ? 1 : 0

        Behavior on y       { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }

        // The same slider as in the settings
        SliderBar {
            anchors.left: parent.left
            anchors.leftMargin: 11
            anchors.right: parent.right
            anchors.rightMargin: 58
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: 24
            height: 24
            enabled: false
            value: OsdState.value
            icon: OsdState.icon
            iconLevel: OsdState.iconLevel
            track: Theme.mix(Theme.island, Theme.foreground, 0.14)
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(OsdState.value * 100) + "%"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.bold: true
        }
    }
}
