import QtQuick
import "PadMath.js" as PM
import qs.modules.common

// A shoulder key on the top edge (214 x 46 design pixels): pearl plastic, with a
// thick wall, it sinks a little when pressed. Sits BEHIND the shell, so only the
// part above the edge shows.
Item {
    id: key

    property real u: 1
    property real kx: 0.30
    property real ky: 0.34
    property string label: ""
    property real thick: 10
    property real renderScale: 1
    signal clicked()

    readonly property bool down: area.pressed
    property real sink: key.down ? 4 : 0
    Behavior on sink {
        NumberAnimation { duration: 70 }
    }

    width: 214 * u
    height: 46 * u

    // The wall: 8 steps along the fixed depth vector, one small canvas (it was 8
    // rectangles). It repaints only while the key sinks (70 ms on a press).
    readonly property real wallR: 6
    readonly property real wallB: 10

    onSinkChanged: wall.requestPaint()

    Canvas {
        id: wall
        width: ((214 + key.wallR) * key.u) * key.renderScale
        height: ((46 + key.wallB) * key.u) * key.renderScale
        // painted at renderScale times its logical size, then shrunk back (smooth edges)
        scale: 1 / key.renderScale
        transformOrigin: Item.TopLeft
        onCanvasSizeChanged: requestPaint()
        Component.onCompleted: requestPaint()
        Connections {
            target: PadPalette
            function onPChanged() { wall.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var k = canvasSize.width / (214 + key.wallR)
            ctx.scale(k, k)
            var cA = PadPalette.pearlWallLight, cB = PadPalette.pearlWallDark
            for (var i = 0; i < 8; i++) {
                var hgt = (8 - i) * key.thick / 8
                ctx.beginPath()
                PM.rr(ctx, hgt * key.kx, hgt * key.ky + key.sink, 214, 46, 23)
                ctx.fillStyle = PM.mixCss(cA, cB, 1 - hgt / key.thick)
                ctx.fill()
            }
        }
    }

    Rectangle {
        id: face
        y: key.sink * key.u
        width: key.width
        height: key.height
        radius: height / 2
        antialiasing: true
        border.width: Math.max(1, key.u)
        border.color: PadPalette.alpha(PadPalette.pearlText, 0.3)
        gradient: Gradient {
            GradientStop { position: 0.0; color: PadPalette.pearl }
            GradientStop { position: 0.55; color: PadPalette.pearlMid }
            GradientStop { position: 1.0; color: PadPalette.pearlShade }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 2 * key.u
            width: parent.width - 2 * parent.radius * 0.55
            height: 2 * key.u
            radius: height / 2
            antialiasing: true
            color: "#ffffff"
            opacity: 0.9
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8 * key.u
            text: key.label
            color: PadPalette.pearlText
            font.family: Theme.fontFamily
            font.pixelSize: 10 * key.u
            font.weight: Font.Bold
            font.letterSpacing: 1.4 * key.u
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            antialiasing: true
            color: "#ffffff"
            opacity: area.containsMouse && !key.down ? 0.2 : 0
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: key.clicked()
    }
}
