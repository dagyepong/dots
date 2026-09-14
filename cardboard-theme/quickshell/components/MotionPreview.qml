// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M O T I O N   P R E V I E W                                            │
// │   a window opening on one preset's curve                                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"

// A window arriving on a tiny screen with the preset's curve and duration:
// popping in for popin presets, sliding for slide presets, appearing
// instantly for "None". Opacity never animates, since every preset disables
// `fadeIn`.
//
// Qt's bezier easing needs the end point spelled out, hence the trailing 1, 1.
Item {
    id: root

    // A row from `Motion.presets`.
    property var preset: null

    readonly property bool still: !root.preset || !root.preset.curve
    readonly property bool slides:
        root.preset && String(root.preset.windows ?? "").startsWith("slide")
    readonly property var bezier: root.still ? [0, 0, 1, 1, 1, 1] : [
        root.preset.curve[0], root.preset.curve[1],
        root.preset.curve[2], root.preset.curve[3], 1, 1]
    // Hyprland counts in deciseconds, so 2.6 is 260 ms. `slow` is the speed
    // windowsIn actually runs at.
    readonly property int span: root.still ? 0 : root.preset.slow * 100

    implicitWidth: 92
    implicitHeight: 46

    Rectangle {
        id: screen

        anchors.fill: parent
        radius: 5
        color: Theme.island
        border.color: Theme.islandBorder
        border.width: 1
        clip: true

        Rectangle {
            id: win

            property bool shown: false

            anchors.horizontalCenter: parent.horizontalCenter
            y: (parent.height - height) / 2
                + (root.slides && !win.shown ? 12 : 0)
            width: parent.width - 20
            height: parent.height - 16
            radius: 4
            color: Theme.accent
            scale: root.slides ? 1 : (win.shown ? 1 : 0.8)
            // Scale or slide only; presets disable fadeIn.
            opacity: win.shown ? 1 : 0

            Behavior on scale {
                enabled: !root.still
                NumberAnimation {
                    duration: root.span
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.bezier
                }
            }

            Behavior on y {
                enabled: !root.still
                NumberAnimation {
                    duration: root.span
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.bezier
                }
            }

            Timer {
                interval: 1300
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: win.shown = !win.shown
            }
        }
    }
}
