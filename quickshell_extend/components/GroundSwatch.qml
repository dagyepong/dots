// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G R O U N D   S W A T C H                                              │
// │   one ground on the wallpaper · classic or glass                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

import "../theme"
import "../services"

// A capsule in one ground over the current wallpaper, blurred as the
// compositor blurs it behind the glass, so the choice is seen on the
// settings' black. Drawn at one size and scaled: 60 by 40 at a factor of one.
ClippingRectangle {
    id: root

    property string style: "classic"
    property real factor: 1

    implicitWidth: Math.round(60 * root.factor)
    implicitHeight: Math.round(40 * root.factor)
    radius: Theme.radiusSmall
    color: Theme.island

    Image {
        id: wallpaper

        anchors.fill: parent
        visible: false
        source: WallpaperService.currentWallpaper !== "" ? `file://${WallpaperService.currentWallpaper}` : ""
        sourceSize.width: 160
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        blurEnabled: root.style !== "classic"
        blur: 1
        blurMax: 24
    }

    Rectangle {
        id: capsule

        anchors.fill: parent
        anchors.margins: Math.round(8 * root.factor)
        radius: height / 3
        color: Theme.groundOf(root.style)
        border.color: Theme.rimOf(root.style)
        border.width: 1

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            visible: root.style === "glass"
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.glassSheen }
                GradientStop { position: 0.5; color: "transparent" }
            }
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, Theme.glassEdge)
        }

        Text {
            anchors.centerIn: parent
            text: "Aa"
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(11 * root.factor)
            font.weight: Font.DemiBold
            color: Theme.text
        }
    }
}
