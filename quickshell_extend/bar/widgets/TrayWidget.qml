// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T R A Y   W I D G E T                                                  │
// │   the applications' tray icons · one capsule                             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import Quickshell
import "../../theme"
import "../../services"
import "../../components"

// The tray's icons in one capsule, in grey so an application's colours do not
// break the black (`TrayIcon`). A click is the item's own action, a
// right click opens its menu in the island, a middle click its second action
// and the wheel scrolls it. Past `fold` icons the rest fold behind a count.
Item {
    id: root

    // Inside the one capsule, where the band is already the ground.
    property bool chromeless: false

    // A preview for the layout editor: drawn, never clicked.
    property bool still: false

    readonly property int fold: 5
    property bool unfolded: false

    readonly property var items: TrayService.items
    readonly property bool folds: root.items.length > root.fold
    readonly property var shown: root.folds && !root.unfolded
        ? root.items.slice(0, root.fold - 1) : root.items

    readonly property int slot: Theme.capsuleHeight - 6
    // The box a glyph gets on the bar (`ChipFace`), so a tray icon's drawing
    // is as tall as the glyphs beside it.
    readonly property int mark: Math.round(Theme.capsuleHeight * 0.44)
    readonly property int pad: root.chromeless ? 0 : 3

    implicitWidth: row.implicitWidth + 2 * root.pad
    implicitHeight: Theme.capsuleHeight

    Rectangle {
        id: ground

        anchors.fill: parent
        radius: height / 2
        color: root.chromeless ? "transparent" : Theme.islandGround
        border.color: Theme.islandRim
        border.width: root.chromeless ? 0 : 1
    }

    GlassSheen {
        shape: ground
        visible: Theme.glass && !root.chromeless
    }

    Row {
        id: row

        x: root.pad
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: root.shown

            Item {
                id: entry

                required property var modelData

                readonly property bool open: ModuleService.shownPanel === "tray"
                    && TrayService.item === entry.modelData

                width: root.slot
                height: root.slot

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Theme.surfaceHoverIn(QsWindow.window)
                    opacity: mouse.containsMouse || entry.open ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                }

                TrayIcon {
                    anchors.centerIn: parent
                    width: root.mark
                    height: width
                    icon: entry.modelData.icon
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    enabled: !root.still
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: event => {
                        if (event.button === Qt.RightButton)
                            TrayService.open(entry.modelData)
                        else if (event.button === Qt.MiddleButton)
                            entry.modelData.secondaryActivate()
                        else
                            TrayService.activate(entry.modelData)
                    }
                    onWheel: event => entry.modelData.scroll(event.angleDelta.y / 120, false)
                }
            }
        }

        // The folded rest, as a count; a click unfolds and folds them.
        Item {
            visible: root.folds
            width: root.slot
            height: root.slot

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.surfaceHoverIn(QsWindow.window)
                opacity: more.containsMouse ? 1 : 0
            }

            Text {
                anchors.centerIn: parent
                text: root.unfolded ? "󰅁" : `+${root.items.length - root.fold + 1}`
                font.family: root.unfolded ? Theme.fontMono : Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.weight: Font.DemiBold
                color: Theme.textMuted
            }

            MouseArea {
                id: more

                anchors.fill: parent
                enabled: !root.still
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.unfolded = !root.unfolded
            }
        }
    }
}
