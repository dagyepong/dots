import QtQuick
import "PadMath.js" as PM
import qs.modules.common

// The D-pad: a raised cross (128 x 128 design pixels, arms 48 wide) with a wall,
// soft-touch navy plastic with a dished middle. Left / right pick the band, up /
// down nudge it by 1 dB; hold to repeat. One canvas, painted once: the depth
// vector is fixed, so it is only redrawn if the render scale changes.
Item {
    id: pad

    property real u: 1
    property real kx: 0.30
    property real ky: 0.34
    property real renderScale: 1
    property int heldDir: 0          // 1 up, 2 right, 3 down, 4 left
    signal step(int dir)

    readonly property real arm: 128
    readonly property real thick: 48
    readonly property real stand: 16

    width: 220 * u
    height: 220 * u

    onKxChanged: art.requestPaint()
    onKyChanged: art.requestPaint()

    Canvas {
        id: art
        width: parent.width * pad.renderScale
        height: parent.height * pad.renderScale
        // painted at renderScale times its logical size, then shrunk back (smooth edges)
        scale: 1 / pad.renderScale
        transformOrigin: Item.TopLeft
        onCanvasSizeChanged: requestPaint()
        Component.onCompleted: requestPaint()
        Connections {
            target: PadPalette
            function onPChanged() { art.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var k = canvasSize.width / 220
            ctx.scale(k, k)
            var A = pad.arm, T = pad.thick
            var px = -pad.stand * pad.kx, py = -pad.stand * pad.ky

            function cross(dx, dy) {
                ctx.beginPath()
                PM.rr(ctx, 110 - A / 2 + dx, 110 - T / 2 + dy, A, T, 14)
                PM.rr(ctx, 110 - T / 2 + dx, 110 - A / 2 + dy, T, A, 14)
            }

            // soft shadow
            ctx.save()
            ctx.shadowColor = PM.alpha(PadPalette.deskShadow, 0.55)
            ctx.shadowBlur = 12
            ctx.shadowOffsetX = 5
            ctx.shadowOffsetY = 11
            cross(0, 0)
            ctx.fillStyle = PM.alpha(PadPalette.deskShadow, 0.5)
            ctx.fill()
            ctx.restore()

            // the socket
            cross(0, 1.5)
            ctx.lineJoin = "round"
            ctx.lineWidth = 12
            ctx.strokeStyle = PM.alpha(PadPalette.dpadGlow, 0.5)
            ctx.stroke()
            cross(0, 0)
            ctx.fillStyle = PM.css(PadPalette.dpadSocket)
            ctx.fill()
            ctx.strokeStyle = PM.css(PadPalette.dpadSocket)
            ctx.stroke()

            // the wall, back to front
            for (var j = pad.stand; j >= 1; j--) {
                cross(px + j * pad.kx, py + j * pad.ky)
                var t = j / pad.stand
                ctx.fillStyle = PM.mixCss(PadPalette.dpadWallLight, PadPalette.dpadWallDark, t)
                ctx.fill()
            }

            // the cap
            var g = ctx.createLinearGradient(40 + px, 40 + py, 180 + px, 180 + py)
            g.addColorStop(0, PM.css(PadPalette.keyHover))
            g.addColorStop(1, PM.css(PadPalette.keyBottom))
            cross(px, py)
            ctx.fillStyle = g
            ctx.fill()

            // the dish in the middle
            var cx = 110 + px, cy = 110 + py
            var dg = ctx.createRadialGradient(cx + 5, cy + 6, 1, cx, cy, 24)
            dg.addColorStop(0, PM.css(PadPalette.dishTop))
            dg.addColorStop(1, PM.css(PadPalette.dishBottom))
            ctx.beginPath()
            ctx.arc(cx, cy, 22, 0, Math.PI * 2)
            ctx.fillStyle = dg
            ctx.fill()
            ctx.beginPath()
            ctx.arc(cx, cy + 2, 21, Math.PI * 0.1, Math.PI * 0.9)
            ctx.lineWidth = 1.2
            ctx.strokeStyle = "rgba(255,255,255,0.18)"
            ctx.stroke()
        }
    }

    // arrows, printed on the cap
    Repeater {
        model: [
            { dir: 1, ax: 110, ay: 110 - 64 + 15, g: "▲" },
            { dir: 2, ax: 110 + 64 - 15, ay: 110, g: "▶" },
            { dir: 3, ax: 110, ay: 110 + 64 - 15, g: "▼" },
            { dir: 4, ax: 110 - 64 + 15, ay: 110, g: "◀" }
        ]
        Text {
            required property var modelData
            readonly property bool held: pad.heldDir === modelData.dir
            x: (modelData.ax - pad.stand * pad.kx) * pad.u - width / 2
            y: (modelData.ay - pad.stand * pad.ky) * pad.u - height / 2 + (held ? 1.5 * pad.u : 0)
            text: modelData.g
            color: held ? "#ffffff" : PadPalette.arrow
            opacity: held ? 1 : 0.85
            font.family: Theme.fontFamily
            font.pixelSize: 13 * pad.u
            font.weight: Font.Bold
        }
    }

    // the four arms
    Repeater {
        model: [
            { dir: 1, ax: 110 - 24, ay: 110 - 64, aw: 48, ah: 54 },
            { dir: 2, ax: 110 + 10, ay: 110 - 24, aw: 54, ah: 48 },
            { dir: 3, ax: 110 - 24, ay: 110 + 10, aw: 48, ah: 54 },
            { dir: 4, ax: 110 - 64, ay: 110 - 24, aw: 54, ah: 48 }
        ]
        MouseArea {
            required property var modelData
            x: (modelData.ax - pad.stand * pad.kx) * pad.u
            y: (modelData.ay - pad.stand * pad.ky) * pad.u
            width: modelData.aw * pad.u
            height: modelData.ah * pad.u
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                pad.heldDir = modelData.dir
                pad.step(modelData.dir)
                repeat.dir = modelData.dir
                repeat.interval = 380
                repeat.restart()
            }
            onReleased: {
                pad.heldDir = 0
                repeat.stop()
            }
            onCanceled: {
                pad.heldDir = 0
                repeat.stop()
            }
        }
    }

    Timer {
        id: repeat
        property int dir: 0
        repeat: true
        onTriggered: {
            interval = 70
            pad.step(dir)
        }
    }
}
