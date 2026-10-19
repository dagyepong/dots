import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The THEME tab of Edit Desktop's shelf (EditTray.qml): the colour groups,
// each drawn as a little picture of the shell wearing that group's colours
// (a bar, a widget card, two Quick Panel keys), so you pick by how it looks,
// not by a name. This replaces the old drop-down card under the media pill
// (ThemePopup.qml).
//
//   click a tile     the whole shell, the card above included, re-colours live
//                    (ThemeService.setTheme); the pick is remembered
//   mouse wheel      scrolls the row sideways, if the tiles do not all fit
//
// The pictures are drawn from each group's own palette (`group.c`), not from
// the active theme, so every tile shows what you would get. They follow the
// current Light / Dark / Darker look for their surfaces, so the preview is
// honest about that too. The last tile is the Matugen (wallpaper) theme; its
// swatches are the live palette once matugen has made one.
//
// Tile size lives in `tileW` / `tileH`. The shelf is 168 tall, so keep
// tileH under about 140 (the selected badge pokes out above the tile).
Item {
    id: root

    readonly property real tileW: 150
    readonly property real tileH: 138

    // One group: the picture, its name, and a badge on the one that is on.
    component ThemeTile: Item {
        id: tile

        required property var group

        readonly property var c: group.c
        readonly property bool selected: ThemeService.current === group.id
        readonly property bool dark: ThemeService.dark

        // What the picture's surfaces are in the current look: white in Light,
        // the group's own dark tone in Dark / Darker (as Theme.qml makes them).
        readonly property color surf: dark ? Qt.lighter(Qt.color(c.deep), 1.18) : "#ffffff"
        readonly property color bg: dark ? Qt.darker(Qt.color(c.deep), 1.3) : Qt.color(c.boardBg)
        readonly property color skeleton: dark ? Qt.lighter(surf, 1.75) : Qt.color(c.divider)

        width: root.tileW
        height: root.tileH

        Gradient {
            id: onFill
            GradientStop { position: 0.0; color: Theme.accentMint }
            GradientStop { position: 1.0; color: Theme.accentCyan }
        }

        // The group's own accent stops, left to right.
        Gradient {
            id: accent
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: tile.c.A }
            GradientStop { position: 1.0; color: tile.c.B }
        }

        // The tile lifts a little under the pointer, like the shelf's slots.
        Pill {
            id: body
            width: tile.width
            height: tile.height
            y: tileArea.containsMouse && !tile.selected && !tileArea.pressed ? -3 : 0
            cornerRadius: 15
            ringWidth: 4
            shadowDx: 0
            shadowDy: 4
            pressed: tileArea.pressed
            fillColor: tileArea.containsMouse && !tile.selected ? Theme.pSurfaceHover : Theme.pSurface
            fillGradient: tile.selected ? onFill : null

            Behavior on y {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            // ===== the picture =====
            Item {
                id: pic
                x: 6
                y: 6
                width: body.capWidth - body.ringWidth * 2 - 12
                height: 92

                // Its hard drop shadow, then the card (the desktop).
                Rectangle {
                    y: 3
                    width: parent.width
                    height: parent.height - 3
                    radius: 10
                    color: tile.c.border
                    antialiasing: true
                }

                Rectangle {
                    id: card
                    width: parent.width
                    height: parent.height - 3
                    radius: 10
                    color: tile.bg
                    border.width: 3
                    border.color: tile.c.border
                    antialiasing: true

                    // The bar: a gradient key on the left, two dots on the right.
                    Rectangle {
                        x: 8
                        y: 8
                        width: card.width - 16
                        height: 15
                        radius: 7.5
                        color: tile.surf
                        border.width: 2
                        border.color: tile.c.border
                        antialiasing: true

                        Rectangle {
                            x: 6
                            y: 3.5
                            width: 24
                            height: 8
                            radius: 4
                            gradient: accent
                            antialiasing: true
                        }

                        Rectangle {
                            x: parent.width - 24
                            y: 4
                            width: 7
                            height: 7
                            radius: 3.5
                            color: tile.c.border
                            antialiasing: true
                        }

                        Rectangle {
                            x: parent.width - 14
                            y: 4
                            width: 7
                            height: 7
                            radius: 3.5
                            color: tile.c.A
                            antialiasing: true
                        }
                    }

                    // A widget card: title strip, two lines of text, a key.
                    Rectangle {
                        x: 8
                        y: 30
                        width: 58
                        height: card.height - 38
                        radius: 7
                        color: tile.surf
                        border.width: 2
                        border.color: tile.c.border
                        antialiasing: true

                        Rectangle {
                            x: 6
                            y: 6
                            width: 30
                            height: 8
                            radius: 4
                            gradient: accent
                            antialiasing: true
                        }

                        Rectangle {
                            x: 6
                            y: 19
                            width: 44
                            height: 4
                            radius: 2
                            color: tile.skeleton
                        }

                        Rectangle {
                            x: 6
                            y: 27
                            width: 32
                            height: 4
                            radius: 2
                            color: tile.skeleton
                        }

                        Rectangle {
                            x: 6
                            y: parent.height - 16
                            width: 24
                            height: 8
                            radius: 4
                            color: tile.c.border
                            antialiasing: true
                        }
                    }

                    // Two Quick Panel keys: one on (the gradient), one off.
                    Rectangle {
                        x: 72
                        y: 30
                        width: card.width - 72 - 8
                        height: (card.height - 38 - 4) / 2
                        radius: 8
                        gradient: accent
                        border.width: 2
                        border.color: tile.c.border
                        antialiasing: true

                        Rectangle {
                            x: 6
                            y: (parent.height - 8) / 2
                            width: 8
                            height: 8
                            radius: 4
                            color: tile.c.border
                            antialiasing: true
                        }
                    }

                    Rectangle {
                        x: 72
                        y: 30 + (card.height - 38 - 4) / 2 + 4
                        width: card.width - 72 - 8
                        height: (card.height - 38 - 4) / 2
                        radius: 8
                        color: tile.surf
                        border.width: 2
                        border.color: tile.c.border
                        antialiasing: true

                        Rectangle {
                            x: 6
                            y: (parent.height - 8) / 2
                            width: 8
                            height: 8
                            radius: 4
                            color: tile.c.A
                            antialiasing: true
                        }
                    }
                }
            }

            // ===== the name =====
            Text {
                x: 6
                y: pic.y + pic.height + 6
                width: pic.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: tile.group.id === "matugen" ? "Matugen" : tile.group.name
                color: tile.selected ? Theme.colBorder : Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }

        // The one that is on: a small tick badge on the corner.
        Rectangle {
            visible: tile.selected
            x: tile.width - 17
            y: -8
            width: 24
            height: 24
            radius: 12
            color: Theme.accentMint
            border.width: 2
            border.color: Theme.pLine
            antialiasing: true

            MaterialIcon {
                anchors.centerIn: parent
                name: "check"
                size: 15
                weight: 700
                color: Theme.colBorder
            }
        }

        MouseArea {
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: ThemeService.setTheme(tile.group.id)
        }
    }

    // The row. Centred; if the tiles do not all fit, it scrolls sideways.
    Flickable {
        id: flick
        anchors.fill: parent

        contentWidth: Math.max(flick.width, row.width)
        contentHeight: flick.height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        // Not clipped while everything fits, so the tick badge and the lift
        // can poke out above the tiles.
        clip: flick.contentWidth > flick.width + 1

        // A plain wheel scrolls the row (a Flickable only takes sideways ones).
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const d = Theme.wheelPx(event, true)
                flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, flick.contentX - d))
            }
        }

        Row {
            id: row
            x: Math.max(0, (flick.width - row.width) / 2)
            y: (flick.height - row.height) / 2
            spacing: 16

            Repeater {
                model: ThemeService.groups

                delegate: ThemeTile {
                    required property var modelData

                    group: modelData
                }
            }
        }
    }
}
