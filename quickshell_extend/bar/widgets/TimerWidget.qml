// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T I M E R   W I D G E T                                                │
// │   the countdown as a ring, beside the battery                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../../components"

// The countdown as a ring, like the battery's. A click opens the detail,
// where pause, restart and cancel live. A clock glyph in the middle rather
// than a number, which would be too small to read. The ring's colour steps
// with the time left; idle, it is an empty ring, since starting a countdown is
// part of what the module is for.
RingIndicator {
    id: root

    property real size: Theme.capsuleHeight

    implicitWidth: root.size
    implicitHeight: root.size

    progress: TimerService.running ? TimerService.progress : 0
    thickness: 2.5

    trackColor: Theme.indicatorDim
    fillColor: TimerService.tint

    Behavior on fillColor { ColorAnimation { duration: Theme.durationMedium } }

    Text {
        anchors.centerIn: parent
        text: "󰥔"
        font.family: Theme.fontMono
        font.pixelSize: Math.round(root.size * 0.36)
        color: TimerService.paused || !TimerService.running
            ? Theme.textMuted : Theme.indicator

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }
}
