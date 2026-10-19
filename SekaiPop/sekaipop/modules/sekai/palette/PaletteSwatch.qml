import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/PaletteMath.js" as PM

// One colour of the strip: a tall card in that colour that lifts when the pointer is
// on it. Click copies its HEX (a "Copied" tick shows for a moment), right-click or the
// padlock keeps it through a shuffle / a new picture. The colour, and the label on it,
// glide to a new colour instead of snapping.
//
//   PaletteSwatch { hex: "#04feee"; locked: false; onCopyRequested: ...; onLockToggled: ... }
Item {
    id: root

    property string hex: "#000000"
    property bool locked: false
    // The smaller swatch the desktop widget uses (PaletteWidget.qml): shorter, a smaller
    // padlock and HEX. The tool keeps the big one.
    property bool compact: false
    // The smallest swatch, for the desktop widget's 2 x 2 size (PaletteWidget.qml): five of
    // them fit a 286 px row. Shorter again, a small padlock, HEX without the "#" in 10 px.
    property bool mini: false
    // true for a moment after a copy
    property bool copied: false

    signal copyRequested()
    signal lockToggled()

    readonly property bool hovered: mouse.containsMouse || lockMouse.containsMouse
    // The label's colour: dark ink or white, whichever reads on the swatch. It glides with
    // the fill, so it never flashes the wrong colour half way through a change.
    property color ink: PM.textOn(root.hex)

    readonly property real rest: 8
    readonly property real raised: 2
    readonly property real faceH: root.mini ? 72 : (root.compact ? 104 : 152)
    readonly property real corner: root.mini ? 12 : 16

    implicitWidth: root.mini ? 52 : (root.compact ? 72 : 124)
    implicitHeight: root.rest + root.faceH + 8

    Behavior on ink { ColorAnimation { duration: 340; easing.type: Easing.OutCubic } }

    function flashCopied() {
        root.copied = true
        copiedTimer.restart()
    }

    Timer {
        id: copiedTimer
        interval: 1000
        onTriggered: root.copied = false
    }

    // the hard shadow stays put while the face lifts off it
    Rectangle {
        y: root.rest + 4
        width: root.width
        height: root.faceH
        radius: root.corner
        color: Theme.lineShadow
        antialiasing: true
    }

    Rectangle {
        id: face
        y: mouse.pressed ? root.rest + 2 : (root.hovered ? root.raised : root.rest)
        width: root.width
        height: root.faceH
        radius: root.corner
        antialiasing: true
        color: root.hex
        border.width: 3
        border.color: Theme.line
        scale: mouse.pressed ? 0.98 : 1

        Behavior on color { ColorAnimation { duration: 340; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
        Behavior on scale { NumberAnimation { duration: 90 } }

        // the padlock: always there when locked, otherwise only while hovering
        Rectangle {
            id: lockBtn
            x: parent.width - width - (root.mini ? 4 : (root.compact ? 5 : 8))
            y: root.mini ? 4 : (root.compact ? 5 : 8)
            width: root.mini ? 20 : (root.compact ? 24 : 30)
            height: width
            radius: width / 2
            color: root.locked ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.22) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, lockMouse.containsMouse ? 0.18 : 0.08)
            opacity: (root.locked || root.hovered) ? 1 : 0
            antialiasing: true

            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on color { ColorAnimation { duration: 140 } }

            MaterialIcon {
                anchors.centerIn: parent
                name: root.locked ? "lock" : "lock_open"
                size: root.mini ? 12 : (root.compact ? 14 : 18)
                color: root.ink
            }

            MouseArea {
                id: lockMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.lockToggled()
            }
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: root.mini ? 6 : (root.compact ? 8 : 12)
            spacing: root.mini ? 1 : 2

            Text {
                width: parent.width
                text: root.mini ? root.hex.toUpperCase().replace("#", "") : root.hex.toUpperCase()
                color: root.ink
                font.family: Theme.fontFamily
                font.pixelSize: root.mini ? 10 : (root.compact ? 12 : 17)
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
                elide: Text.ElideRight
            }

            // swaps between the hint and the "Copied" confirmation
            Item {
                width: parent.width
                height: root.mini ? 13 : 16

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.locked ? "locked" : ((root.compact || root.mini) ? "copy" : "click to copy")
                    color: root.ink
                    opacity: root.copied ? 0 : (root.hovered || root.locked ? 0.8 : 0)
                    font.family: Theme.fontFamily
                    font.pixelSize: root.mini ? 9 : (root.compact ? 10 : 11)
                    font.weight: Font.Bold
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    opacity: root.copied ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    MaterialIcon { name: "check"; size: root.mini ? 10 : (root.compact ? 12 : 14); color: root.ink; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        // (the 2 x 2 swatch is too narrow for the word: the tick alone says it)
                        visible: !root.mini
                        text: "Copied"
                        color: root.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: root.mini ? 9 : (root.compact ? 10 : 11)
                        font.weight: Font.ExtraBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouse
        // a fixed area (not the face, which moves), so the lift can't make the pointer
        // fall off the edge and flicker
        x: 0
        y: root.raised
        width: root.width
        height: root.faceH + root.rest - root.raised
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.lockToggled()
            else
                root.copyRequested()
        }
    }
}
