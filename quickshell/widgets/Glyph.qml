import QtQuick
import qs.theme

// wifi | bluetooth | focus | game | lock | moon | volume | sun | power | logout | reboot
// play | pause | stop | flag | hourglass | stopwatch | star | gear | bell | grid | cpu | ram (level 0 = empty, otherwise filled)
Canvas {
    id: root

    property string kind: "wifi"
    property color color: Theme.foreground
    property int level: 3
    property real size: 16

    width: size
    height: size

    onColorChanged: requestPaint()
    onKindChanged: requestPaint()
    onLevelChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const s = width / 16
        ctx.scale(s, s)
        ctx.strokeStyle = color
        ctx.fillStyle = color
        ctx.lineWidth = 1.6
        ctx.lineCap = "round"
        ctx.lineJoin = "round"

        if (kind === "wifi") {
            for (let i = 1; i <= 3; i++) {
                ctx.globalAlpha = (i <= level) ? 1 : 0.25
                ctx.beginPath()
                ctx.arc(8, 13, i * 3.7, Math.PI * 1.25, Math.PI * 1.75)
                ctx.stroke()
            }
            ctx.globalAlpha = 1
            ctx.beginPath()
            ctx.arc(8, 13, 1.2, 0, Math.PI * 2)
            ctx.fill()
        } else if (kind === "bluetooth") {
            ctx.beginPath()
            ctx.moveTo(4, 5)
            ctx.lineTo(12, 11)
            ctx.lineTo(8, 14)
            ctx.lineTo(8, 2)
            ctx.lineTo(12, 5)
            ctx.lineTo(4, 11)
            ctx.stroke()
        } else if (kind === "focus") {
            ctx.beginPath()
            ctx.arc(8, 8, 6, 0, Math.PI * 2)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(5.5, 8)
            ctx.lineTo(10.5, 8)
            ctx.stroke()
        } else if (kind === "leaf") {
            ctx.beginPath()
            ctx.moveTo(3, 13)
            ctx.bezierCurveTo(3, 6, 7, 3, 13, 3)
            ctx.bezierCurveTo(13, 9, 10, 13, 3, 13)
            ctx.closePath()
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(3, 13)
            ctx.lineTo(8, 8)
            ctx.stroke()
        } else if (kind === "game") {
            ctx.strokeRect(1.5, 4.5, 11, 7)
            ctx.fillRect(13.5, 6.5, 1.5, 3)
            ctx.fillRect(3.5, 6.5, 4, 3)
        } else if (kind === "lock") {
            ctx.fillRect(3.5, 7.5, 9, 6.5)
            ctx.beginPath()
            ctx.arc(8, 7.5, 3, Math.PI, Math.PI * 2)
            ctx.stroke()
        } else if (kind === "moon") {
            ctx.beginPath()
            ctx.arc(8, 8, 6, 0, Math.PI * 2)
            ctx.fill()
            ctx.globalCompositeOperation = "destination-out"
            ctx.beginPath()
            ctx.arc(11, 6, 5, 0, Math.PI * 2)
            ctx.fill()
        } else if (kind === "volume") {
            ctx.beginPath()
            ctx.moveTo(2, 6)
            ctx.lineTo(5, 6)
            ctx.lineTo(9, 2.5)
            ctx.lineTo(9, 13.5)
            ctx.lineTo(5, 10)
            ctx.lineTo(2, 10)
            ctx.closePath()
            ctx.fill()
            if (level > 0) {
                ctx.beginPath()
                ctx.arc(9, 8, 3.5, -0.9, 0.9)
                ctx.stroke()
                if (level > 1) {
                    ctx.beginPath()
                    ctx.arc(9, 8, 6.2, -0.9, 0.9)
                    ctx.stroke()
                }
            } else {
                ctx.beginPath()
                ctx.moveTo(11, 5.5)
                ctx.lineTo(15, 10.5)
                ctx.moveTo(15, 5.5)
                ctx.lineTo(11, 10.5)
                ctx.stroke()
            }
        } else if (kind === "sun") {
            ctx.beginPath()
            ctx.arc(8, 8, 3, 0, Math.PI * 2)
            ctx.fill()
            for (let i = 0; i < 8; i++) {
                const a = i * Math.PI / 4
                ctx.beginPath()
                ctx.moveTo(8 + Math.cos(a) * 5, 8 + Math.sin(a) * 5)
                ctx.lineTo(8 + Math.cos(a) * 7, 8 + Math.sin(a) * 7)
                ctx.stroke()
            }
        } else if (kind === "power") {
            ctx.beginPath()
            ctx.arc(8, 8.5, 5.5, -Math.PI / 2 + 0.65, -Math.PI / 2 - 0.65 + Math.PI * 2)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(8, 2)
            ctx.lineTo(8, 8)
            ctx.stroke()
        } else if (kind === "logout") {
            ctx.beginPath()
            ctx.moveTo(7, 2.5)
            ctx.lineTo(3, 2.5)
            ctx.lineTo(3, 13.5)
            ctx.lineTo(7, 13.5)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(6.5, 8)
            ctx.lineTo(13, 8)
            ctx.moveTo(10.5, 5.2)
            ctx.lineTo(13.3, 8)
            ctx.lineTo(10.5, 10.8)
            ctx.stroke()
        } else if (kind === "area") {
            ctx.beginPath()
            ctx.moveTo(2, 6); ctx.lineTo(2, 2); ctx.lineTo(6, 2)
            ctx.moveTo(10, 2); ctx.lineTo(14, 2); ctx.lineTo(14, 6)
            ctx.moveTo(14, 10); ctx.lineTo(14, 14); ctx.lineTo(10, 14)
            ctx.moveTo(6, 14); ctx.lineTo(2, 14); ctx.lineTo(2, 10)
            ctx.stroke()
        } else if (kind === "window") {
            ctx.strokeRect(2, 3, 12, 10)
            ctx.beginPath()
            ctx.moveTo(2, 6.5)
            ctx.lineTo(14, 6.5)
            ctx.stroke()
        } else if (kind === "screen") {
            ctx.strokeRect(1.5, 2.5, 13, 8.5)
            ctx.beginPath()
            ctx.moveTo(8, 11); ctx.lineTo(8, 13.5)
            ctx.moveTo(5, 13.5); ctx.lineTo(11, 13.5)
            ctx.stroke()
        } else if (kind === "record") {
            ctx.beginPath()
            ctx.arc(8, 8, 6, 0, Math.PI * 2)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(8, 8, 3, 0, Math.PI * 2)
            ctx.fill()
        } else if (kind === "keyboard") {
            ctx.strokeRect(1.5, 3.5, 13, 9)
            ctx.fillRect(3.5, 5.5, 1.6, 1.6)
            ctx.fillRect(6.2, 5.5, 1.6, 1.6)
            ctx.fillRect(8.9, 5.5, 1.6, 1.6)
            ctx.fillRect(11.4, 5.5, 1.3, 1.6)
            ctx.fillRect(4.5, 9, 7, 1.6)
        } else if (kind === "clip") {
            ctx.strokeRect(3.5, 3, 9, 11)
            ctx.fillRect(6, 1.5, 4, 3)
        } else if (kind === "mic") {
            ctx.beginPath()
            ctx.roundedRect(5.5, 1.5, 5, 8, 2.5, 2.5)
            ctx.fill()
            ctx.beginPath()
            ctx.arc(8, 8, 4.8, 0, Math.PI, false)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(8, 12.8)
            ctx.lineTo(8, 14.5)
            ctx.moveTo(5.5, 14.5)
            ctx.lineTo(10.5, 14.5)
            ctx.stroke()
            if (level === 0) {
                ctx.beginPath()
                ctx.moveTo(3, 3)
                ctx.lineTo(13, 13)
                ctx.stroke()
            }
        } else if (kind === "play") {
            ctx.beginPath()
            ctx.moveTo(4.5, 2.5)
            ctx.lineTo(13, 8)
            ctx.lineTo(4.5, 13.5)
            ctx.closePath()
            ctx.fill()
        } else if (kind === "pause") {
            ctx.fillRect(4, 3, 3, 10)
            ctx.fillRect(9, 3, 3, 10)
        } else if (kind === "stop") {
            ctx.beginPath()
            ctx.roundedRect(3.5, 3.5, 9, 9, 2, 2)
            ctx.fill()
        } else if (kind === "flag") {
            ctx.beginPath()
            ctx.moveTo(4, 14)
            ctx.lineTo(4, 2)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(4, 2.5)
            ctx.lineTo(13, 5.5)
            ctx.lineTo(4, 8.5)
            ctx.closePath()
            ctx.fill()
        } else if (kind === "hourglass") {
            ctx.beginPath()
            ctx.moveTo(4, 2.5)
            ctx.lineTo(12, 2.5)
            ctx.lineTo(8, 8)
            ctx.lineTo(12, 13.5)
            ctx.lineTo(4, 13.5)
            ctx.lineTo(8, 8)
            ctx.closePath()
            ctx.stroke()
        } else if (kind === "stopwatch") {
            ctx.beginPath()
            ctx.arc(8, 9, 5.5, 0, Math.PI * 2)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(6.5, 1.8)
            ctx.lineTo(9.5, 1.8)
            ctx.moveTo(8, 9)
            ctx.lineTo(8, 5.8)
            ctx.stroke()
        } else if (kind === "star") {
            ctx.beginPath()
            for (let i = 0; i < 10; i++) {
                const r = (i % 2 === 0) ? 6.6 : 2.9
                const a = -Math.PI / 2 + i * Math.PI / 5
                const px = 8 + Math.cos(a) * r
                const py = 8.6 + Math.sin(a) * r
                if (i === 0) ctx.moveTo(px, py)
                else ctx.lineTo(px, py)
            }
            ctx.closePath()
            if (level > 0) ctx.fill()
            ctx.stroke()
        } else if (kind === "gear") {
            ctx.beginPath()
            ctx.arc(8, 8, 3.3, 0, Math.PI * 2)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(8, 8, 1.1, 0, Math.PI * 2)
            ctx.fill()
            for (let i = 0; i < 8; i++) {
                const a = i * Math.PI / 4
                ctx.beginPath()
                ctx.moveTo(8 + Math.cos(a) * 5.2, 8 + Math.sin(a) * 5.2)
                ctx.lineTo(8 + Math.cos(a) * 6.9, 8 + Math.sin(a) * 6.9)
                ctx.stroke()
            }
        } else if (kind === "bell") {
            ctx.beginPath()
            ctx.moveTo(3.4, 11.2)
            ctx.lineTo(4.5, 10)
            ctx.lineTo(4.5, 7)
            ctx.arc(8, 7, 3.5, Math.PI, 0, false)
            ctx.lineTo(11.5, 10)
            ctx.lineTo(12.6, 11.2)
            ctx.closePath()
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(8, 13.2, 1.1, 0, Math.PI * 2)
            ctx.fill()
        } else if (kind === "grid") {
            for (let r = 0; r < 2; r++) {
                for (let c = 0; c < 2; c++) {
                    ctx.beginPath()
                    ctx.roundedRect(2.6 + c * 5.8, 2.6 + r * 5.8, 4.8, 4.8, 1.4, 1.4)
                    ctx.fill()
                }
            }
        } else if (kind === "cpu") {
            ctx.beginPath()
            ctx.roundedRect(4, 4, 8, 8, 1.6, 1.6)
            ctx.stroke()
            for (let i = 0; i < 3; i++) {
                const t = 5.6 + i * 2.4
                ctx.beginPath()
                ctx.moveTo(t, 1.6); ctx.lineTo(t, 4)
                ctx.moveTo(t, 12); ctx.lineTo(t, 14.4)
                ctx.moveTo(1.6, t); ctx.lineTo(4, t)
                ctx.moveTo(12, t); ctx.lineTo(14.4, t)
                ctx.stroke()
            }
        } else if (kind === "ram") {
            ctx.beginPath()
            ctx.roundedRect(1.6, 4.6, 12.8, 6, 1.4, 1.4)
            ctx.stroke()
            ctx.fillRect(3.6, 6.4, 1.8, 2.4)
            ctx.fillRect(7.1, 6.4, 1.8, 2.4)
            ctx.fillRect(10.6, 6.4, 1.8, 2.4)
            ctx.beginPath()
            ctx.moveTo(4, 11); ctx.lineTo(4, 13)
            ctx.moveTo(8, 11); ctx.lineTo(8, 13)
            ctx.moveTo(12, 11); ctx.lineTo(12, 13)
            ctx.stroke()
        } else if (kind === "reboot") {
            ctx.beginPath()
            ctx.arc(8, 8, 5.2, -0.9, 4.6)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(9.8, 2.56)
            ctx.lineTo(7.17, 0.64)
            ctx.lineTo(7.67, 5.02)
            ctx.closePath()
            ctx.fill()
        }
    }
}
