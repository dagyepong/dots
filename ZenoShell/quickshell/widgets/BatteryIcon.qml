import QtQuick
import qs.theme

Canvas {
    id: root

    property real percent: 1
    property bool charging: false
    property color outline: Theme.foreground
    property color fillColor: Theme.foreground

    width: 24
    height: 12

    // While charging the icon breathes (opacity only: no repaint)
    SequentialAnimation on opacity {
        id: breathe
        running: root.charging && root.visible
        loops: Animation.Infinite
        NumberAnimation { to: 0.5; duration: 1100; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 1100; easing.type: Easing.InOutSine }
        onRunningChanged: if (!running) root.opacity = 1
    }

    onPercentChanged: requestPaint()
    onChargingChanged: requestPaint()
    onOutlineChanged: requestPaint()
    onFillColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()

        const bw = width - 2.5

        ctx.strokeStyle = outline
        ctx.lineWidth = 1.3
        ctx.beginPath()
        ctx.roundedRect(0.65, 0.65, bw - 1.3, height - 1.3, 3, 3)
        ctx.stroke()

        ctx.fillStyle = outline
        ctx.fillRect(bw + 0.6, height * 0.32, 1.7, height * 0.36)

        const inner = bw - 5
        const p = Math.max(0, Math.min(1, percent))
        ctx.fillStyle = fillColor
        ctx.beginPath()
        ctx.roundedRect(2.5, 2.5, Math.max(1.5, inner * p), height - 5, 1.5, 1.5)
        ctx.fill()

        if (charging) {
            const cx = bw / 2
            const cy = height / 2
            ctx.fillStyle = p > 0.5 ? Theme.island : Theme.foreground
            ctx.beginPath()
            ctx.moveTo(cx + 0.8, 2)
            ctx.lineTo(cx - 2.6, cy + 0.6)
            ctx.lineTo(cx, cy + 0.6)
            ctx.lineTo(cx - 0.8, height - 2)
            ctx.lineTo(cx + 2.6, cy - 0.6)
            ctx.lineTo(cx, cy - 0.6)
            ctx.closePath()
            ctx.fill()
        }
    }
}
