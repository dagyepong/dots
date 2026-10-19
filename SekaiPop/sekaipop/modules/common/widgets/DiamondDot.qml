import QtQuick
import qs.modules.common

// One diamond of the beat: the clock widget's BeatDiamond, as a part the
// popups share. Off it is a pale, outlined square turned on its corner; lit
// it takes `litColor`. `pop` springs from big to normal when it lights (or
// whenever something calls `bump()`), like the clock's diamonds.
Rectangle {
    id: root

    property bool lit: false
    property color litColor: Theme.accentMint
    property color offColor: Theme.surfaceDivider
    property color lineColor: Theme.line
    property real size: 12
    property real pop: 1

    width: root.size
    height: root.size
    radius: Math.max(2, root.size * 0.25)
    rotation: 45
    scale: root.pop
    color: root.lit ? root.litColor : root.offColor
    border.width: 2
    border.color: root.lineColor
    antialiasing: true

    Behavior on color {
        ColorAnimation { duration: 140 }
    }

    onLitChanged: {
        if (root.lit)
            root.bump()
    }

    function bump() {
        bumpAnim.restart()
    }

    NumberAnimation {
        id: bumpAnim
        target: root
        property: "pop"
        from: 1.7
        to: 1
        duration: 360
        easing.type: Easing.OutBack
        easing.overshoot: 2.2
    }
}
