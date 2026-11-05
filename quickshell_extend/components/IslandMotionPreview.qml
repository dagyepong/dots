// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I S L A N D   M O T I O N   P R E V I E W                              │
// │   the island opening and closing, at one preset's pace                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"

// The island morphing between its resting capsule and a panel, using the
// motion preset being previewed.
Item {
    id: root

    // A row from `Theme.motionPresets`.
    property var preset: null

    readonly property real pace: root.preset ? root.preset.scale / 100 : 1
    readonly property bool still: root.pace === 0

    implicitWidth: 92
    implicitHeight: 40

    Rectangle {
        id: isle

        property bool open: false

        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: isle.open ? parent.width - 8 : 46
        height: isle.open ? parent.height - 6 : 16
        radius: height / 2
        color: Theme.accent

        Behavior on width {
            enabled: !root.still
            NumberAnimation {
                duration: 380 * root.pace
                easing.type: root.preset ? Theme.easingTypeOf(root.preset.curve)
                                         : Easing.OutCubic
            }
        }

        Behavior on height {
            enabled: !root.still
            NumberAnimation {
                duration: 380 * root.pace
                easing.type: root.preset ? Theme.easingTypeOf(root.preset.curve)
                                         : Easing.OutCubic
            }
        }

        Timer {
            interval: 1300
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: isle.open = !isle.open
        }
    }
}
