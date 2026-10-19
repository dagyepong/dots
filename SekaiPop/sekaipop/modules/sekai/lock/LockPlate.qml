import QtQuick
import qs.modules.common

// The shell's block, for the Calendar lockscreen (LockCalendar.qml): the three layers of
// Pill.qml -- a thick outline, a thin white ring inside it, then the colour -- standing
// on a hard shadow that drops straight down (never sideways, like the bar's pills).
// Pill.qml itself reads the bar's theme (Theme.qml, capsule bars, ...); the lockscreen
// has its own palette (LockPalette.qml), so this is the same construction in those
// colours. Anything declared inside lands on top of the colour, positioned from the
// inside of the ring.
//
// `pressed` sinks the plate onto its shadow, like a keycap. A plate has no mouse
// handling of its own: the caller puts a MouseArea over it and binds `pressed` to it.
// The plate is `width` x `height`; its shadow hangs `shadowDy` below that.
Item {
    id: root

    property color fillColor: LockPalette.paper
    // A second colour here makes the fill a top-to-bottom gradient, fillColor on top.
    property color fillBottom: "transparent"
    property color outlineColor: LockPalette.cBorder
    property color ringColor: LockPalette.paper
    property color shadowColor: LockPalette.cBorder

    // Whole device pixels, please (the caller passes px() values).
    property real outline: 3
    property real ring: 2
    property real shadowDy: 4
    property real cornerRadius: height / 2

    property bool pressed: false

    // Where the contents start, from the plate's edge.
    readonly property real inset: root.outline + root.ring
    readonly property bool hasGradient: root.fillBottom.a > 0

    default property alias content: face.data

    Gradient {
        id: fade

        GradientStop { position: 0; color: root.fillColor }
        GradientStop { position: 1; color: root.fillBottom }
    }

    // The hard shadow: fixed, it is what the plate either shows (raised) or covers (pressed).
    Rectangle {
        visible: root.shadowDy > 0
        y: root.shadowDy
        width: root.width
        height: root.height
        radius: root.cornerRadius
        color: root.shadowColor
        antialiasing: true
    }

    Item {
        id: cap
        width: root.width
        height: root.height
        y: root.pressed ? root.shadowDy : 0

        Behavior on y {
            NumberAnimation {
                duration: root.pressed ? 70 : 220
                easing.type: root.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: root.pressed ? 0 : 2.2
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            color: root.outlineColor
            antialiasing: true
        }

        Rectangle {
            x: root.outline
            y: root.outline
            width: Math.max(0, root.width - 2 * root.outline)
            height: Math.max(0, root.height - 2 * root.outline)
            radius: Math.max(0, root.cornerRadius - root.outline)
            color: root.ringColor
            antialiasing: true
        }

        Rectangle {
            id: face
            x: root.inset
            y: root.inset
            width: Math.max(0, root.width - 2 * root.inset)
            height: Math.max(0, root.height - 2 * root.inset)
            radius: Math.max(0, root.cornerRadius - root.inset)
            color: root.hasGradient ? "transparent" : root.fillColor
            gradient: root.hasGradient ? fade : null
            antialiasing: true
        }
    }
}
