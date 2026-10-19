import QtQuick
import qs.modules.common

// A rounded plate in the phone's own look: the fill, the outline and the hard
// offset shadow the app tiles and the search pill have. It is what the phone
// versions of the Calc, Clip and Web cards are built from, so none of them
// needs a card of its own around it any more.
//
// The size is the whole plate, shadow included (like the app tiles): the face
// is `shadow` px smaller each way. Anything declared inside lands on the face.
// Colours come from the phone's tokens (Theme.p*), so a plate follows Light /
// Dark / Darker with everything else.
Item {
    id: root

    default property alias content: inner.data

    property real radius: 28
    property color fill: Theme.pSurface
    property Gradient fillGradient: null
    property real borderW: 3
    // How far the hard shadow reaches (right and down).
    property real shadow: 4
    property color line: Theme.pLine
    property color shadowColor: Theme.pLineShadow
    // Sinks the face onto its shadow (a pressed key).
    property bool pressed: false

    readonly property real faceW: width - shadow
    readonly property real faceH: height - shadow
    readonly property alias face: face

    Rectangle {
        x: root.shadow
        y: root.shadow
        width: root.faceW
        height: root.faceH
        radius: root.radius
        color: root.shadowColor
        antialiasing: true
    }

    Rectangle {
        id: face

        x: root.pressed ? root.shadow - 1 : 0
        y: root.pressed ? root.shadow - 1 : 0
        width: root.faceW
        height: root.faceH
        radius: root.radius
        color: root.fill
        gradient: root.fillGradient
        border.width: root.borderW
        border.color: root.line
        antialiasing: true

        Behavior on x {
            NumberAnimation {
                duration: 70
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: 70
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: inner
            anchors.fill: parent
        }
    }
}
