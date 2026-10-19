import QtQuick

// The base of the phone versions of the launcher's cards (Calc, Clip, Emoji, Web).
// Unlike ExtraFrame (the white paper card with tape that Colour still uses) it
// has no frame at all: it is just the page, with the room the Apps
// screen gives it, and each card lays plates straight onto the phone's face.
//
// LauncherExtras.qml hands it the page's size (`pageW` x `pageH`, design
// units), so a card is laid out for the room it really has and is never shrunk.
// It comes in the way the old frame did: a short fade and rise.
Item {
    id: root

    property real pageW: 550
    property real pageH: 592

    width: pageW
    height: pageH

    // 0 -> 1 when the card appears.
    property real appear: 0

    opacity: appear
    transform: Translate { y: (1 - root.appear) * 12 }

    Component.onCompleted: appearAnim.start()

    NumberAnimation {
        id: appearAnim
        target: root
        property: "appear"
        from: 0
        to: 1
        duration: 200
        easing.type: Easing.OutCubic
    }
}
