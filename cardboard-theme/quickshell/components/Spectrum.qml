// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S P E C T R U M                                                        │
// │   audio spectrum bars                                                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"

// Bars grow from the centre line, like a waveform, with a small floor at
// silence so the row never disappears.
Item {
    id: root

    // False flattens the bars to their floor.
    property bool active: true

    property color barColor: Theme.accent
    property real barWidth: 3
    property real minimum: 3

    // cava reports linear amplitude; a fractional power keeps quiet passages
    // visible.
    property real curve: 0.55

    property real barSpacing: 2

    // Sized from its own bars, so layouts can place it exactly.
    readonly property int barCount: CavaService.values.length

    implicitWidth: root.barCount > 0
        ? root.barCount * root.barWidth + (root.barCount - 1) * root.barSpacing
        : 0
    implicitHeight: 16

    RowLayout {
        anchors.fill: parent
        spacing: root.barSpacing

        Repeater {
            model: CavaService.values

            Rectangle {
                required property real modelData

                Layout.preferredWidth: root.barWidth
                Layout.preferredHeight: root.active
                    ? Math.max(root.minimum,
                        root.height * Math.pow(Math.max(0, modelData), root.curve))
                    : root.minimum
                Layout.alignment: Qt.AlignVCenter
                radius: width / 2
                color: root.barColor

                // Short enough to follow the beat, long enough to hide a
                // dropped cava frame.
                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 70; easing.type: Easing.OutQuad }
                }
            }
        }
    }
}
