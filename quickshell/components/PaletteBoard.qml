// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P   A   L   E   T   T   E       B   O   A   R   D                      │
// │   palette board · the project mark in the active colours                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"

// The logo at any size: the board picture with five daubs in Theme tokens,
// placed from `Board`. Square, scaled from the board's canvas.
//
// Without a board installed it draws a single accent daub instead.

Item {
    id: root

    property real size: 64

    implicitWidth: root.size
    implicitHeight: root.size

    // Board coordinates to screen pixels; zero until the geometry loads.
    readonly property real factor: Board.ready ? root.size / Board.canvas : 0

    // Listed explicitly: a binding through `Theme[key]` is not tracked.
    readonly property var paints: ({
        accent: Theme.accent,
        green: Theme.green,
        yellow: Theme.yellow,
        red: Theme.red,
        blue: Theme.blue
    })

    Image {
        id: picture

        anchors.fill: parent
        source: Board.board
        // Decoded at twice the display size rather than the source 1254 px,
        // to keep the brush texture.
        sourceSize.width: Math.ceil(root.size * 2)
        sourceSize.height: Math.ceil(root.size * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        visible: picture.status === Image.Ready

        Repeater {
            model: Board.ready ? Board.paint : []

            Rectangle {
                required property var modelData

                width: Board.daubWidth * root.factor
                height: Board.daubHeight * root.factor
                radius: Board.daubRadius * root.factor
                // Positions are daub centres; x and y are the corner.
                x: modelData.x * root.factor - width / 2
                y: modelData.y * root.factor - height / 2
                rotation: modelData.rotation
                antialiasing: true
                color: root.paints[modelData.key] ?? Theme.accent

                Behavior on color { ColorAnimation { duration: Theme.durationMedium } }
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        visible: picture.status !== Image.Ready
        width: root.size * 0.42
        height: root.size * 0.27
        radius: height / 2
        rotation: -16
        antialiasing: true
        color: Theme.accent

        Behavior on color { ColorAnimation { duration: Theme.durationMedium } }
    }
}
