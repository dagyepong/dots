// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B A R   P R E V I E W                                                  │
// │   the bar's style, drawn small                                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"

// A thumbnail of a screen with the bar on it, showing only what the bar
// settings change: whether the island touches the top edge, where the sides
// sit, and whether it is one capsule. The real bar is a layer surface and
// cannot be embedded.
Item {
    id: root

    property bool attached: false

    // One of `SettingsService.barStyles`.
    property string barStyle: "grouped"

    readonly property bool grouped: root.barStyle !== "spread" && root.barStyle !== "island"
    readonly property bool unified: root.barStyle === "island"

    implicitWidth: 108
    implicitHeight: 62

    // The screen outline, so "attached" has an edge to attach to.
    Rectangle {
        id: screen

        anchors.centerIn: parent
        width: root.width - 12
        height: root.height - 14
        radius: 5
        color: Theme.island
        border.color: Theme.islandBorder
        border.width: 1
        clip: true

        readonly property int band: 7

        // Only the island reaches the top edge; notch mode moves nothing else.
        readonly property int inset: 4

        readonly property int islandWidth: 22
        readonly property int gap: 3

        // Single-capsule style, island in the middle.
        Rectangle {
            visible: root.unified
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.attached ? 0 : screen.inset
            width: 66
            height: screen.band + (root.attached ? screen.inset : 0)
            radius: height / 2
            topLeftRadius: root.attached ? 0 : radius
            topRightRadius: root.attached ? 0 : radius
            color: Theme.islandSurface
        }

        // The two sides: against the island when grouped, at the edges when
        // spread.
        Rectangle {
            visible: !root.unified
            x: root.grouped
                ? (screen.width - screen.islandWidth) / 2 - screen.gap - width
                : 6
            y: screen.inset
            width: 12
            height: screen.band
            radius: height / 2
            color: Theme.islandSurface
        }

        Rectangle {
            visible: !root.unified
            x: root.grouped
                ? (screen.width + screen.islandWidth) / 2 + screen.gap
                : screen.width - 6 - width
            y: screen.inset
            width: 18
            height: screen.band
            radius: height / 2
            color: Theme.islandSurface
        }

        // The island.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.attached ? 0 : screen.inset
            width: screen.islandWidth
            height: screen.band + (root.attached ? screen.inset : 0)
            radius: height / 2
            topLeftRadius: root.attached ? 0 : radius
            topRightRadius: root.attached ? 0 : radius
            color: Theme.accent
        }
    }
}
