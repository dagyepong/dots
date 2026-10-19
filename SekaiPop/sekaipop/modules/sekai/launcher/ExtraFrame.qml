import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// The paper-and-outline frame every launcher extras card sits in -- the
// same white face, navy outline and hard offset shadow as the results card
// under the search pill, with two strips of washi tape on top. Cards put
// their content inside it (it lands in `inner`, above the face) and it
// pops in when the card is created: a short fade + rise.
//
// The card's size is the frame's width/height; the shadow hangs outside it.
Item {
    id: root

    default property alias content: inner.data
    property real radius: 24
    property bool tape: true
    property color tapeLeft: ScrapbookTheme.tapeTeal
    property color tapeRight: ScrapbookTheme.tapeMint

    // 0 -> 1 when the card appears (see the animation below).
    property real appear: 0

    opacity: appear
    transform: Translate { y: (1 - root.appear) * 10 }

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

    // hard shadow
    Rectangle {
        x: Theme.shadowOffset
        y: Theme.shadowOffset
        width: root.width
        height: root.height
        radius: root.radius
        color: Theme.lineShadow
    }

    Rectangle {
        id: face
        anchors.fill: parent
        radius: root.radius
        color: Theme.colBg
        border.width: Theme.borderWidth
        border.color: Theme.line
        clip: true
        antialiasing: true

        // eats clicks on the card's own padding so they don't fall through
        // to the launcher's click-outside-to-close
        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: inner
            anchors.fill: parent
            anchors.margins: Theme.borderWidth
        }
    }

    WashiTape {
        visible: root.tape
        x: 30
        y: -12
        width: 68
        height: 22
        rotation: -6
        color: root.tapeLeft
    }
    WashiTape {
        visible: root.tape
        x: root.width - 30 - 68
        y: -12
        width: 68
        height: 22
        rotation: 5
        color: root.tapeRight
    }
}
