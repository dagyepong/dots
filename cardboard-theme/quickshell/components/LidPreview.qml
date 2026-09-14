// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L I D   P R E V I E W                                                  │
// │   a laptop and a monitor, and which of them is lit                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"

// A laptop beside a monitor, showing which screen stays lit when the lid
// closes. Not to scale.
Item {
    id: root

    // Whether the laptop's own panel is lit behind the closed lid.
    property bool lit: false

    // Whether a second screen is drawn. The "let the system decide" tile shows
    // the laptop alone.
    property bool external: true

    implicitWidth: 104
    implicitHeight: 52

    Row {
        anchors.centerIn: parent
        spacing: 10

        // The laptop, lid partly closed.
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Rectangle {
                width: 40
                height: 24
                radius: Theme.radiusSmall - 4
                color: root.lit ? Theme.accent : Theme.island
                border.color: Theme.islandBorder
                border.width: 1
                opacity: root.lit ? 1 : 0.8

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                // The closed lid as a line across the screen; a side-on hinge
                // is unreadable at this size.
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 10
                    height: 1
                    color: root.lit ? Theme.accentText : Theme.islandBorder
                    opacity: 0.7
                }
            }

            Rectangle {
                width: 46
                height: 3
                radius: 1.5
                x: -3
                color: Theme.islandBorder
            }
        }

        // The monitor, always lit when present.
        Column {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.external
            spacing: 2

            Rectangle {
                width: 44
                height: 28
                radius: Theme.radiusSmall - 4
                color: Theme.accent
                border.color: Theme.islandBorder
                border.width: 1
            }

            Rectangle {
                width: 14
                height: 3
                radius: 1.5
                x: 15
                color: Theme.islandBorder
            }
        }
    }
}
