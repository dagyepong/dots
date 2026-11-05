import QtQuick
import qs.theme

// Circle that completes itself: name inside, small percentage below
Item {
    id: root

    property real value: 0               // 0..1
    property string label: ""
    property color tone: Theme.accent
    property real stroke: 9
    property int sweep: 600              // duration of the fill (ms)

    implicitWidth: 96
    implicitHeight: 96

    // "Soft" value: glides instead of jumping
    property real smooth: value
    Behavior on smooth { NumberAnimation { duration: root.sweep; easing.type: Easing.OutCubic } }

    readonly property color ringColor: smooth > 0.85 ? Theme.danger : tone

    onSmoothChanged: canvas.requestPaint()
    onRingColorChanged: canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const c = width / 2
            const r = c - root.stroke / 2 - 1

            ctx.lineWidth = root.stroke
            ctx.lineCap = "round"

            ctx.strokeStyle = Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
            ctx.beginPath()
            ctx.arc(c, c, r, 0, Math.PI * 2)
            ctx.stroke()

            if (root.smooth > 0.004) {
                ctx.strokeStyle = root.ringColor
                ctx.beginPath()
                ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, root.smooth))
                ctx.stroke()
            }
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 28
        spacing: 0

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.label
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.bold: true
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Math.round(root.value * 100) + "%"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }
}
