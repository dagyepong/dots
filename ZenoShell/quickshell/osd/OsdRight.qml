import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.widgets

// Island: the tall pill on the right edge. Dashboard (pill version): the same place, but drawn like the sliders
// of the settings, upright.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property bool island: Style.current === "island"
    readonly property bool dashPill: Style.current === "dash" && !Style.dashAttached
    readonly property bool mine: island || dashPill
    readonly property bool on: mine && OsdState.shown

    anchors { right: true }
    margins { right: 10 }

    implicitWidth: 64
    implicitHeight: 230
    color: "transparent"
    visible: mine && (OsdState.shown || pill.opacity > 0)

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-osd"

    // Clicks pass through: the OSD is informational only
    mask: Region {}

    Item {
        id: pill

        anchors.verticalCenter: parent.verticalCenter
        x: win.on ? parent.width - width - 4 : parent.width + 4
        width: win.dashPill ? 40 : 46
        height: win.dashPill ? 190 : 210
        opacity: win.on ? 1 : 0

        Behavior on x       { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }

        // ---- Island: as before ----
        Rectangle {
            anchors.fill: parent
            visible: win.island
            radius: 23
            color: Theme.island
            border.width: 1
            border.color: Theme.border

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 14
                text: Math.round(OsdState.value * 100) + "%"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.bold: true
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 40
                width: 8
                height: parent.height - 40 - 48
                radius: 4
                color: Theme.border

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(width, parent.height * OsdState.value)
                    radius: 4
                    color: Theme.accent
                    Behavior on height { NumberAnimation { duration: 80 } }
                }
            }

            Glyph {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - 14 - height
                kind: OsdState.icon
                level: OsdState.iconLevel
                size: 18
                color: Theme.foreground
            }
        }

        // ---- Dashboard (pill): the settings slider, upright ----
        Rectangle {
            anchors.fill: parent
            visible: win.dashPill
            radius: width / 2
            color: Theme.island
            border.width: 1
            border.color: Theme.border

            Rectangle {
                id: fill
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.max(width, parent.height * OsdState.value)
                radius: width / 2
                color: Theme.accent
                Behavior on height { NumberAnimation { duration: 80 } }

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - parent.width / 2 - height / 2
                    kind: OsdState.icon
                    level: OsdState.iconLevel
                    size: 16
                    color: Theme.island
                }
            }
        }
    }
}
