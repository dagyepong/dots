import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.widgets

// Vertical: a piece fused with the right edge of the frame (with the concave curves where it meets it),
// volume and brightness one under the other, in the middle of the edge.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property bool mine: Style.current === "side"
    readonly property bool on: mine && OsdState.shown

    readonly property int rows: Brightness.available ? 2 : 1
    readonly property real rowH: 30
    readonly property real gap: 10
    readonly property real pad: 14
    readonly property real fillet: 14
    readonly property real bodyLength: rows * rowH + (rows - 1) * gap + pad * 2
    readonly property real depth: 260

    anchors { right: true }
    margins { right: 8 }             // the thickness of the frame: it starts where the frame ends

    implicitWidth: depth
    implicitHeight: bodyLength + fillet * 2
    color: "transparent"
    visible: mine && (OsdState.shown || shape.x < depth - 1)

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-osd"

    mask: Region {}

    AttachedShapeSide {
        id: shape
        x: win.on ? 0 : win.depth
        y: 0
        bodyDepth: win.depth
        bodyLength: win.bodyLength
        fillet: win.fillet
        corner: 18

        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        Column {
            x: 14
            y: win.fillet + win.pad
            spacing: win.gap

            Repeater {
                model: win.rows

                delegate: Item {
                    required property int index
                    readonly property bool isVol: index === 0
                    readonly property real v: isVol ? OsdState.volume : OsdState.brightness

                    width: win.depth - 14 - win.fillet - 12
                    height: win.rowH

                    SliderBar {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.rightMargin: 44
                        anchors.verticalCenter: parent.verticalCenter
                        height: 24
                        implicitHeight: 24
                        enabled: false
                        value: parent.v
                        icon: parent.isVol ? "volume" : "sun"
                        iconLevel: parent.isVol ? ((Audio.muted) ? 0 : (parent.v > 0.5 ? 2 : 1)) : (parent.v > 0.5 ? 2 : 1)
                        track: Theme.mix(Theme.island, Theme.foreground, 0.14)
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(parent.v * 100) + "%"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
            }
        }
    }
}
