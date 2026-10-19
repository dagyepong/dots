import QtQuick
import "PadMath.js" as PM
import qs.modules.common

// The volume wheel on the right edge (preamp, -12 .. +12 dB). Ribbed dark metal,
// shaded like a cylinder; the ribs scroll as the value changes. Drag it up or
// down (8 px = 1 dB), roll the mouse wheel over it, double click for 0.
Item {
    id: wheel

    property real u: 1
    property real kx: 0.30
    property real ky: 0.34
    property real renderScale: 1
    property real value: 0
    property real range: 12
    signal moved(real v)

    width: 32 * u
    height: 100 * u

    onValueChanged: art.requestPaint()

    // The wall (four steps along the fixed depth vector, up to 8 design px out) and
    // the face are one canvas, reaching `wallR` x `wallB` design px past the wheel.
    readonly property real wallR: 4
    readonly property real wallB: 4

    Canvas {
        id: art
        width: ((32 + wheel.wallR) * wheel.u) * wheel.renderScale
        height: ((100 + wheel.wallB) * wheel.u) * wheel.renderScale
        // painted at renderScale times its logical size, then shrunk back (smooth edges)
        scale: 1 / wheel.renderScale
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
            var k = canvasSize.width / (32 + wheel.wallR)
            ctx.scale(k, k)

            // the wall, far end last (the same order the stacked rectangles had)
            var wA = PadPalette.wheelWallLight, wB = PadPalette.wheelWallDark
            for (var wi = 0; wi < 4; wi++) {
                ctx.beginPath()
                PM.rr(ctx, (wi + 1) * 2 * wheel.kx, (wi + 1) * 2 * wheel.ky, 32, 100, 12)
                ctx.fillStyle = PM.mixCss(wA, wB, wi / 3)
                ctx.fill()
            }

            ctx.save()
            ctx.beginPath()
            PM.rr(ctx, 0, 0, 32, 100, 12)
            ctx.clip()
            ctx.fillStyle = PM.css(PadPalette.wheelBase)
            ctx.fillRect(0, 0, 32, 100)
            var off = (wheel.value * 5) % 6
            ctx.fillStyle = PM.css(PadPalette.wheelRib)
            for (var y = -6 + off; y < 106; y += 6)
                ctx.fillRect(0, y, 32, 3)
            // cylinder shading
            var sh = ctx.createLinearGradient(0, 0, 32, 0)
            sh.addColorStop(0, "rgba(0,0,0,0.5)")
            sh.addColorStop(0.42, "rgba(255,255,255,0.36)")
            sh.addColorStop(1, "rgba(0,0,0,0.55)")
            ctx.fillStyle = sh
            ctx.fillRect(0, 0, 32, 100)
            var ed = ctx.createLinearGradient(0, 0, 0, 100)
            ed.addColorStop(0, "rgba(0,0,0,0.5)")
            ed.addColorStop(0.15, "rgba(0,0,0,0)")
            ed.addColorStop(0.85, "rgba(0,0,0,0)")
            ed.addColorStop(1, "rgba(0,0,0,0.5)")
            ctx.fillStyle = ed
            ctx.fillRect(0, 0, 32, 100)
            ctx.restore()
            ctx.beginPath()
            PM.rr(ctx, 0.5, 0.5, 31, 99, 12)
            ctx.lineWidth = 1
            ctx.strokeStyle = "rgba(10,20,40,0.6)"
            ctx.stroke()
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.SizeVerCursor
        property real startY: 0
        property real startV: 0
        onPressed: mouse => {
            startY = mouse.y
            startV = wheel.value
        }
        onPositionChanged: mouse => {
            if (pressed)
                wheel.moved(startV + (startY - mouse.y) / (8 * wheel.u))
        }
        onDoubleClicked: wheel.moved(0)
        onWheel: w => wheel.moved(wheel.value + (w.angleDelta.y > 0 ? 1 : -1))
    }
}
