// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B O T S                                                                │
// │   five lanes · a click or the lane's digit, and the low ones pay double  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"

// Bot Bash: robots march down five lanes, faster as the score climbs. A click
// in a lane, or its digit, bashes the lowest robot in it: one point, two if it
// had reached the bottom third. Three robots reaching the floor end the round.
//
// A bash on an empty lane also costs a life, so mashing the digits doesn't
// work. Further misses are ignored for a third of a second after one, so a
// double tap counts once.
//
// One Canvas repainted at 30 fps; the robots are a plain array rebuilt each
// tick, since QML doesn't notice in-place mutation.
FocusScope {
    id: root

    // ── CONTRACT ────────────────────────────────────────────────────────────

    property int score: 0
    property bool over: false
    property color tint: Theme.accent

    signal finished(int score)

    function restart(): void {
        root.robots = []
        root.lives = 3
        root.score = 0
        root.ticks = 0
        root.missLane = -1
        root.missLeft = 0
        root.over = false
        board.requestPaint()
    }

    // ── BOARD ───────────────────────────────────────────────────────────────

    readonly property int lanes: 5
    readonly property int cell: Math.max(1, Math.floor(root.width / root.lanes))
    readonly property int drop: Math.max(1, Math.floor(root.height))
    readonly property int rate: 30

    // A robot's body size. Every `y` is a fraction of the drop: 0 at the top,
    // 1 at the floor.
    readonly property int body: Math.max(4, Math.round(root.cell * 0.5))
    readonly property real half: root.body / 2 / root.drop

    // Fractions of the drop per second, rising with the score and capped so a
    // crossing still takes nearly two seconds.
    readonly property real speed: Math.min(0.55, 0.16 + root.score * 0.006)

    // One object per robot: lane, body centre, and squash progress (0 while
    // standing).
    property var robots: []
    property int lives: 3
    property int ticks: 0

    // The lane last missed and the ticks left on its flash, which is also the
    // window in which further misses are ignored.
    property int missLane: -1
    property int missLeft: 0
    readonly property int stun: Math.round(root.rate * 0.3)

    focus: true

    Component.onCompleted: root.restart()

    // Only into a lane whose last robot has cleared the top; none if every lane
    // is taken.
    function spawn(): void {
        const clear = []
        for (let lane = 0; lane < root.lanes; lane++)
            if (!root.robots.some(robot => robot.lane === lane && robot.y < root.half * 3))
                clear.push(lane)
        if (clear.length === 0)
            return
        const lane = clear[Math.floor(Math.random() * clear.length)]
        root.robots = root.robots.concat([{ lane: lane, y: -root.half, squash: 0 }])
    }

    function miss(lane: int): void {
        if (root.over || root.missLeft > 0)
            return
        root.missLane = lane
        root.missLeft = root.stun
        root.lives -= 1
        if (root.lives === 0) {
            root.over = true
            root.finished(root.score)
        }
        board.requestPaint()
    }

    function bash(index: int): void {
        if (index < 0)
            return
        root.score += root.robots[index].y > 2 / 3 ? 2 : 1
        root.robots = root.robots.map((robot, at) =>
            at === index ? { lane: robot.lane, y: robot.y, squash: 0.001 } : robot)
        board.requestPaint()
    }

    // Bashes the lowest standing robot in the lane.
    function bashLane(lane: int): void {
        let lowest = -1
        root.robots.forEach((robot, index) => {
            if (robot.lane === lane && robot.squash === 0
                    && (lowest < 0 || robot.y > root.robots[lowest].y))
                lowest = index
        })
        if (lowest < 0)
            root.miss(lane)
        else
            root.bash(lowest)
    }

    function bashAt(x: real): void {
        root.bashLane(Math.max(0, Math.min(root.lanes - 1, Math.floor(x / root.cell))))
    }

    function step(): void {
        const dt = 1 / root.rate
        const kept = []
        let lost = 0
        for (const robot of root.robots) {
            if (robot.squash > 0) {
                const squash = robot.squash + dt / 0.16
                if (squash < 1)
                    kept.push({ lane: robot.lane, y: robot.y, squash: squash })
                continue
            }
            const y = robot.y + root.speed * dt
            if (y + root.half >= 1)
                lost += 1
            else
                kept.push({ lane: robot.lane, y: y, squash: 0 })
        }
        root.robots = kept
        root.ticks += 1
        if (root.missLeft > 0)
            root.missLeft -= 1
        if (lost > 0) {
            root.lives = Math.max(0, root.lives - lost)
            if (root.lives === 0) {
                root.over = true
                root.finished(root.score)
            }
        }
        board.requestPaint()
    }

    Timer {
        interval: Math.round(1000 / root.rate)
        repeat: true
        running: !root.over && root.visible
        onTriggered: root.step()
    }

    // Spawn interval shrinks in steps of five points: a Timer restarts when its
    // interval changes, so a smooth curve would keep delaying the next robot.
    Timer {
        interval: Math.max(380, 1100 - Math.floor(root.score / 5) * 50)
        repeat: true
        running: !root.over && root.visible
        onTriggered: root.spawn()
    }

    Keys.onPressed: event => {
        if (event.key < Qt.Key_1 || event.key > Qt.Key_5)
            return
        root.bashLane(event.key - Qt.Key_1)
        event.accepted = true
    }

    Rectangle {
        id: ground

        anchors.centerIn: parent
        width: root.cell * root.lanes
        height: root.drop
        radius: Theme.radiusMedium
        color: Theme.islandSurface
        border.color: Theme.islandBorder
        border.width: 1

        Canvas {
            id: board

            anchors.fill: parent

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const cell = root.cell
                const body = root.body
                const corner = Math.max(2, Math.round(body * 0.22))

                // Lanes, each with its digit underneath.
                ctx.strokeStyle = Theme.hairline
                ctx.lineWidth = 1
                ctx.fillStyle = Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.5)
                ctx.font = Theme.fontSizeSmall + "px '" + Theme.fontMono + "'"
                ctx.textAlign = "center"
                ctx.textBaseline = "bottom"
                for (let lane = 0; lane < root.lanes; lane++) {
                    if (lane > 0) {
                        ctx.beginPath()
                        ctx.moveTo(lane * cell + 0.5, 0)
                        ctx.lineTo(lane * cell + 0.5, height)
                        ctx.stroke()
                    }
                    ctx.fillText(String(lane + 1), lane * cell + cell / 2, height - cell * 0.1)
                }

                // A miss flashes its lane red.
                if (root.missLeft > 0 && root.missLane >= 0) {
                    ctx.fillStyle = Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b,
                                            0.28 * root.missLeft / root.stun)
                    ctx.fillRect(root.missLane * cell, 0, cell, height)
                }

                // Lives, top right, dimming from the right.
                const dot = Math.max(2, Math.round(cell * 0.04))
                const inset = Theme.radiusMedium
                for (let life = 0; life < 3; life++) {
                    const gone = life >= root.lives
                    ctx.fillStyle = Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, gone ? 0.22 : 1)
                    ctx.beginPath()
                    ctx.arc(width - inset - dot - (2 - life) * dot * 3, inset + dot, dot, 0, Math.PI * 2)
                    ctx.fill()
                }

                // Robots: body, two eyes and an antenna, with a slight sway. A
                // bashed one flattens and fades.
                for (const robot of root.robots) {
                    const alive = 1 - robot.squash
                    const paint = Qt.rgba(root.tint.r, root.tint.g, root.tint.b, alive)
                    const cx = robot.lane * cell + cell / 2
                        + Math.sin(root.ticks / 4 + robot.lane * 1.3) * body * 0.05 * alive
                    const feet = (robot.y + root.half) * root.drop
                    const w = body * (1 + robot.squash * 0.6)
                    const h = body * (1 - robot.squash * 0.85)
                    ctx.fillStyle = paint
                    if (robot.squash === 0) {
                        ctx.strokeStyle = paint
                        ctx.lineWidth = Math.max(1, Math.round(body * 0.06))
                        ctx.beginPath()
                        ctx.moveTo(cx, feet - h)
                        ctx.lineTo(cx, feet - h - body * 0.2)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.arc(cx, feet - h - body * 0.24, body * 0.07, 0, Math.PI * 2)
                        ctx.fill()
                    }
                    ctx.beginPath()
                    ctx.roundedRect(cx - w / 2, feet - h, w, h, corner, corner)
                    ctx.fill()
                    ctx.fillStyle = Qt.rgba(Theme.island.r, Theme.island.g, Theme.island.b, alive)
                    for (const side of [-1, 1]) {
                        ctx.beginPath()
                        ctx.arc(cx + side * w * 0.2, feet - h * 0.6, body * 0.09, 0, Math.PI * 2)
                        ctx.fill()
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onPressed: mouse => root.bashAt(mouse.x)
        }
    }
}
