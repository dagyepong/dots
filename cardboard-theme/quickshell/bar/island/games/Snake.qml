// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S N A K E                                                              │
// │   twenty by twenty · arrows or WASD, and the tail is the enemy           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"

// Snake, and the template for the other games: the contract first, state as
// plain properties, one timer that runs only during a round, and a Canvas for
// the board.
//
// Ten points per apple; each apple shortens the tick a little.
FocusScope {
    id: root

    // ── CONTRACT ────────────────────────────────────────────────────────────

    property int score: 0
    property bool over: false
    property color tint: Theme.accent

    signal finished(int score)

    function restart(): void {
        root.body = [{ x: 10, y: 10 }, { x: 9, y: 10 }, { x: 8, y: 10 }]
        root.dx = 1
        root.dy = 0
        root.queued = []
        root.score = 0
        root.eaten = 0
        root.over = false
        root.placeApple()
        board.requestPaint()
    }

    // ── BOARD ───────────────────────────────────────────────────────────────

    readonly property int columns: 20
    readonly property int rows: 20
    readonly property int cell: Math.max(1, Math.floor(
        Math.min(root.width / root.columns, root.height / root.rows)))

    // Head first.
    property var body: []
    property var apple: ({ x: 5, y: 5 })
    property int dx: 1
    property int dy: 0

    // Turns queued between ticks, so two quick presses both count and a
    // reversal is checked against the pending turn, not the current direction.
    property var queued: []
    property int eaten: 0

    focus: true

    Component.onCompleted: root.restart()

    function occupied(x: int, y: int): bool {
        return root.body.some(segment => segment.x === x && segment.y === y)
    }

    function placeApple(): void {
        const free = []
        for (let y = 0; y < root.rows; y++)
            for (let x = 0; x < root.columns; x++)
                if (!root.occupied(x, y))
                    free.push({ x: x, y: y })
        if (free.length === 0)
            return
        root.apple = free[Math.floor(Math.random() * free.length)]
    }

    function turn(nx: int, ny: int): void {
        const last = root.queued.length > 0
            ? root.queued[root.queued.length - 1] : { x: root.dx, y: root.dy }
        if ((nx === -last.x && ny === -last.y) || (nx === last.x && ny === last.y))
            return
        root.queued = root.queued.concat([{ x: nx, y: ny }])
    }

    function step(): void {
        if (root.queued.length > 0) {
            const next = root.queued[0]
            root.queued = root.queued.slice(1)
            root.dx = next.x
            root.dy = next.y
        }
        const head = root.body[0]
        const next = { x: head.x + root.dx, y: head.y + root.dy }
        const ate = next.x === root.apple.x && next.y === root.apple.y
        // The tail moves out of the way in the same tick unless the snake is
        // growing.
        const kept = ate ? root.body : root.body.slice(0, -1)
        const hitWall = next.x < 0 || next.y < 0
            || next.x >= root.columns || next.y >= root.rows
        if (hitWall || kept.some(segment => segment.x === next.x && segment.y === next.y)) {
            root.over = true
            root.finished(root.score)
            board.requestPaint()
            return
        }
        root.body = [next].concat(kept)
        if (ate) {
            root.eaten += 1
            root.score += 10
            root.placeApple()
        }
        board.requestPaint()
    }

    Timer {
        interval: Math.max(55, 130 - root.eaten * 3)
        repeat: true
        running: !root.over && root.visible
        onTriggered: root.step()
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Up:    case Qt.Key_W: root.turn(0, -1); break
        case Qt.Key_Down:  case Qt.Key_S: root.turn(0, 1);  break
        case Qt.Key_Left:  case Qt.Key_A: root.turn(-1, 0); break
        case Qt.Key_Right: case Qt.Key_D: root.turn(1, 0);  break
        default: return
        }
        event.accepted = true
    }

    Rectangle {
        id: ground

        anchors.centerIn: parent
        width: root.cell * root.columns
        height: root.cell * root.rows
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
                const size = root.cell
                const inset = Math.max(1, Math.round(size * 0.12))

                ctx.fillStyle = Theme.red
                ctx.beginPath()
                ctx.arc(root.apple.x * size + size / 2, root.apple.y * size + size / 2,
                        size / 2 - inset, 0, Math.PI * 2)
                ctx.fill()

                // The body is one stroke from centre to centre with round caps
                // and joins, so turns are elbows. It thins and darkens towards
                // the tail; the colour is mixed opaque rather than faded, since
                // overlapping translucent strokes would show seams at every
                // joint. Drawn tail first so the head sits on top.
                const count = root.body.length
                const centre = index => ({
                    x: root.body[index].x * size + size / 2,
                    y: root.body[index].y * size + size / 2
                })
                const girth = at => size * (0.78 - 0.38 * at)
                const paint = at => {
                    const ground = Theme.islandSurface
                    const mix = at * 0.5
                    return Qt.rgba(root.tint.r + (ground.r - root.tint.r) * mix,
                                   root.tint.g + (ground.g - root.tint.g) * mix,
                                   root.tint.b + (ground.b - root.tint.b) * mix, 1)
                }
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                for (let index = count - 2; index >= 0; index--) {
                    const at = index / Math.max(1, count - 1)
                    const from = centre(index + 1)
                    const to = centre(index)
                    ctx.strokeStyle = paint(at)
                    ctx.lineWidth = girth(at)
                    ctx.beginPath()
                    ctx.moveTo(from.x, from.y)
                    ctx.lineTo(to.x, to.y)
                    ctx.stroke()
                }

                // The head, slightly rounder, with two eyes facing the
                // direction of travel.
                if (count > 0) {
                    const head = centre(0)
                    ctx.fillStyle = paint(0)
                    ctx.beginPath()
                    ctx.arc(head.x, head.y, size * 0.44, 0, Math.PI * 2)
                    ctx.fill()
                    ctx.fillStyle = Theme.island
                    for (const side of [-1, 1]) {
                        const ex = head.x + root.dx * size * 0.16 - root.dy * side * size * 0.2
                        const ey = head.y + root.dy * size * 0.16 + root.dx * side * size * 0.2
                        ctx.beginPath()
                        ctx.arc(ex, ey, size * 0.08, 0, Math.PI * 2)
                        ctx.fill()
                    }
                }
            }
        }
    }
}
