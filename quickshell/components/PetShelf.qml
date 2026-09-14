// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P E T   S H E L F                                                      │
// │   pet shelf · one slot per species                                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"

// The collection in one row: a slot per species (sleeping pets shown,
// undiscovered ones empty) and a line saying what earns the next. Clicking a
// sleeping pet brings it out. Used in the module detail and the control
// centre block.
RowLayout {
    id: root

    // Slot size, and whether to use the short caption (for the narrower
    // control centre block).
    property int slot: 32
    property bool brief: false

    spacing: 6

    Repeater {
        model: PetService.species.length

        Rectangle {
            id: slot

            required property int index

            readonly property bool filled: slot.index < PetService.family.length
            readonly property bool out: slot.index === PetService.activeIndex

            implicitWidth: root.slot
            implicitHeight: root.slot
            radius: width / 2
            color: slot.out
                ? Theme.islandSurface
                : (slotMouse.containsMouse ? Theme.islandSurfaceHover : "transparent")
            border.width: 1
            // The active pet in white; sleepers outlined, empty slots faint.
            border.color: slot.out
                ? Theme.indicator
                : (slot.filled ? Theme.islandBorder : Theme.hairline)

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            PetFace {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                visible: slot.filled
                size: Math.round(root.slot * 0.625)
                record: PetService.recordAt(slot.index)
                mood: PetService.moodAt(slot.index)
            }

            MouseArea {
                id: slotMouse

                anchors.fill: parent
                hoverEnabled: slot.filled && !slot.out
                cursorShape: slot.filled && !slot.out
                    ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: PetService.bringOut(slot.index)
            }
        }
    }

    Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        text: {
            if (PetService.complete)
                return "All five found"
            const left = PetService.levelsToNextEgg
            if (root.brief)
                return `${left} to the next egg`
            return left === 1
                ? "1 level to the next egg"
                : `${left} levels to the next egg`
        }
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
        color: Theme.textMuted
    }
}
