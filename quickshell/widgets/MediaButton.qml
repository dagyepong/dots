import QtQuick
import qs.theme

Item {
    id: root

    property string kind: "play"      // play | pause | next | prev
    property bool highlighted: false
    signal clicked()

    implicitWidth: 30
    implicitHeight: 30

    // Semi-transparent background: works over the blurred cover
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b,
                       mouse.containsMouse ? 0.22 : (root.highlighted ? 0.14 : 0))
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    Canvas {
        id: cv

        anchors.centerIn: parent
        width: 10
        height: 10
        opacity: root.enabled ? 1 : 0.35

        property color fg: Theme.foreground
        property string shape: root.kind

        onFgChanged: requestPaint()
        onShapeChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = fg
            const w = width
            const h = height

            if (shape === "play") {
                ctx.beginPath()
                ctx.moveTo(w * 0.15, 0)
                ctx.lineTo(w * 0.15, h)
                ctx.lineTo(w, h / 2)
                ctx.closePath()
                ctx.fill()
            } else if (shape === "pause") {
                ctx.fillRect(w * 0.1, 0, w * 0.28, h)
                ctx.fillRect(w * 0.62, 0, w * 0.28, h)
            } else if (shape === "next") {
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(0, h)
                ctx.lineTo(w * 0.75, h / 2)
                ctx.closePath()
                ctx.fill()
                ctx.fillRect(w * 0.8, 0, w * 0.2, h)
            } else if (shape === "prev") {
                ctx.beginPath()
                ctx.moveTo(w, 0)
                ctx.lineTo(w, h)
                ctx.lineTo(w * 0.25, h / 2)
                ctx.closePath()
                ctx.fill()
                ctx.fillRect(0, 0, w * 0.2, h)
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
