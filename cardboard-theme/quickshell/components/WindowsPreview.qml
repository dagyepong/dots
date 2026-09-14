// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W I N D O W S   P R E V I E W                                          │
// │   two tiled windows, drawn at the numbers the sliders hold               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

import "../theme"

// Two tiled windows over the real wallpaper, with the window settings applied
// at 1:1 rather than to scale (a scaled-down screen would shrink the gaps and
// corners to a few pixels). The focused window is drawn like kitty's.
Item {
    id: root

    property int rounding: 22
    property int borderWidth: 0
    property int gapsIn: 7
    property int gapsOut: 18
    property real inactiveOpacity: 1
    // Hyprland's blur size; zero is off. Approximated as size × 2^passes,
    // with look.lua's two passes.
    property int blur: 6
    // hyprglass, which replaces Hyprland's blur on the windows it draws.
    property bool glassed: false
    property bool lifted: false
    property string wallpaper: ""

    implicitHeight: 190

    // Hyprland clamps the radius to half the window height.
    readonly property real corner: Math.min(root.rounding, winHeight / 2)

    readonly property real winY: root.gapsOut
    readonly property real winHeight: screen.height - root.gapsOut * 2
    // `gaps_in` applies to each side of each window, so 2× between the pair.
    readonly property real winWidth:
        (screen.width - root.gapsOut * 2 - root.gapsIn * 2) / 2
    readonly property real leftX: root.gapsOut
    readonly property real rightX: root.leftX + root.winWidth + root.gapsIn * 2

    ClippingRectangle {
        id: screen

        anchors.fill: parent
        radius: 6
        color: Theme.island
        border.color: Theme.islandBorder
        border.width: 1
        contentUnderBorder: true

        Image {
            id: paper

            anchors.fill: parent
            source: root.wallpaper !== "" ? `file://${root.wallpaper}` : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        // Shadow, built like the bar's: grown silhouettes, blurred, behind
        // the windows.
        Item {
            id: silhouette

            anchors.fill: parent
            visible: false

            Rectangle {
                x: root.leftX - Theme.shadowSpread
                y: root.winY - Theme.shadowSpread
                width: root.winWidth + Theme.shadowSpread * 2
                height: root.winHeight + Theme.shadowSpread * 2
                radius: root.corner + Theme.shadowSpread
                color: Theme.shadowColor
            }

            Rectangle {
                x: root.rightX - Theme.shadowSpread
                y: root.winY - Theme.shadowSpread
                width: root.winWidth + Theme.shadowSpread * 2
                height: root.winHeight + Theme.shadowSpread * 2
                radius: root.corner + Theme.shadowSpread
                color: Theme.shadowColor
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: silhouette
            visible: root.lifted
            opacity: Theme.shadowOpacity
            blurEnabled: true
            blur: 1
            blurMax: (Theme.shadowRange - Theme.shadowSpread) * 2
        }

        // Focused window: a kitty terminal.
        ClippingRectangle {
            x: root.leftX
            y: root.winY
            width: root.winWidth
            height: root.winHeight
            radius: root.corner
            color: "transparent"
            border.width: root.borderWidth
            border.color: Theme.accent
            contentUnderBorder: true

            // The wallpaper behind the window, offset to line up, as the
            // blur's source.
            Item {
                id: throughGlass

                anchors.fill: parent
                visible: false

                Image {
                    x: -root.leftX
                    y: -root.winY
                    width: screen.width
                    height: screen.height
                    source: paper.source
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            // look.lua sets the glass blur below Hyprland's (0.7 × 12 px vs
            // size 6 × 2 passes), so enabling glass sharpens the background.
            // Saturation 0.9 in the plugin is an offset of -0.10 here.
            MultiEffect {
                anchors.fill: parent
                source: throughGlass
                blurEnabled: root.glassed || root.blur > 0
                blur: 1
                blurMax: root.glassed ? 8 : root.blur * 4
                saturation: root.glassed ? -0.10 : 0
            }

            // Fresnel rim and specular highlight, drawn under the terminal
            // background as the plugin does, so they show only through the
            // window's translucency. Refraction and chromatic aberration are
            // not simulated.
            Rectangle {
                anchors.fill: parent
                visible: root.glassed
                color: "transparent"
                radius: root.corner
                border.width: 2
                border.color: Qt.rgba(1, 1, 1, 0.5)
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: parent.height * 0.45
                visible: root.glassed
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.25) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }

            // kitty's background: the accent at 22%, at kitty.conf's
            // `background_opacity` (keep in sync).
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Theme.accent.r * 0.22, Theme.accent.g * 0.22,
                               Theme.accent.b * 0.22, 0.90)
            }

            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 14
                anchors.bottomMargin: 12
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "❯"
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Theme.green
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 12
                    color: Theme.text
                    opacity: 0.85
                }
            }
        }

        // Unfocused window. Item opacity matches Hyprland's inactive_opacity.
        ClippingRectangle {
            x: root.rightX
            y: root.winY
            width: root.winWidth
            height: root.winHeight
            radius: root.corner
            color: Theme.surface
            border.width: root.borderWidth
            border.color: Theme.islandBorder
            contentUnderBorder: true
            opacity: root.inactiveOpacity

            Column {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: 14
                anchors.topMargin: 14
                spacing: 7

                Rectangle { width: 74; height: 5; radius: 2.5; color: Theme.textMuted; opacity: 0.6 }
                Rectangle { width: 118; height: 5; radius: 2.5; color: Theme.textMuted; opacity: 0.3 }
                Rectangle { width: 96; height: 5; radius: 2.5; color: Theme.textMuted; opacity: 0.3 }
            }
        }
    }
}
