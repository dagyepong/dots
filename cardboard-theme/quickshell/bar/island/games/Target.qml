// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T A R G E T                                                            │
// │   one target at a time · it shrinks, and the bullseye is worth three     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"

// Target Smash: one target at a time, shrinking to nothing, faster as the
// score climbs. A hit scores three for the bullseye, two for the middle ring,
// one for the outer, judged by distance from the centre at the moment of the
// click. Clicks on empty ground do nothing.
//
// A target that shrinks away unclicked costs one of three lives. Mouse only.
FocusScope {
    id: root

    // ── CONTRACT ────────────────────────────────────────────────────────────

    property int score: 0
    property bool over: false
    property color tint: Theme.accent

    signal finished(int score)

    function restart(): void {
        burst.stop()
        root.score = 0
        root.lives = 3
        root.over = false
        root.place()
    }

    // ── GROUND ──────────────────────────────────────────────────────────────

    // Full target size, and its centre's margin from the edge: the burst grows
    // it by half again and the ground doesn't clip.
    readonly property int size: 96
    readonly property int margin: Math.ceil(root.size * 0.75)

    // Target lifetime: 1.6 s at the start, falling to 700 ms by thirty points.
    readonly property int lifetime: Math.max(700, 1600 - root.score * 30)

    // Part of the game's pace, so it ignores the shell's motion scale.
    readonly property int burstDuration: 220

    property int lives: 3
    property int targetX: 0
    property int targetY: 0
    property bool smashed: false

    focus: true

    Component.onCompleted: root.restart()

    function place(): void {
        const spanX = Math.max(0, ground.width - 2 * root.margin)
        const spanY = Math.max(0, ground.height - 2 * root.margin)
        root.targetX = root.margin + Math.round(Math.random() * spanX)
        root.targetY = root.margin + Math.round(Math.random() * spanY)
        root.smashed = false
        rings.scale = 1
        rings.opacity = 1
        shrink.restart()
    }

    function smash(x: real, y: real): void {
        if (root.over || root.smashed)
            return
        // The rings are thirds of the current on-screen radius.
        const radius = target.scale * root.size / 2
        const distance = Math.hypot(x - root.targetX, y - root.targetY)
        if (distance > radius)
            return
        root.score += distance <= radius / 3 ? 3 : distance <= radius * 2 / 3 ? 2 : 1
        root.smashed = true
        shrink.stop()
        burst.restart()
    }

    function miss(): void {
        if (root.over)
            return
        root.lives -= 1
        if (root.lives === 0) {
            root.over = true
            root.finished(root.score)
            return
        }
        root.place()
    }

    Rectangle {
        id: ground

        anchors.centerIn: parent
        width: Math.floor(root.width)
        height: Math.floor(root.height)
        radius: Theme.radiusMedium
        color: Theme.islandSurface
        border.color: Theme.islandBorder
        border.width: 1

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onPressed: event => root.smash(event.x, event.y)
        }

        // The target; its scale is the clock. Reaching zero is a miss; a hit
        // stops it, and the rings flash and burst before the next one.
        Item {
            id: target

            x: root.targetX - width / 2
            y: root.targetY - height / 2
            width: root.size
            height: root.size

            NumberAnimation on scale {
                id: shrink

                from: 1
                to: 0
                duration: root.lifetime
                running: !root.over && root.visible
                onFinished: root.miss()
            }

            Item {
                id: rings

                anchors.fill: parent

                // Outer, middle, bullseye: the tint at three strengths.
                Repeater {
                    model: [0.22, 0.5, 1]

                    Rectangle {
                        required property int index
                        required property real modelData

                        anchors.centerIn: parent
                        width: root.size * (3 - index) / 3
                        height: width
                        radius: width / 2
                        color: root.smashed ? Theme.text
                            : Qt.rgba(root.tint.r, root.tint.g, root.tint.b, modelData)
                    }
                }
            }

            ParallelAnimation {
                id: burst

                NumberAnimation {
                    target: rings
                    property: "scale"
                    from: 1
                    to: 1.5
                    duration: root.burstDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: rings
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: root.burstDuration
                }
                onFinished: root.place()
            }
        }

        // Three lives, top right; a lost one dims.
        Row {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 14
            spacing: 6

            Repeater {
                model: 3

                Rectangle {
                    required property int index

                    width: 8
                    height: 8
                    radius: Theme.radiusPill
                    color: Theme.red
                    opacity: index < root.lives ? 1 : 0.25

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.durationFast }
                    }
                }
            }
        }
    }
}
