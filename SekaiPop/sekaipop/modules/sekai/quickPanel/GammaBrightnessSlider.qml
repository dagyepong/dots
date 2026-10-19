import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.phone

// Gamma and Brightness as ONE slider in the Quick Panel — a single
// continuous track, the first (short) stretch of it is gamma and the rest
// is brightness, with a tick where one hands over to the other:
//
//   (o) 100%  | (*) 72%        (icon + value; the words are gone: they did not fit)
//   ==================|=================================
//
// Same look as VolumeSlider's `simple` mode (plain icon + label + value
// header, thin gradient track). Press anywhere on the track and drag: the
// value under the pointer follows it, and the drag carries on across the
// tick into the other side — leaving gamma to the right pins it at 100%
// and brightness takes over; leaving brightness to the left pins it at 0%
// and gamma takes over. So one drag sweeps the whole slider. Pure UI:
// QuickPanelFace feeds it `gamma` / `brightness` (0-100) and reads changes
// back out through `gammaMoved` / `brightnessMoved`.
Item {
    id: root

    property real gamma: 100        // 0-100 (100 = unchanged)
    property real brightness: 100   // 0-100
    // hyprsunset can't go usefully below this — the gamma side stops there.
    property real gammaMin: 10

    // Total footprint (same as the Brightness slider it replaces).
    property real sliderWidth: 514
    // How much of the track is gamma.
    property real gammaWidth: 176

    signal gammaMoved(real value)
    signal brightnessMoved(real value)

    implicitWidth: sliderWidth
    implicitHeight: 56

    readonly property real edge: 20                          // left/right margin, as VolumeSlider
    readonly property real trackWidth: sliderWidth - edge * 2
    readonly property real brightnessWidth: trackWidth - gammaWidth

    // The track follows the pointer while dragging, not the real values
    // (which only catch up after the round trip to hyprsunset/brightnessctl).
    // -1 = this side isn't being driven by the current drag.
    property bool dragging: false
    property string dragSide: ""       // side the pointer is over: "gamma" | "brightness"
    property real dragGamma: -1
    property real dragBrightness: -1
    readonly property real shownGamma: dragging && dragGamma >= 0 ? dragGamma : gamma
    readonly property real shownBrightness: dragging && dragBrightness >= 0 ? dragBrightness : brightness

    readonly property color ink: Theme.pInk
    readonly property color inkSub: Qt.rgba(ink.r, ink.g, ink.b, 0.667)

    // ===== headers =====
    Item {
        id: gammaHead
        x: root.edge
        width: root.gammaWidth - 12
        height: 32

        MaterialIcon {
            id: gammaGlyph
            x: 0
            y: (32 - height) / 2
            size: 24
            color: root.ink
            name: "contrast"
        }
        Text {
            id: gammaPct
            anchors.left: gammaGlyph.right
            anchors.leftMargin: 8
            y: (32 - height) / 2
            text: Math.round(root.shownGamma) + "%"
            color: root.ink
            font.family: Theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }

    Item {
        id: brightHead
        x: root.edge + root.gammaWidth + 12
        width: root.brightnessWidth - 12
        height: 32

        MaterialIcon {
            id: brightGlyph
            x: 0
            y: (32 - height) / 2
            size: 24
            color: root.ink
            name: "light_mode"
        }
        Text {
            id: brightPct
            anchors.left: brightGlyph.right
            anchors.leftMargin: 8
            y: (32 - height) / 2
            text: Math.round(root.shownBrightness) + "%"
            color: root.ink
            font.family: Theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }

    // ===== the one track =====
    Rectangle {
        id: track
        x: root.edge
        y: 42
        width: root.trackWidth
        height: 14
        radius: 7
        color: Theme.pSurfaceDivider
        antialiasing: true

        // gamma's stretch
        Rectangle {
            width: root.gammaWidth * Math.max(0, Math.min(1, root.shownGamma / 100))
            height: parent.height
            radius: 7
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.accentMint }
                GradientStop { position: 1.0; color: Theme.accentCyan }
            }
            Behavior on width {
                enabled: !root.dragging
                NumberAnimation { duration: 150 }
            }
        }

        // brightness's stretch
        Rectangle {
            x: root.gammaWidth
            width: root.brightnessWidth * Math.max(0, Math.min(1, root.shownBrightness / 100))
            height: parent.height
            radius: 7
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.accentMint }
                GradientStop { position: 1.0; color: Theme.accentCyan }
            }
            Behavior on width {
                enabled: !root.dragging
                NumberAnimation { duration: 150 }
            }
        }

        // where gamma ends and brightness begins
        Rectangle {
            x: root.gammaWidth - 1.5
            y: -3
            width: 3
            height: parent.height + 6
            radius: 1.5
            color: root.ink
            opacity: 0.55
            antialiasing: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function setFromX(mx) {
                const side = mx < root.gammaWidth ? "gamma" : "brightness"
                // The pointer crossed the tick: the side it left is finished,
                // so it goes to its far end (the end nearest the tick).
                if (root.dragSide !== "" && side !== root.dragSide) {
                    if (root.dragSide === "gamma") {
                        root.dragGamma = 100
                        root.gammaMoved(100)
                    } else {
                        root.dragBrightness = 0
                        root.brightnessMoved(0)
                    }
                }
                root.dragSide = side
                if (side === "gamma") {
                    const p = Math.max(0, Math.min(1, mx / root.gammaWidth))
                    root.dragGamma = Math.max(root.gammaMin, p * 100)
                    root.gammaMoved(root.dragGamma)
                } else {
                    const p = Math.max(0, Math.min(1, (mx - root.gammaWidth) / root.brightnessWidth))
                    root.dragBrightness = p * 100
                    root.brightnessMoved(root.dragBrightness)
                }
                PanelActivity.touch()
            }

            function endDrag() {
                root.dragging = false
                root.dragSide = ""
                root.dragGamma = -1
                root.dragBrightness = -1
            }

            onPressed: mouse => {
                root.dragSide = ""
                root.dragGamma = -1
                root.dragBrightness = -1
                root.dragging = true
                setFromX(mouse.x)
            }
            onPositionChanged: mouse => {
                if (pressed)
                    setFromX(mouse.x)
            }
            onReleased: endDrag()
            onCanceled: endDrag()
        }
    }
}
