import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/PaletteMath.js" as PM

// A small mock-up of the shell (a bar pill with workspace badges and a clock chip, a
// card with a title, text lines and buttons, two tiles) painted in the colours of
// `colors`, as they would look if the palette were applied, in the CURRENT light /
// dark / darker mode.
//
// It never reads the live theme's palette (no ThemeService here, tests/palette-test
// checks that): the colours come only from PaletteMath.toShell(colors), the same
// function ThemeService uses for an applied palette. From Theme it takes only the mode
// and the fixed constants (outline alpha, dark factors...), which do not depend on the
// palette. The few lines that build a surface / outline / chip from the palette copy
// Theme.qml's formulas, since Theme can only wear the active palette.
//
//   PalettePreview { width: 440; height: 200; colors: PaletteService.colors }
Item {
    id: root

    property var colors: []

    readonly property var pal: PM.toShell(root.colors)
    readonly property bool dark: Theme.dark
    readonly property bool darker: Theme.darker

    // Every colour is a plain (not readonly) property so it can glide to the next value.
    property color cBorder: root.pal.border
    property color cA: root.pal.A
    property color cB: root.pal.B
    property color cWall1: root.pal.wallMid
    property color cWall2: root.pal.wallDark
    property color cLight: root.pal.wallLight
    property color cGlint: root.pal.glint
    property color cTint: root.pal.hoverTint

    property color cSurface: root.darker
        ? Qt.darker(Qt.color(root.pal.deep), Theme.darkerFactor)
        : (root.dark ? Qt.lighter(Qt.color(root.pal.deep), 1.18) : Qt.color("#ffffff"))
    property color cLine: root.darker
        ? Qt.darker(root.cBorder, Theme.darkerLineFactor)
        : (root.dark ? root.cBorder
            : Qt.tint(Qt.color("#ffffff"), Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, Theme.lightLineAlpha)))
    property color cShadow: root.darker
        ? Qt.darker(root.cBorder, Theme.darkerShadowFactor)
        : (root.dark ? Qt.darker(root.cBorder, Theme.darkShadowFactor)
            : Qt.tint(Qt.color("#ffffff"), Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, Theme.lightShadowAlpha)))
    property color cInk: root.dark ? Qt.color(root.pal.divider) : root.cBorder
    property color cChip: root.darker
        ? Qt.darker(root.cBorder, Theme.darkerLineFactor)
        : (root.dark ? root.cBorder
            : Qt.tint(Qt.color("#ffffff"), Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, Theme.lightChipAlpha)))
    property color cChipInk: root.dark ? Qt.color("#ffffff") : root.cBorder

    Behavior on cBorder { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on cA { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on cB { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on cWall1 { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on cWall2 { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on cLight { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on cGlint { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on cTint { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on cSurface { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on cLine { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on cShadow { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on cInk { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on cChip { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on cChipInk { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }

    implicitWidth: 440
    implicitHeight: 200

    // the "wallpaper" behind
    Rectangle {
        anchors.fill: parent
        radius: 16
        antialiasing: true
        border.width: 3
        border.color: root.cLine

        gradient: Gradient {
            GradientStop { position: 0; color: root.cWall1 }
            GradientStop { position: 1; color: root.cWall2 }
        }
    }

    // ===== the bar =====
    Item {
        id: bar
        x: 18
        y: 16
        width: root.width - 36
        height: 36

        Rectangle {
            y: 3
            width: parent.width
            height: parent.height
            radius: 18
            color: root.cShadow
            antialiasing: true
        }

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: root.cSurface
            border.width: 3
            border.color: root.cLine
            antialiasing: true

            // workspace badges
            Row {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: [0, 1, 2, 3, 4]
                    delegate: Rectangle {
                        required property int modelData
                        width: modelData === 0 ? 34 : 18
                        height: 18
                        radius: 9
                        antialiasing: true
                        border.width: 2
                        border.color: root.cBorder
                        color: modelData === 0 ? root.cA
                            : (modelData === 1 ? root.cB : (modelData === 2 ? root.cLight : (modelData === 3 ? root.cGlint : root.cTint)))
                    }
                }
            }

            // clock chip
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: clockText.implicitWidth + 18
                height: 22
                radius: 11
                color: root.cChip
                antialiasing: true

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: "12:34"
                    color: root.cChipInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }
            }
        }
    }

    // ===== a card =====
    Item {
        id: card
        x: 18
        y: 68
        width: Math.round(root.width * 0.60)
        height: root.height - 68 - 18

        Rectangle {
            y: 4
            width: parent.width
            height: parent.height
            radius: 14
            color: root.cShadow
            antialiasing: true
        }

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: root.cSurface
            border.width: 3
            border.color: root.cLine
            antialiasing: true

            Text {
                x: 14
                y: 10
                text: "Live preview"
                color: root.cInk
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }

            Column {
                x: 14
                y: 36
                spacing: 6

                Rectangle { width: card.width * 0.62; height: 7; radius: 3.5; color: root.cInk; opacity: 0.28 }
                Rectangle { width: card.width * 0.44; height: 7; radius: 3.5; color: root.cInk; opacity: 0.18 }
            }

            Row {
                x: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                spacing: 8

                // primary: the accent gradient, with the outline colour as its ink
                Rectangle {
                    width: 70
                    height: 26
                    radius: 10
                    antialiasing: true
                    border.width: 2
                    border.color: root.cBorder
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: root.cA }
                        GradientStop { position: 1; color: root.cB }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Apply"
                        color: root.cBorder
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                }

                Rectangle {
                    width: 70
                    height: 26
                    radius: 10
                    color: root.cChip
                    antialiasing: true

                    Text {
                        anchors.centerIn: parent
                        text: "Later"
                        color: root.cChipInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                }
            }
        }
    }

    // ===== two quick tiles =====
    Column {
        x: card.x + card.width + 14
        y: card.y
        width: root.width - x - 18
        spacing: 10

        Repeater {
            model: [{ icon: "wifi", on: true }, { icon: "bluetooth", on: false }]

            delegate: Item {
                required property var modelData
                width: parent.width
                height: (card.height - 10) / 2

                Rectangle {
                    y: 3
                    width: parent.width
                    height: parent.height
                    radius: 12
                    color: root.cShadow
                    antialiasing: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    antialiasing: true
                    border.width: 3
                    border.color: modelData.on ? root.cBorder : root.cLine
                    color: modelData.on ? root.cA : root.cSurface

                    MaterialIcon {
                        anchors.centerIn: parent
                        name: modelData.icon
                        size: 22
                        color: modelData.on ? root.cBorder : root.cInk
                    }
                }
            }
        }
    }
}
