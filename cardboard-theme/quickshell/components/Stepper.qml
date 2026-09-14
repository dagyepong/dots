// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S T E P P E R                                                          │
// │   a number with an arrow either side of it                               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"

// A value nudged with arrows, wrapping at both ends. Compact enough to fit
// two across in the island.
Rectangle {
    id: root

    property int value: 0
    property int maximum: 59
    property string unit: ""

    signal changed(int value)

    implicitWidth: 62
    implicitHeight: 26
    radius: Theme.radiusSmall
    color: Theme.islandSurface
    border.color: Theme.islandBorder
    border.width: 1

    function step(delta: int): void {
        root.changed((root.value + delta + root.maximum + 1) % (root.maximum + 1))
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        text: `${root.value < 10 ? "0" : ""}${root.value} ${root.unit}`
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.text
    }

    Column {
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Repeater {
            model: [{ glyph: "󰅃", delta: 1 }, { glyph: "󰅀", delta: -1 }]

            Item {
                required property var modelData

                width: 14
                height: 12

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.glyph
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    color: arrow.containsMouse ? Theme.accent : Theme.textMuted

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                MouseArea {
                    id: arrow
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.step(parent.modelData.delta)
                }
            }
        }
    }
}
