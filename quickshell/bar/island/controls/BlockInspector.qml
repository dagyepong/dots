// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B L O C K   I N S P E C T O R                                          │
// │   block inspector · size and tiles                                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"
import "../../../services"
import "../../../components"

// Opens beside a block clicked while the grid is being arranged: the sizes
// the block offers, drawn as cell footprints, and for the toggles block which
// switches it carries.
//
// Fills the grid so the card can go wherever there is room (right of the
// block, then left, then below) and so clicks on the card stay on it.
Item {
    id: root

    required property Item board

    readonly property string key: ControlsService.selected
    readonly property var block: ControlsService.entryOf(root.key)
    readonly property string blockId: root.block ? root.block.id : ""
    readonly property var entry: ControlsService.entry(root.blockId)
    readonly property var box: root.block
        ? ControlsService.geometry(root.block) : ({ x: 0, y: 0, width: 0, height: 0 })

    readonly property bool onToggles: root.blockId === "toggles"

    readonly property int cardWidth: 268
    readonly property int pad: 14
    readonly property int gap: 14

    Rectangle {
        id: card

        readonly property bool rightFits:
            root.box.x + root.box.width + root.gap + card.width <= root.board.width
        readonly property bool leftFits:
            root.box.x - root.gap - card.width >= 0

        x: card.rightFits ? root.box.x + root.box.width + root.gap
            : (card.leftFits ? root.box.x - root.gap - card.width
                : Math.max(0, Math.min(root.board.width - card.width, root.box.x)))
        y: Math.max(0, Math.min(root.board.height - card.height,
            card.rightFits || card.leftFits
                ? root.box.y : root.box.y + root.box.height + root.gap))

        width: root.cardWidth
        height: column.implicitHeight + 2 * root.pad
        radius: Theme.radiusLarge
        color: Theme.island
        border.color: Theme.islandBorder
        border.width: 1

        Behavior on x { NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing } }
        Behavior on y { NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing } }

        // Exclusive from the press, or the ground's tap underneath would close
        // the inspector.
        TapHandler {
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
        }

        Column {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.pad
            spacing: 12

            // ── NAME ────────────────────────────────────────────────────────

            Item {
                width: parent.width
                height: 28

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.entry ? Tr.t(root.entry.name) : ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                PillButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.t("Remove")
                    implicitHeight: 26
                    onClicked: ControlsService.remove(root.key)
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.hairline }

            // ── SIZE ────────────────────────────────────────────────────────
            //
            // Every size the block offers, as its footprint in cells. The
            // corner handle and the wheel do the same.

            Text {
                text: Tr.t("Size")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.weight: Font.DemiBold
                color: Theme.textMuted
            }

            Flow {
                width: parent.width
                spacing: 8

                Repeater {
                    model: ControlsService.sizesFor(root.blockId)

                    Rectangle {
                        id: sizeTile

                        required property string modelData

                        readonly property var shape: ControlsService.parse(sizeTile.modelData)
                        readonly property bool current:
                            ControlsService.sizeOf(root.block) === sizeTile.modelData

                        width: Math.max(48, sizeTile.shape.cols * 11 + 16)
                        height: 58
                        radius: Theme.radiusSmall
                        color: sizeTile.current ? Theme.islandSurfaceHover : "transparent"
                        border.color: sizeTile.current ? Theme.accent : Theme.hairline
                        border.width: 1

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: sizeLabel.top
                            anchors.bottomMargin: 6
                            width: sizeTile.shape.cols * 11
                            height: sizeTile.shape.rows * 4
                            radius: 2
                            color: sizeTile.current ? Theme.accent : Theme.textMuted
                        }

                        Text {
                            id: sizeLabel

                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            text: ControlsService.label(sizeTile.modelData)
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            color: sizeTile.current ? Theme.text : Theme.textMuted
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: ControlsService.setSize(root.key, sizeTile.modelData)
                        }
                    }
                }
            }

            // ── TILES ───────────────────────────────────────────────────────
            //
            // Toggles block only: every switch in the catalogue, ticked when it
            // is on this block. A newly ticked tile goes to the end; the arrows
            // reorder.

            Text {
                visible: root.onToggles
                text: Tr.t("Toggles")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.weight: Font.DemiBold
                color: Theme.textMuted
            }

            Column {
                visible: root.onToggles
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.onToggles ? ControlsService.tileRowsOf(root.key) : []

                    Rectangle {
                        id: tickRow

                        required property var modelData

                        readonly property bool on:
                            ControlsService.showsTileIn(root.key, tickRow.modelData.key)
                        readonly property var order: ControlsService.toggleKeysOf(root.key)
                        readonly property int at: tickRow.order.indexOf(tickRow.modelData.key)

                        width: parent.width
                        height: 24
                        radius: Theme.radiusSmall
                        color: tickHover.hovered ? Theme.islandSurfaceHover : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 8

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                radius: 4
                                color: tickRow.on ? Theme.accent : "transparent"
                                border.color: tickRow.on ? Theme.accent : Theme.textMuted
                                border.width: 1.5

                                Text {
                                    anchors.centerIn: parent
                                    visible: tickRow.on
                                    text: "󰄬"
                                    font.family: Theme.fontMono
                                    font.pixelSize: 9
                                    color: Theme.accentText
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                horizontalAlignment: Text.AlignHCenter
                                text: tickRow.modelData.icon
                                font.family: Theme.fontMono
                                font.pixelSize: 12
                                color: tickRow.on ? Theme.accent : Theme.textMuted
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 46 - (tickRow.on ? 44 : 0)
                                text: Tr.t(tickRow.modelData.label)
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: tickRow.on ? Theme.text : Theme.textMuted
                            }
                        }

                        HoverHandler { id: tickHover; cursorShape: Qt.PointingHandCursor }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: ControlsService.toggleTileIn(root.key, tickRow.modelData.key)
                        }

                        // Declared after the row's tap so a press on an arrow
                        // goes to the arrow.
                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            visible: tickRow.on
                            spacing: 2

                            Repeater {
                                model: [{ glyph: "󰅃", delta: -1 }, { glyph: "󰅀", delta: 1 }]

                                Rectangle {
                                    id: arrow

                                    required property var modelData

                                    readonly property bool usable: arrow.modelData.delta < 0
                                        ? tickRow.at > 0 : tickRow.at < tickRow.order.length - 1

                                    width: 20
                                    height: 20
                                    radius: Theme.radiusSmall
                                    color: arrowHover.hovered && arrow.usable
                                        ? Theme.islandSurface : "transparent"
                                    opacity: arrow.usable ? 1 : 0.3

                                    Text {
                                        anchors.centerIn: parent
                                        text: arrow.modelData.glyph
                                        font.family: Theme.fontMono
                                        font.pixelSize: 11
                                        color: Theme.text
                                    }

                                    HoverHandler { id: arrowHover }

                                    // Always takes the press, even when
                                    // disabled, so a tap doesn't fall through
                                    // to the row and untick the tile.
                                    TapHandler {
                                        gesturePolicy: TapHandler.ReleaseWithinBounds
                                        onTapped: {
                                            if (arrow.usable)
                                                ControlsService.moveTileIn(root.key,
                                                    tickRow.modelData.key, arrow.modelData.delta)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
