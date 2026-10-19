import QtQuick
import "PadMath.js" as PM
import qs.modules.common

// One of the four dome keys. A real button: it stands `lift` design pixels off
// the shell, with a wall you can see, and sinks to `pressedLift` while held (or
// while `latched`). Flat 2D with the 2.5D look painted in: the foot (socket,
// glow, wall) is one canvas drawn along the fixed depth vector, and the
// cap is a second one that slides up it.
Item {
    id: key

    property real u: 1
    property real kx: 0.30
    property real ky: 0.34
    property real renderScale: 1
    property real dd: 56                  // diameter, design pixels
    property color capColor: PadPalette.domeAuto
    property color wallColor: PadPalette.domeAutoWall
    property string glyph: ""
    property bool lit: false              // glowing (SAVE with something to save, AUTO on)
    property bool latched: false
    property real standing: 14
    property real pressedLift: 4
    property bool enabledKey: true

    signal clicked()

    readonly property bool down: area.pressed
    property real lift: (key.down || key.latched) ? key.pressedLift : key.standing
    Behavior on lift {
        NumberAnimation { duration: 70; easing.type: Easing.OutQuad }
    }

    width: dd * u
    height: dd * u
    opacity: key.enabledKey ? 1 : 0.55

    // The foot of the key, painted in ONE small canvas: the socket it sits in, the
    // glow while `lit`, and the wall from the shell up to the cap. There is no cast
    // shadow, the key sits flat on the shell. It repaints while the cap moves
    // (70 ms on a press) and when the key lights up, never otherwise.
    readonly property real footL: 20
    readonly property real footT: 20
    readonly property real footR: 20
    readonly property real footB: 32

    onLiftChanged: foot.requestPaint()
    onLitChanged: foot.requestPaint()
    onCapColorChanged: foot.requestPaint()
    onWallColorChanged: foot.requestPaint()
    onKxChanged: foot.requestPaint()
    onKyChanged: foot.requestPaint()

    Canvas {
        id: foot
        x: -key.footL * key.u
        y: -key.footT * key.u
        width: ((key.dd + key.footL + key.footR) * key.u) * key.renderScale
        height: ((key.dd + key.footT + key.footB) * key.u) * key.renderScale
        // painted at renderScale times its logical size, then shrunk back (smooth edges)
        scale: 1 / key.renderScale
        transformOrigin: Item.TopLeft
        onCanvasSizeChanged: requestPaint()
        Component.onCompleted: requestPaint()
        Connections {
            target: PadPalette
            function onPChanged() { foot.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var k = canvasSize.width / (key.dd + key.footL + key.footR)
            ctx.scale(k, k)
            ctx.translate(key.footL, key.footT)
            var d = key.dd, r = d / 2, lift = key.lift
            var TAU = Math.PI * 2

            // the socket it sits in
            var sg = ctx.createLinearGradient(0, -6, 0, d + 6)
            sg.addColorStop(0, PM.css(PadPalette.socketTop))
            sg.addColorStop(1, PM.css(PadPalette.socketBottom))
            ctx.beginPath()
            ctx.arc(r, r, r + 6 - 0.5, 0, TAU)
            ctx.fillStyle = sg
            ctx.fill()
            ctx.lineWidth = 1
            ctx.strokeStyle = PM.css(PadPalette.socketEdge)
            ctx.stroke()

            // glow
            if (key.lit) {
                var cc = key.capColor
                ctx.fillStyle = "rgba(" + Math.round(cc.r * 255) + "," + Math.round(cc.g * 255) + "," + Math.round(cc.b * 255) + ",0.13)"
                for (var gi = 0; gi < 3; gi++) {
                    ctx.beginPath()
                    ctx.arc(r - lift * key.kx, r - lift * key.ky, d / 2 + 3 + gi * 4, 0, TAU)
                    ctx.fill()
                }
            }

            // the wall: from the shell up to the cap
            var wDark = Qt.darker(key.wallColor, 2.1)
            for (var wi = 0; wi < 14; wi++) {
                var hgt = (wi + 1) * 2
                if (hgt > lift)
                    break
                ctx.beginPath()
                ctx.arc(r - hgt * key.kx, r - hgt * key.ky, r, 0, TAU)
                ctx.fillStyle = PM.mixCss(wDark, key.wallColor, Math.min(1, hgt / Math.max(1, key.standing)))
                ctx.fill()
            }
        }
    }

    // the cap
    Item {
        id: cap
        x: -key.lift * key.kx * key.u
        y: -key.lift * key.ky * key.u
        width: key.width
        height: key.height

        Canvas {
            width: parent.width * key.renderScale
            height: parent.height * key.renderScale
            // painted at renderScale times its logical size, then shrunk back (smooth edges)
            scale: 1 / key.renderScale
            transformOrigin: Item.TopLeft
            property color c1: key.capColor
            property color c2: key.wallColor
            onC1Changed: requestPaint()
            onC2Changed: requestPaint()
            onCanvasSizeChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var k = canvasSize.width / key.dd
                ctx.scale(k, k)
                var d = key.dd, r = d / 2
                var rg = ctx.createRadialGradient(r, r * 1.4, 1, r, r * 1.4, r * 1.3)
                rg.addColorStop(0, String(key.capColor))
                rg.addColorStop(1, String(key.wallColor))
                ctx.beginPath()
                ctx.arc(r, r, r - 0.5, 0, Math.PI * 2)
                ctx.fillStyle = rg
                ctx.fill()
                // underside shade
                var us = ctx.createLinearGradient(0, d * 0.55, 0, d)
                us.addColorStop(0, "rgba(0,0,0,0)")
                us.addColorStop(1, "rgba(0,0,0,0.30)")
                ctx.fillStyle = us
                ctx.fill()
                // specular
                var sp = ctx.createRadialGradient(d * 0.36, d * 0.24, 0.5, d * 0.36, d * 0.24, d * 0.42)
                sp.addColorStop(0, "rgba(255,255,255,0.92)")
                sp.addColorStop(1, "rgba(255,255,255,0)")
                ctx.fillStyle = sp
                ctx.fill()
                // rim
                ctx.beginPath()
                ctx.arc(r, r, r - 1.2, Math.PI * 1.05, Math.PI * 1.8)
                ctx.lineWidth = 1.6
                ctx.strokeStyle = "rgba(255,255,255,0.75)"
                ctx.stroke()
                ctx.beginPath()
                ctx.arc(r, r, r - 0.5, 0, Math.PI * 2)
                ctx.lineWidth = 1
                ctx.strokeStyle = "rgba(0,0,0,0.28)"
                ctx.stroke()
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -key.u
            text: key.glyph
            color: PadPalette.alpha(PadPalette.stageTop, 0.72)
            font.family: Theme.fontFamily
            font.pixelSize: 22 * key.u
            font.weight: Font.Bold
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            antialiasing: true
            color: "#ffffff"
            opacity: area.containsMouse && !key.down ? 0.14 : 0
            Behavior on opacity {
                NumberAnimation { duration: 90 }
            }
        }
    }

    MouseArea {
        id: area
        x: -key.lift * key.kx * key.u
        y: -key.lift * key.ky * key.u
        width: key.width
        height: key.height
        enabled: key.enabledKey
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: key.clicked()
    }
}
