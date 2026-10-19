import QtQuick
import "PadMath.js" as PM
import qs.modules.common

// The console's shell, drawn from its own pixels (design size 920 x 400; `u` is
// how big one pixel is here). It is ONE canvas, painted once (and again only when
// the render scale changes), flat 2D with the 2.5D look painted in:
//   - the shadow on the desk, a stack of soft translucent copies of the outline;
//   - the wall: the shell's thickness, as `steps` thin copies of its outline, each
//     one a step further along the fixed depth vector (kx, ky), shaded from the
//     lit rim down to the dark back;
//   - the face: satin teal plastic (lit from the top left), with its rim light,
//     the sheen, the cartridge slot, screws, the speaker grille and the pearl
//     line along the bottom.
// The depth vector no longer follows the pointer, so nothing here is re-laid-out
// or repainted while the popup is used: it was 34 + 12 rectangles moving on every
// pointer move and two canvases, now it is one texture.
Item {
    id: body

    property real u: 1
    property real kx: 0.30
    property real ky: 0.34
    property real renderScale: 1
    readonly property real bw: 920
    readonly property real bh: 400
    readonly property real depth: 40
    readonly property int steps: 20

    width: bw * u
    height: bh * u

    // Soft shadow on the desk: the footprint of the wall's far end (the body moved
    // along the whole depth vector), then `shadowLayers` translucent copies of it,
    // each one growing by an even step on every side, so it fades out evenly all
    // the way round. It never grows past `shadowSpread` design pixels beyond the
    // wall: the popup's window ends a little past the body (about 25 px on the
    // right and 17 px at the bottom beyond the wall), and what was drawn past that
    // was cut off in a straight line. Raise `shadowSpread` only together with the
    // popup's `marginR` / `marginB` in EqualizerPopup.qml.
    readonly property int shadowLayers: 12
    readonly property real shadowSpread: 9

    // Everything is painted in one canvas that reaches past the face to the far
    // end of the wall and the shadow: `cw` x `ch` design pixels.
    readonly property real cw: Math.ceil(bw + depth * kx + shadowSpread) + 1
    readonly property real ch: Math.ceil(bh + depth * ky + shadowSpread) + 1

    Canvas {
        id: face
        // The biggest canvas: painted on a worker thread, so opening the card
        // does not stall the GUI thread while it is drawn.
        renderStrategy: Canvas.Threaded
        width: (body.cw * body.u) * body.renderScale
        height: (body.ch * body.u) * body.renderScale
        // painted at renderScale times its logical size, then shrunk back (smooth edges)
        scale: 1 / body.renderScale
        transformOrigin: Item.TopLeft
        onCanvasSizeChanged: requestPaint()
        Component.onCompleted: requestPaint()

        // (the popup keeps the depth vector fixed; this only matters if it is ever changed)
        Connections {
            target: body
            function onKxChanged() { face.requestPaint() }
            function onKyChanged() { face.requestPaint() }
        }
        // a new theme (or new matugen colours): paint the shell again
        Connections {
            target: PadPalette
            function onPChanged() { face.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var k = canvasSize.width / body.cw
            ctx.scale(k, k)
            var W = body.bw, H = body.bh

            // the shadow on the desk, the biggest and faintest first
            ctx.fillStyle = PM.alpha(PadPalette.deskShadow, 0.045)
            for (var sl_i = 0; sl_i < body.shadowLayers; sl_i++) {
                var grow = body.shadowSpread * (body.shadowLayers - sl_i) / body.shadowLayers
                ctx.beginPath()
                PM.rr(ctx, body.depth * body.kx - grow, body.depth * body.ky - grow, W + grow * 2, H + grow * 2, 64 + grow)
                ctx.fill()
            }

            // the wall, back to front
            var wFar = PadPalette.wallFar, wNear = PadPalette.wallNear
            for (var j = body.steps; j >= 1; j--) {
                var hgt = j * body.depth / body.steps
                ctx.beginPath()
                PM.rr(ctx, hgt * body.kx, hgt * body.ky, W, H, 64)
                ctx.fillStyle = j === 1 ? PM.css(PadPalette.rim) : PM.mixCss(wFar, wNear, (j - 1) / (body.steps - 1))
                ctx.fill()
            }

            // the plastic
            var g = ctx.createLinearGradient(W * 0.08, 0, W * 0.92, H)
            g.addColorStop(0, PM.css(PadPalette.faceLight))
            g.addColorStop(0.36, PM.css(PadPalette.faceMid))
            g.addColorStop(1, PM.css(PadPalette.faceDark))
            ctx.beginPath()
            PM.rr(ctx, 0, 0, W, H, 64)
            ctx.fillStyle = g
            ctx.fill()

            ctx.save()
            ctx.beginPath()
            PM.rr(ctx, 0, 0, W, H, 64)
            ctx.clip()

            // the sheen, top left
            var sh = ctx.createLinearGradient(0, 0, 0, 170)
            sh.addColorStop(0, "rgba(255,255,255,0.42)")
            sh.addColorStop(1, "rgba(255,255,255,0)")
            ctx.save()
            ctx.translate(180, 70)
            ctx.rotate(-0.31)
            ctx.beginPath()
            ctx.ellipse(-300, -100, 600, 200)
            ctx.fillStyle = sh
            ctx.fill()
            ctx.restore()

            // shade along the bottom, light on the top rim
            var bs = ctx.createLinearGradient(0, H - 26, 0, H)
            bs.addColorStop(0, PM.alpha(PadPalette.shadeBottom, 0))
            bs.addColorStop(1, PM.alpha(PadPalette.shadeBottom, 0.42))
            ctx.fillStyle = bs
            ctx.fillRect(0, H - 26, W, 26)
            var tr = ctx.createLinearGradient(0, 0, 0, 14)
            tr.addColorStop(0, "rgba(255,255,255,0.85)")
            tr.addColorStop(1, "rgba(255,255,255,0)")
            ctx.fillStyle = tr
            ctx.fillRect(0, 0, W, 14)
            ctx.restore()

            ctx.beginPath()
            PM.rr(ctx, 0.5, 0.5, W - 1, H - 1, 64)
            ctx.lineWidth = 1
            ctx.strokeStyle = "rgba(255,255,255,0.3)"
            ctx.stroke()
            ctx.beginPath()
            PM.rr(ctx, -0.5, -0.5, W + 1, H + 1, 64)
            ctx.strokeStyle = PM.alpha(PadPalette.edgeDark, 0.45)
            ctx.stroke()

            // the cartridge slot
            var sl = ctx.createLinearGradient(0, 6, 0, 16)
            sl.addColorStop(0, PM.css(PadPalette.slotTop))
            sl.addColorStop(1, PM.css(PadPalette.slotBottom))
            ctx.beginPath()
            PM.rr(ctx, W / 2 - 70, 6, 140, 10, 5)
            ctx.fillStyle = sl
            ctx.fill()
            ctx.fillStyle = "rgba(255,255,255,0.5)"
            ctx.fillRect(W / 2 - 66, 16, 132, 1)

            // the pearl line
            var ln = ctx.createLinearGradient(90, 0, W - 90, 0)
            ln.addColorStop(0, PM.css(PadPalette.bass))
            ln.addColorStop(0.5, PM.css(PadPalette.lineMid))
            ln.addColorStop(1, PM.css(PadPalette.lineEnd))
            ctx.beginPath()
            PM.rr(ctx, 90, 386, W - 180, 4, 2)
            ctx.fillStyle = ln
            ctx.fill()

            // speaker grille (right; the left one is the MEDIA key)
            var gx = W - 126, gy = 334
            ctx.beginPath()
            PM.rr(ctx, gx, gy, 80, 30, 12)
            ctx.fillStyle = PM.alpha(PadPalette.grille, 0.18)
            ctx.fill()
            ctx.fillStyle = PM.alpha(PadPalette.grilleHole, 0.75)
            for (var ix = 0; ix < 10; ix++) {
                for (var iy = 0; iy < 4; iy++) {
                    ctx.beginPath()
                    ctx.arc(gx + 4 + ix * 8, gy + 4 + iy * 8, 1.7, 0, Math.PI * 2)
                    ctx.fill()
                }
            }

            // screws
            var sc = [[30, 32], [W - 30, 32], [36, 366], [W - 36, 366]]
            for (var s = 0; s < sc.length; s++) {
                var rg = ctx.createRadialGradient(sc[s][0] - 2, sc[s][1] - 2, 0.5, sc[s][0], sc[s][1], 7)
                rg.addColorStop(0, "#ffffff")
                rg.addColorStop(0.6, PM.css(PadPalette.screwLight))
                rg.addColorStop(1, PM.css(PadPalette.screwDark))
                ctx.beginPath()
                ctx.arc(sc[s][0], sc[s][1], 6, 0, Math.PI * 2)
                ctx.fillStyle = rg
                ctx.fill()
                ctx.strokeStyle = "rgba(60,80,100,0.75)"
                ctx.lineWidth = 1.4
                ctx.beginPath()
                ctx.moveTo(sc[s][0] - 3.5, sc[s][1])
                ctx.lineTo(sc[s][0] + 3.5, sc[s][1])
                ctx.moveTo(sc[s][0], sc[s][1] - 3.5)
                ctx.lineTo(sc[s][0], sc[s][1] + 3.5)
                ctx.stroke()
            }
        }
    }
}
