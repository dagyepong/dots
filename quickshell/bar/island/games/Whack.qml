// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W H A C K                                                              │
// │   nine holes · a digit or a click, and the mole drops                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"

// Whack-a-Mole: nine holes numbered like a phone keypad (1 top left, 9 bottom
// right). Up to two moles at a time pop up, wait and duck; a click or the
// hole's digit drops one for a point. Moles stay up for less as the score
// climbs. Rounds last 45 seconds, shown by the bar at the top.
//
// A miss (an empty hole's digit or a click on one) costs two seconds, so
// mashing the digits doesn't pay. Further misses are ignored for a third of a
// second after one.
FocusScope {
    id: root

    // ── CONTRACT ────────────────────────────────────────────────────────────

    property int score: 0
    property bool over: false
    property color tint: Theme.accent

    signal finished(int score)

    function restart(): void {
        root.up = Array(root.holes).fill(false)
        root.until = Array(root.holes).fill(0)
        root.elapsed = 0
        root.spawnGap = 600
        root.score = 0
        root.missHole = -1
        root.missLeft = 0
        root.over = false
    }

    // ── FIELD ───────────────────────────────────────────────────────────────

    readonly property int columns: 3
    readonly property int rows: 3
    readonly property int holes: root.columns * root.rows
    readonly property int cell: Math.max(1, Math.floor(
        Math.min(root.width / root.columns, root.height / root.rows)))

    // Counted in ticks rather than wall time, so hiding the island pauses the
    // round.
    readonly property int roundLength: 45000
    readonly property int tick: 50
    property int elapsed: 0

    // How long a mole stays up (shrinking with the score), how long a hole
    // rests afterwards, and how many can be up at once.
    readonly property int stay: Math.max(450, 1100 - root.score * 20)
    readonly property int rest: 300
    readonly property int maxUp: 2
    property int spawnGap: 600

    // Per hole: whether the mole is up and the tick it drops at, or while down,
    // the tick the hole becomes available again.
    property var up: []
    property var until: []

    // The hole last missed and the ticks left on its flash, which is also the
    // window in which further misses are ignored.
    property int missHole: -1
    property int missLeft: 0
    readonly property int stun: 300
    readonly property int penalty: 2000

    focus: true

    Component.onCompleted: root.restart()

    function put(hole: int, raised: bool, when: int): void {
        const up = root.up.slice()
        const until = root.until.slice()
        up[hole] = raised
        until[hole] = when
        root.up = up
        root.until = until
    }

    function spawn(): void {
        if (root.up.filter(raised => raised).length < root.maxUp) {
            const free = []
            for (let hole = 0; hole < root.holes; hole++)
                if (!root.up[hole] && root.until[hole] <= root.elapsed)
                    free.push(hole)
            if (free.length > 0)
                root.put(free[Math.floor(Math.random() * free.length)], true,
                         root.elapsed + root.stay)
        }
        // Randomised gap before the next mole.
        root.spawnGap = Math.round(root.stay * (0.4 + Math.random() * 0.5))
    }

    // Takes two seconds off the clock without shortening the moles: every
    // hole's timing shifts with it.
    function miss(hole: int): void {
        if (root.over || root.missLeft > 0)
            return
        root.missHole = hole
        root.missLeft = root.stun
        root.elapsed = Math.min(root.roundLength, root.elapsed + root.penalty)
        root.until = root.until.map(when => when + root.penalty)
    }

    function whack(hole: int): void {
        if (root.over)
            return
        if (!root.up[hole]) {
            root.miss(hole)
            return
        }
        root.score += 1
        root.put(hole, false, root.elapsed + root.rest)
    }

    function step(): void {
        root.elapsed += root.tick
        if (root.missLeft > 0)
            root.missLeft = Math.max(0, root.missLeft - root.tick)
        const dropped = root.up.map((raised, hole) => raised && root.until[hole] <= root.elapsed)
        if (dropped.some(fell => fell)) {
            root.up = root.up.map((raised, hole) => raised && !dropped[hole])
            root.until = root.until.map((when, hole) => dropped[hole] ? root.elapsed + root.rest : when)
        }
        if (root.elapsed >= root.roundLength) {
            root.up = Array(root.holes).fill(false)
            root.over = true
            root.finished(root.score)
        }
    }

    Timer {
        interval: root.spawnGap
        repeat: true
        running: !root.over && root.visible
        onTriggered: root.spawn()
    }

    Timer {
        interval: root.tick
        repeat: true
        running: !root.over && root.visible
        onTriggered: root.step()
    }

    Keys.onPressed: event => {
        if (event.key < Qt.Key_1 || event.key > Qt.Key_9)
            return
        root.whack(event.key - Qt.Key_1)
        event.accepted = true
    }

    // ── GROUND ──────────────────────────────────────────────────────────────

    Rectangle {
        id: ground

        anchors.centerIn: parent
        width: root.cell * root.columns
        height: root.cell * root.rows
        radius: Theme.radiusMedium
        color: Theme.islandSurface
        border.color: Theme.islandBorder
        border.width: 1

        // Time left, draining from the right.
        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: Theme.radiusMedium
            }
            height: Math.max(2, Math.round(root.cell * 0.03))
            radius: height / 2
            color: Theme.islandBorder

            // Animated, so a miss's two seconds visibly drain rather than jump.
            Rectangle {
                width: parent.width * Math.max(0, 1 - root.elapsed / root.roundLength)
                height: parent.height
                radius: height / 2
                color: root.tint

                Behavior on width {
                    NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
                }
            }
        }

        Repeater {
            model: root.holes

            Item {
                id: hole

                required property int index

                readonly property bool raised: root.up[hole.index] === true

                x: (hole.index % root.columns) * root.cell
                y: Math.floor(hole.index / root.columns) * root.cell
                width: root.cell
                height: root.cell

                // The pit, low in its square so the mole has room above it.
                Rectangle {
                    id: pit

                    x: Math.round((root.cell - width) / 2)
                    y: root.cell - Math.round(root.cell * 0.14) - height
                    width: Math.round(root.cell * 0.72)
                    height: Math.round(root.cell * 0.26)
                    radius: height / 2
                    // Red while a miss on it is flashing.
                    color: hole.index === root.missHole && root.missLeft > 0
                        ? Theme.red : Theme.island
                    border.color: Theme.islandBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                // Clips the mole at the pit's midline so a dropped mole
                // disappears into it.
                Item {
                    id: well

                    width: root.cell
                    height: pit.y + Math.round(pit.height / 2)
                    clip: true

                    Rectangle {
                        id: mole

                        x: Math.round((root.cell - width) / 2)
                        y: hole.raised
                            ? well.height - height + Math.round(width * 0.3)
                            : well.height
                        width: Math.round(root.cell * 0.46)
                        height: Math.round(root.cell * 0.6)
                        radius: width / 2
                        color: root.tint

                        Behavior on y {
                            NumberAnimation {
                                duration: Theme.durationFast
                                easing.type: Theme.easing
                            }
                        }

                        Repeater {
                            model: 2

                            Rectangle {
                                id: eye

                                required property int index

                                x: Math.round(mole.width * (eye.index === 0 ? 0.32 : 0.68) - width / 2)
                                y: Math.round(mole.width * 0.36 - height / 2)
                                width: Math.round(mole.width * 0.16)
                                height: width
                                radius: width / 2
                                color: Theme.island
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: hole.raised ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPressed: root.whack(hole.index)
                }
            }
        }
    }
}
