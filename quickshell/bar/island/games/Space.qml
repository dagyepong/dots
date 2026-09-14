// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S P A C E                                                              │
// │   five by four · left and right, space to fire, three lives              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"

// Space Blaster: a ship at the bottom and a formation of twenty invaders that
// sweeps sideways and steps down at each edge, speeding up as it thins. One
// Canvas repainted at 30 fps from state rebuilt each tick. At most three shots
// in flight, three lives, and a second of invulnerability after a hit.
//
// Ten points per invader, twenty for the front row; each wave is faster. The
// round ends when the lives run out or the formation reaches the ship's row.
FocusScope {
    id: root

    // ── CONTRACT ────────────────────────────────────────────────────────────

    property int score: 0
    property bool over: false
    property color tint: Theme.accent

    signal finished(int score)

    function restart(): void {
        root.score = 0
        root.lives = 3
        root.wave = 0
        root.shield = 0
        root.shipAt = 0.5
        root.leftHeld = false
        root.rightHeld = false
        root.stars = root.scatter()
        root.over = false
        root.spawnWave()
        board.requestPaint()
    }

    // ── BOARD ───────────────────────────────────────────────────────────────

    // Designed at 520×600 and scaled from the actual size: a column is a tenth
    // of the width, and everything else derives from it.
    readonly property int boardWidth: Math.floor(root.width)
    readonly property int boardHeight: Math.floor(root.height)
    readonly property int margin: 16

    readonly property int columns: 5
    readonly property int rows: 4
    readonly property int columnStride: Math.max(1, Math.floor(root.boardWidth / 10))
    readonly property int rowStride: Math.floor(root.columnStride * 0.85)
    readonly property int invaderSize: Math.floor(root.columnStride * 0.58)
    readonly property int formationTop: 64
    readonly property int dropStep: 18

    readonly property int shipWidth: Math.floor(root.columnStride * 0.7)
    readonly property int shipHeight: Math.floor(root.shipWidth * 0.6)
    readonly property int shipTop: root.boardHeight - 40 - root.shipHeight
    readonly property int shipSpeed: 7
    readonly property int shotLength: 10
    readonly property int shotSpeed: 11
    readonly property int bombSpeed: 5
    readonly property int shotsInFlight: 3
    readonly property int bombsInFlight: 3

    // ── STATE ───────────────────────────────────────────────────────────────

    // Surviving invaders as column and row within the formation; the
    // formation's position is one pair of numbers.
    property var invaders: []
    property real formX: 0
    property real formY: 0
    property int formDir: 1

    // Ours go up, theirs come down.
    property var shots: []
    property var bombs: []

    // Ship position as 0–1 rather than pixels, so it is centred before the
    // board has a size.
    property real shipAt: 0.5
    property int lives: 3
    property int wave: 0
    // Invulnerability ticks left after a hit; the ship blinks meanwhile.
    property int shield: 0

    property var stars: []
    property bool leftHeld: false
    property bool rightHeld: false

    readonly property int lane: Math.max(1, root.boardWidth - 2 * root.margin - root.shipWidth)
    readonly property real shipX: root.margin + root.shipWidth / 2 + root.shipAt * root.lane

    // Formation speed per tick: a base that rises with the wave, multiplied as
    // the formation thins.
    readonly property real pace: {
        const thinned = 1 - root.invaders.length / (root.columns * root.rows)
        return Math.min(10, (1.8 + 0.5 * root.wave) * (1 + 2 * thinned))
    }
    readonly property real bombChance: 0.02 + 0.006 * root.wave

    focus: true

    Component.onCompleted: root.restart()

    // Release held keys when focus leaves, or they would stay down.
    onActiveFocusChanged: {
        if (!root.activeFocus) {
            root.leftHeld = false
            root.rightHeld = false
        }
    }

    function scatter(): var {
        const sky = []
        for (let index = 0; index < 48; index++)
            sky.push({ x: Math.random(), y: Math.random(), r: 1 + Math.random() })
        return sky
    }

    function spawnWave(): void {
        const formation = []
        for (let r = 0; r < root.rows; r++)
            for (let c = 0; c < root.columns; c++)
                formation.push({ c: c, r: r })
        root.invaders = formation
        root.formX = root.margin
        root.formY = root.formationTop
        root.formDir = 1
        root.shots = []
        root.bombs = []
    }

    function invaderX(invader: var): real {
        return root.formX + invader.c * root.columnStride
    }

    function invaderY(invader: var): real {
        return root.formY + invader.r * root.rowStride
    }

    function fire(): void {
        if (root.over || root.shots.length >= root.shotsInFlight)
            return
        root.shots = root.shots.concat([{ x: root.shipX, y: root.shipTop - root.shotLength }])
    }

    // Bombs drop from the lowest invader of a random column, so none fires
    // through its own front row.
    function dropBomb(): void {
        const pick = root.invaders[Math.floor(Math.random() * root.invaders.length)]
        const lowest = root.invaders
            .filter(invader => invader.c === pick.c)
            .reduce((a, b) => b.r > a.r ? b : a)
        root.bombs = root.bombs.concat([{
            x: root.invaderX(lowest) + root.invaderSize / 2,
            y: root.invaderY(lowest) + root.invaderSize
        }])
    }

    function end(): void {
        root.over = true
        root.finished(root.score)
        board.requestPaint()
    }

    function step(): void {
        // Ship.
        const heading = (root.rightHeld ? 1 : 0) - (root.leftHeld ? 1 : 0)
        root.shipAt = Math.max(0, Math.min(1, root.shipAt + heading * root.shipSpeed / root.lane))
        if (root.shield > 0)
            root.shield -= 1

        // Our shots, and hits.
        const size = root.invaderSize
        let standing = root.invaders
        const flying = []
        for (const shot of root.shots) {
            const y = shot.y - root.shotSpeed
            if (y + root.shotLength < 0)
                continue
            const hit = standing.findIndex(invader =>
                shot.x >= root.invaderX(invader) && shot.x <= root.invaderX(invader) + size
                && y <= root.invaderY(invader) + size && y + root.shotLength >= root.invaderY(invader))
            if (hit === -1) {
                flying.push({ x: shot.x, y: y })
                continue
            }
            root.score += standing[hit].r === root.rows - 1 ? 20 : 10
            standing = standing.filter((invader, index) => index !== hit)
        }
        root.shots = flying
        root.invaders = standing
        if (standing.length === 0) {
            root.wave += 1
            root.spawnWave()
            board.requestPaint()
            return
        }

        // Formation: sideways, stepping down when its own edge (not the grid's)
        // reaches a side.
        const cs = standing.map(invader => invader.c)
        const minC = Math.min(...cs)
        const maxC = Math.max(...cs)
        let x = root.formX + root.formDir * root.pace
        let y = root.formY
        const leftEdge = x + minC * root.columnStride
        const rightEdge = x + maxC * root.columnStride + size
        if (leftEdge < root.margin || rightEdge > root.boardWidth - root.margin) {
            x = leftEdge < root.margin
                ? root.margin - minC * root.columnStride
                : root.boardWidth - root.margin - size - maxC * root.columnStride
            y += root.dropStep
            root.formDir = -root.formDir
        }
        root.formX = x
        root.formY = y
        const maxR = Math.max(...standing.map(invader => invader.r))
        if (y + maxR * root.rowStride + size >= root.shipTop) {
            root.end()
            return
        }

        // Bombs, and hits. The shield makes the ship unhittable.
        const falling = []
        let struck = false
        for (const bomb of root.bombs) {
            const by = bomb.y + root.bombSpeed
            if (by > root.boardHeight)
                continue
            const onShip = root.shield === 0 && !struck
                && Math.abs(bomb.x - root.shipX) <= root.shipWidth / 2
                && by + root.shotLength >= root.shipTop && by <= root.shipTop + root.shipHeight
            if (onShip) {
                struck = true
                continue
            }
            falling.push({ x: bomb.x, y: by })
        }
        root.bombs = falling
        if (struck) {
            root.lives -= 1
            root.shield = 30
            if (root.lives === 0) {
                root.end()
                return
            }
        }
        if (root.bombs.length < root.bombsInFlight && Math.random() < root.bombChance)
            root.dropBomb()
        board.requestPaint()
    }

    Timer {
        interval: 33
        repeat: true
        running: !root.over && root.visible
        onTriggered: root.step()
    }

    // Left and right are held, not tapped: the tick reads them. Auto-repeat is
    // ignored; only a real release clears them.
    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:  case Qt.Key_A: root.leftHeld = true; break
        case Qt.Key_Right: case Qt.Key_D: root.rightHeld = true; break
        case Qt.Key_Space: if (!event.isAutoRepeat) root.fire(); break
        default: return
        }
        event.accepted = true
    }

    Keys.onReleased: event => {
        switch (event.key) {
        case Qt.Key_Left:  case Qt.Key_A: if (!event.isAutoRepeat) root.leftHeld = false; break
        case Qt.Key_Right: case Qt.Key_D: if (!event.isAutoRepeat) root.rightHeld = false; break
        case Qt.Key_Space: break
        default: return
        }
        event.accepted = true
    }

    Rectangle {
        id: ground

        anchors.centerIn: parent
        width: root.boardWidth
        height: root.boardHeight
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
                const size = root.invaderSize

                // Stars.
                ctx.fillStyle = Theme.hairline
                for (const star of root.stars) {
                    ctx.beginPath()
                    ctx.arc(star.x * width, star.y * height, star.r, 0, Math.PI * 2)
                    ctx.fill()
                }

                // The formation: front row yellow, the rest muted, with two
                // eyes cut out.
                const corner = Math.round(size * 0.3)
                const eye = Math.max(2, Math.round(size * 0.14))
                for (const invader of root.invaders) {
                    const x = root.invaderX(invader)
                    const y = root.invaderY(invader)
                    ctx.fillStyle = invader.r === root.rows - 1 ? Theme.yellow : Theme.textMuted
                    ctx.beginPath()
                    ctx.roundedRect(x, y, size, size, corner, corner)
                    ctx.fill()
                    ctx.fillStyle = Theme.islandSurface
                    ctx.fillRect(x + size * 0.26 - eye / 2, y + size * 0.36, eye, eye)
                    ctx.fillRect(x + size * 0.74 - eye / 2, y + size * 0.36, eye, eye)
                }

                // Shots up, bombs down.
                ctx.fillStyle = root.tint
                for (const shot of root.shots)
                    ctx.fillRect(shot.x - 1, shot.y, 2, root.shotLength)
                ctx.fillStyle = Theme.red
                for (const bomb of root.bombs)
                    ctx.fillRect(bomb.x - 1, bomb.y, 2, root.shotLength)

                // The ship skips frames while invulnerable.
                if (Math.floor(root.shield / 3) % 2 === 0) {
                    ctx.fillStyle = root.tint
                    ctx.beginPath()
                    ctx.moveTo(root.shipX, root.shipTop)
                    ctx.lineTo(root.shipX + root.shipWidth / 2, root.shipTop + root.shipHeight)
                    ctx.lineTo(root.shipX - root.shipWidth / 2, root.shipTop + root.shipHeight)
                    ctx.closePath()
                    ctx.fill()
                }

                // Lives, top right, dimming as they go.
                const dot = 5
                for (let index = 0; index < 3; index++) {
                    const kept = index < root.lives
                    ctx.fillStyle = Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, kept ? 1 : 0.25)
                    ctx.beginPath()
                    ctx.arc(width - root.margin - dot - index * (dot * 2 + 6),
                            root.margin + dot, dot, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }
    }
}
