import QtQuick
import qs.modules.common

// A diamond icon button, the Settings Panel's small round key turned on its
// corner: the close button and the − / + of its steppers. Same behaviour as
// the Quick Panel's keys: hover lights it up with the accent gradient, it
// pushes into its hard shadow on press and springs back on release.
//
// `size` is the diamond's width across its points. `autoRepeat` makes
// holding it repeat clicked(), for the steppers.
Item {
    id: root

    property string icon: ""
    property real size: 50
    property bool on: false
    property bool autoRepeat: false

    signal clicked()

    readonly property bool hovered: area.containsMouse
    readonly property bool lit: on || hovered

    property real litP: lit ? 1 : 0
    Behavior on litP {
        NumberAnimation {
            duration: 170
            easing.type: Easing.OutCubic
        }
    }

    readonly property color inkNow: Qt.tint(Theme.pInk, Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, litP))

    // The side of the square that, turned 45 degrees, is `size` across.
    readonly property real side: size * 0.7
    readonly property real shadowDx: 3 + 2 * litP
    readonly property real shadowDy: 3 + 1 * litP

    implicitWidth: size + 5
    implicitHeight: size + 5

    Rectangle {
        x: (root.size - root.side) / 2 + root.shadowDx
        y: (root.size - root.side) / 2 + root.shadowDy
        width: root.side
        height: root.side
        radius: root.side * 0.3
        rotation: 45
        color: Theme.pLineShadow
        antialiasing: true
    }

    Item {
        id: cap

        width: root.size
        height: root.size
        x: area.pressed ? root.shadowDx : 0
        y: area.pressed ? root.shadowDy : 0

        Behavior on x {
            NumberAnimation {
                duration: area.pressed ? 80 : 260
                easing.type: area.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: area.pressed ? 0 : 2.2
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: area.pressed ? 80 : 260
                easing.type: area.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: area.pressed ? 0 : 2.2
            }
        }

        Rectangle {
            id: outline
            anchors.centerIn: parent
            width: root.side
            height: root.side
            radius: root.side * 0.3
            rotation: 45
            color: Theme.pRingWhite
            border.width: 3 + 1 * root.litP
            border.color: Theme.pLine
            antialiasing: true

            Rectangle {
                anchors.fill: parent
                anchors.margins: outline.border.width + 3 * root.litP
                radius: Math.max(0, outline.radius - anchors.margins)
                color: root.hovered && !root.on ? Theme.pSurfaceHover : Theme.pSurface
                antialiasing: true
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: outline.border.width + 3
                radius: Math.max(0, outline.radius - anchors.margins)
                opacity: root.litP
                antialiasing: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.accentMint }
                    GradientStop { position: 1.0; color: Theme.accentCyan }
                }
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            size: Math.round(root.size * 0.46)
            name: root.icon
            weight: 550
            color: root.inkNow
        }
    }

    // True once the hold has started repeating, so the release that ends the
    // hold isn't counted as one more click.
    property bool repeated: false

    Timer {
        id: repeatTimer
        interval: 380
        repeat: true
        onTriggered: {
            root.repeated = true
            interval = 70
            root.clicked()
        }
    }

    MouseArea {
        id: area
        x: 0
        y: 0
        width: root.size
        height: root.size
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            root.repeated = false
            if (root.autoRepeat) {
                repeatTimer.interval = 380
                repeatTimer.restart()
            }
        }
        onReleased: repeatTimer.stop()
        onCanceled: repeatTimer.stop()
        onClicked: {
            if (!root.repeated)
                root.clicked()
        }
    }
}
