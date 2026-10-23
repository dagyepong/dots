import QtQuick

// The figures' toy. Placed at the floor line; position from the state.
Item {
    id: ball
    required property var world
    visible: world.ballAlpha > 0.01
    opacity: world.ballAlpha
    // in someone's hands it sits between them, above his head
    readonly property var holder: world.ballHolder
    readonly property real bx: holder ? world.handsX(holder) : world.ballX
    readonly property real bh: holder ? world.holdHeight(holder) : world.ballH

    Rectangle {
        width: ball.world.ballR * 1.8 * (1 - Math.min(ball.bh, 80) / 160)
        height: 5; radius: 2.5
        x: ball.bx - width / 2; y: -2.5
        color: "black"
        opacity: 0.2
    }
    Rectangle {
        width: ball.world.ballR * 2; height: width; radius: width / 2
        x: ball.bx - ball.world.ballR
        y: -ball.bh - width
        rotation: ball.world.ballSpin
        color: ball.world.primary
        border.width: 1
        border.color: Qt.darker(ball.world.primary, 1.4)
        Text {
            anchors.centerIn: parent
            text: "₿"
            color: "white"
            font.pixelSize: parent.width * 0.68
            font.bold: true
        }
    }
}
