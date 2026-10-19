import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.phone

// One notification card of the Quick Panel's list. The same card is used
// three ways (QuickPanelFace.qml decides which):
//
//   - a lone notification:       tap it for the app's own action (activated(); the
//                                panel dismisses it when the app has none), swipe
//                                or middle / right click it away (dismissed())
//   - the header of a group:     several notifications from one source
//                                collapse into this single card with a
//                                count pill and a chevron. Tap it to open
//                                or close the dropdown (toggled()); swipe
//                                or middle / right click it to clear the
//                                whole group (dismissed())
//   - a row inside the dropdown: a lone card again, a little narrower
//
// Pure UI (no Quickshell imports), like QuickPanelFace itself.
Item {
    id: card

    property var key
    property string app: ""
    property string title: ""
    property string body: ""
    property double time: 0
    property int urgency: 1
    property string icon: ""
    // "material:<name>" = a Material Symbols glyph instead of a picture.
    readonly property bool materialIcon: icon.startsWith("material:")
    // "now", "5m", "3h" — worked out by the face so it follows its clock.
    property string agoText: ""

    // More than 1: this card stands for a group of that many.
    property int groupCount: 1
    property bool expanded: false
    readonly property bool group: groupCount > 1

    // Where the card is while it is swiped or cleared, and how faded it is.
    // QuickPanelFace.qml binds the stack drawn behind a collapsed group to
    // these, so the gray under the card moves and fades with it instead of
    // staying behind.
    readonly property real slideX: slide.x
    readonly property real slideOpacity: slide.opacity

    // True while "Clear all" is sliding the cards out (no swiping then).
    property bool blocked: false
    property int clearIndex: 0
    property real cardWidth: 526

    signal dismissed()
    signal toggled()
    signal activated()

    // "Clear all": a purely cosmetic slide-out, staggered by position in
    // the list (capped at 5 so a long list still finishes quickly). The
    // real clear is one bulk call from the notifications card's own timer.
    function clearOut() {
        clearOutAnim.restart()
    }

    width: cardWidth
    height: 95.06

    readonly property bool pressed: cardArea.pressed && !cardArea.drag.active

    // Swipe left or right to dismiss (tap works too). Let go past
    // `swipeDistance` and it slides the rest of the way out and is
    // dismissed; let go short of it and it springs back.
    readonly property real swipeDistance: 130
    property bool leaving: false
    // True when the press that just ended was a swipe, so it isn't also
    // counted as a tap.
    property bool swiped: false

    NumberAnimation {
        id: settle
        target: slide
        property: "x"
        duration: 160
        easing.type: Easing.OutCubic
        onFinished: {
            if (card.leaving) {
                // Normally this card is gone right after the dismiss (the
                // list rebuilds without it). If the dismiss doesn't take,
                // bring it back rather than leave an invisible gap.
                restore.start()
                card.dismissed()
            }
        }
    }

    Timer {
        id: restore
        interval: 400
        onTriggered: {
            card.leaving = false
            slide.x = 0
        }
    }

    SequentialAnimation {
        id: clearOutAnim
        PauseAnimation { duration: Math.min(card.clearIndex, 5) * 35 }
        NumberAnimation {
            target: slide
            property: "x"
            to: -card.width
            duration: 140
            easing.type: Easing.InCubic
        }
    }

    // Everything visible on the card lives in here so it can slide as one
    // piece; the MouseArea below stays put and does the dragging.
    Item {
        id: slide
        width: card.width
        height: card.height
        // Fades as it leaves.
        opacity: 1 - Math.min(1, Math.abs(x) / (card.width * 0.75))

        // The card's slightly deeper edge tone, used by both the side
        // gradient and the bottom fade below. Derived from the card colour
        // itself, so the fades blend into the card.
        readonly property color edgeTone: Theme.classic ? Qt.color("#e9e9e9") : Qt.darker(Theme.pSurfaceHover, 1.12)

        Rectangle {
            anchors.fill: parent
            radius: 16.5
            color: Theme.pSurfaceHover
            opacity: card.pressed ? 0.7 : 1
            // A critical one gets the panel's outline.
            border.width: card.urgency === 2 ? 3 : 0
            border.color: Theme.pLine
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.pSurfaceHover }
                GradientStop { position: 0.72; color: Theme.pSurfaceHover }
                GradientStop { position: 1.0; color: slide.edgeTone }
            }
            antialiasing: true
        }

        // A soft settle toward the bottom of the card.
        Rectangle {
            anchors.fill: parent
            radius: 16.5
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(slide.edgeTone.r, slide.edgeTone.g, slide.edgeTone.b, 0) }
                GradientStop { position: 0.62; color: Qt.rgba(slide.edgeTone.r, slide.edgeTone.g, slide.edgeTone.b, 0) }
                GradientStop { position: 1.0; color: Qt.rgba(slide.edgeTone.r, slide.edgeTone.g, slide.edgeTone.b, 0.6) }
            }
            antialiasing: true
        }

        // The app's own icon (or the sender's picture), resolved already
        // in NotificationSource.qml. No icon at all -> a generic glyph.
        Item {
            x: 20
            width: 44
            height: 44
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                visible: !card.materialIcon
                anchors.fill: parent
                radius: width / 2
                color: Theme.pSurface
                antialiasing: true
            }

            // The shell's own notifications (a "material:<glyph>" icon:
            // screenshot, recording, timer ...) wear the attribute badge.
            ShellBadge {
                anchors.centerIn: parent
                size: 42
                visible: card.materialIcon
                glyph: card.materialIcon ? card.icon.substring(9) : ""
            }

            Image {
                anchors.centerIn: parent
                width: parent.width
                height: width
                visible: card.icon !== "" && !card.materialIcon
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                // Apps send 512 px+ icons / avatars; this circle is 44 px.
                sourceSize: Qt.size(Math.ceil(width * 3), Math.ceil(width * 3))
                source: card.materialIcon ? "" : card.icon
            }

            MaterialIcon {
                anchors.centerIn: parent
                size: parent.width - 6
                visible: card.icon === ""
                name: "apps"
            }
        }

        // App name, and — for a group — how many are inside it.
        Row {
            x: 76
            y: 8
            spacing: 8

            Text {
                id: appText
                width: Math.min(implicitWidth, card.cardWidth - 198 - (card.group ? 34 : 0))
                elide: Text.ElideRight
                text: card.app
                color: Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            Rectangle {
                visible: card.group
                height: 18
                width: Math.max(18, countText.implicitWidth + 12)
                radius: 9
                color: Theme.pLine
                antialiasing: true
                anchors.verticalCenter: appText.verticalCenter

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: card.groupCount > 9 ? "9+" : card.groupCount
                    color: "white"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.ExtraBold
                }
            }
        }

        Text {
            x: parent.width - 24 - width
            y: 9
            width: 70
            horizontalAlignment: Text.AlignRight
            text: card.agoText
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.Medium
        }

        Text {
            x: 76
            y: 26
            width: card.cardWidth - 100 - (card.group ? 36 : 0)
            elide: Text.ElideRight
            text: card.title
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        Text {
            x: 76
            y: 51
            width: card.cardWidth - 100 - (card.group ? 36 : 0)
            visible: card.body !== ""
            text: card.body
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeight: 0.92
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 15
        }

        // The dropdown chevron (groups only). Turns over when it's open.
        MaterialIcon {
            visible: card.group
            x: parent.width - 24 - width
            y: 46
            size: 28
            name: "expand_more"
            rotation: card.expanded ? 180 : 0
            Behavior on rotation {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    MouseArea {
        id: cardArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        enabled: !card.leaving && !card.blocked
        drag.target: slide
        drag.axis: Drag.XAxis
        drag.minimumX: -card.width
        drag.maximumX: card.width

        onPressed: {
            settle.stop()
            card.swiped = false
        }

        // drag.target moves `slide` straight from the pointer — no
        // Animation/Behavior runs during the swipe itself, so it needs its
        // own touch().
        onPositionChanged: if (drag.active) PanelActivity.touch()

        onReleased: {
            const dx = slide.x
            card.swiped = Math.abs(dx) > 4
            if (Math.abs(dx) >= card.swipeDistance) {
                card.leaving = true
                settle.duration = 140
                settle.to = dx > 0 ? card.width : -card.width
                settle.restart()
            } else if (dx !== 0) {
                settle.duration = 160
                settle.to = 0
                settle.restart()
            }
        }

        onClicked: mouse => {
            if (card.swiped)
                return
            if (mouse.button !== Qt.LeftButton)
                card.dismissed()
            else if (card.group)
                card.toggled()
            else
                card.activated()
        }
    }
}
