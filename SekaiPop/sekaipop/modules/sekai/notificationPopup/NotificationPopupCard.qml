import QtQuick
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/NotifyKinds.js" as NK

// One popup of the notification stack (NotificationPopup.qml). It is built
// the way the bar's popups are (SekaiPlate / Pill): a raised cap with the
// outline -> ring -> fill layers on a hard shadow, and three things that
// give it depth instead of a flat white card:
//
//   - a coloured plate on the left (the theme's two accent colours, pink
//     when the notification is critical) with a halftone in one corner,
//     two slanted bands of stage light and a slanted cut where it meets
//     the body;
//   - the app's icon (or the sender's picture) as a tilted sticker on
//     that plate: white, outlined, with its own small hard shadow. It
//     pops in as the card lands and wiggles when the pointer is on it;
//   - a soft top-to-bottom settle in the body, an app-name chip, a lit
//     diamond beside the time, and one light sweep across the card as it
//     arrives. Pressing it pushes the cap into its shadow like a key.
//
// Everything animated here is a one-shot (arrival, hover, press): nothing
// runs while a card just sits there, so an idle stack costs nothing.
//
// A notification whose icon is "material:<glyph>" is one the shell sent
// itself; it gets the attribute badge (ShellBadge.qml) in place of the white
// icon tile, and its plate takes the badge's colour.
//
// Pure UI: it only reports what you did.
//
//   click          activated()   the app's own click action (Discord: go to the
//                                message). The stack runs it; when the
//                                notification has none, the stack just hides the
//                                popup, as a click always did
//   middle click   closed()      hide the popup; the notification stays in the
//                                Quick Panel's list
//   right click    dismissed()   remove the notification altogether
//   swipe          dismissed()   the same, with the card following the pointer
//   pointer on it  hoverToggled  the stack stops its clock meanwhile
//
// `leaving` is set by the stack when the popup is over (timed out, closed,
// dismissed elsewhere): the card slides out and says finished(), and the
// stack then drops it. The roles below come straight from the stack's
// ListModel (NotificationSource's entry: key, app, title, body, urgency,
// icon; icon may be "material:<name>" for a Material Symbols glyph).
Item {
    id: card

    // MaterialIcon asks for this to use the panel's colours.
    readonly property bool classicPanel: true

    required property string key
    required property string app
    required property string title
    required property string body
    required property int urgency
    required property string icon
    required property bool leaving

    property real cardWidth: 420
    property real cardHeight: 104

    readonly property real shadowX: 5
    readonly property real shadowY: 4
    readonly property bool critical: card.urgency === 2
    readonly property bool materialIcon: card.icon.startsWith("material:")
    readonly property bool hasBody: card.body !== ""

    // The cap's outline and the ring just inside it; a critical card has the
    // thicker outline it always had.
    readonly property real outline: card.critical ? 5 : 3
    readonly property real ring: card.outline + 1
    readonly property real cornerRadius: 30
    // What is inside the ring: the area the plate and the text are laid out in.
    readonly property real faceW: card.cardWidth - 2 * card.ring
    readonly property real faceH: card.cardHeight - 2 * card.ring
    // How wide the coloured plate is (measured at its middle, its edge leans).
    readonly property real plateW: 100
    readonly property real textX: card.plateW + 20

    // A notification with a "material:<glyph>" icon is one the shell sent
    // itself (a screenshot, a recording, a timer ...): its icon is a ShellBadge
    // and the plate wears that badge's attribute colour.
    readonly property bool shell: card.materialIcon
    readonly property color kindColor: Theme.attributeColors[NK.index(card.icon.substring(9))]

    // The plate's colours: the theme's accents, the kind's colour for the
    // shell's own, or the panel's pink when critical.
    readonly property color plateTop: card.critical ? "#FFB3D1"
        : (card.shell ? Qt.lighter(card.kindColor, 1.05) : Theme.accentMint)
    readonly property color plateBottom: card.critical ? "#FF6F9C"
        : (card.shell ? Qt.darker(card.kindColor, 1.22) : Theme.accentCyan)
    readonly property color navy: Theme.colBorder
    readonly property color stickerShadow: Qt.rgba(card.navy.r, card.navy.g, card.navy.b, 0.5)

    signal closed()
    signal dismissed()
    signal activated()
    signal hoverToggled(bool hovering)
    signal finished()

    width: card.cardWidth + card.shadowX
    height: card.cardHeight + card.shadowY

    // 0 -> 1 as it arrives: slides in from the right while it fades up.
    property real enter: 0
    NumberAnimation on enter {
        from: 0
        to: 1
        duration: 260
        easing.type: Easing.OutCubic
    }

    // One-shots that start as the card lands: the sticker pops in, and a band
    // of light crosses the card once.
    property real stickerPop: 0.5
    property real shine: 0
    SequentialAnimation {
        running: true
        PauseAnimation { duration: 140 }
        NumberAnimation {
            target: card
            property: "stickerPop"
            to: 1
            duration: 420
            easing.type: Easing.OutBack
            easing.overshoot: 2.6
        }
    }
    SequentialAnimation {
        running: true
        PauseAnimation { duration: 220 }
        NumberAnimation {
            target: card
            property: "shine"
            from: 0
            to: 1
            duration: 620
            easing.type: Easing.InOutQuad
        }
    }

    // Let go of a swipe past this far and it is dismissed; short of it, it
    // springs back.
    readonly property real swipeDistance: 110
    property bool swipedOut: false
    // True when the press that just ended was a swipe, so it isn't also a click.
    property bool swiped: false
    readonly property bool pressed: area.pressed && !area.drag.active

    onLeavingChanged: {
        if (!card.leaving)
            return
        if (card.swipedOut)
            card.finished()
        else
            exit.restart()
    }

    SequentialAnimation {
        id: exit
        NumberAnimation {
            target: slide
            property: "x"
            to: card.width + 40
            duration: 200
            easing.type: Easing.InCubic
        }
        ScriptAction { script: card.finished() }
    }

    NumberAnimation {
        id: settle
        target: slide
        property: "x"
        duration: 160
        easing.type: Easing.OutCubic
        onFinished: {
            if (card.swipedOut) {
                // Normally the stack drops this card as the dismissal comes
                // back (leaving -> finished). If that doesn't happen, don't
                // leave an invisible card that eats clicks.
                stuck.restart()
                card.dismissed()
            }
        }
    }

    Timer {
        id: stuck
        interval: 900
        onTriggered: card.finished()
    }

    Item {
        id: arrive
        width: card.width
        height: card.height
        x: (1 - card.enter) * 80
        opacity: card.enter
        scale: 0.96 + 0.04 * card.enter
        transformOrigin: Item.Right

        // Everything visible lives in here so it can follow a swipe as one
        // piece; the MouseArea below stays put and does the dragging.
        Item {
            id: slide
            width: parent.width
            height: parent.height
            // Fades as it leaves.
            opacity: 1 - Math.min(1, Math.abs(x) / (card.cardWidth * 0.75))

            Pill {
                id: cap
                width: card.width
                height: card.height
                cornerRadius: card.cornerRadius
                ringWidth: card.ring
                borderWidth: card.outline
                shadowDx: card.shadowX
                shadowDy: card.shadowY
                fillGradient: bodyGradient
                pressed: card.pressed

                // ----- the art: clipped to the rounded face -----
                ClippingRectangle {
                    anchors.fill: parent
                    radius: Math.max(0, card.cornerRadius - card.ring)
                    color: "transparent"

                    // Pointer on the card: a faint wash of the accent.
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(Theme.accentCyan.r, Theme.accentCyan.g, Theme.accentCyan.b, 0.12)
                        opacity: area.containsMouse ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 140 }
                        }
                    }

                    // The plate. Its right edge leans (Slant), and the left
                    // end runs off the card under the rounded corner.
                    Slant {
                        id: plate
                        x: -40
                        width: 140 + plate.lean / 2
                        height: parent.height
                        skew: 0.18
                        radius: 0
                        gradient: plateGradient
                    }

                    DotField {
                        width: card.plateW - 14
                        height: parent.height
                        corner: "bl"
                        spacing: 13
                        maxRadius: 3
                        reach: 0.95
                        dotColor: Qt.rgba(card.navy.r, card.navy.g, card.navy.b, 0.15)
                    }

                    // Stage light: two bands across the plate.
                    Slant {
                        x: 36 - height * 0.18 / 2
                        width: 22 + height * 0.18
                        height: parent.height
                        skew: 0.18
                        radius: 0
                        color: Qt.rgba(1, 1, 1, area.containsMouse ? 0.34 : 0.22)
                        Behavior on color {
                            ColorAnimation { duration: 160 }
                        }
                    }
                    Slant {
                        x: 66 - height * 0.18 / 2
                        width: 9 + height * 0.18
                        height: parent.height
                        skew: 0.18
                        radius: 0
                        color: Qt.rgba(1, 1, 1, area.containsMouse ? 0.34 : 0.22)
                        Behavior on color {
                            ColorAnimation { duration: 160 }
                        }
                    }

                    // The cut where the plate meets the body.
                    Slant {
                        x: card.plateW - 1.5 - height * 0.18 / 2
                        width: 3 + height * 0.18
                        height: parent.height
                        skew: 0.18
                        radius: 0
                        color: Qt.rgba(card.navy.r, card.navy.g, card.navy.b, 0.9)
                    }

                    // The light that crosses the card once as it lands.
                    Slant {
                        visible: card.shine > 0 && card.shine < 1
                        x: -70 + card.shine * (card.faceW + 140)
                        width: 34 + height * 0.3
                        height: parent.height
                        skew: 0.3
                        radius: 0
                        color: Qt.rgba(1, 1, 1, 0.5)
                    }
                }

                // ----- the icon, as a tilted sticker on the plate -----
                Item {
                    id: sticker
                    x: 46 - width / 2
                    y: (card.faceH - height) / 2
                    width: 60
                    height: 60
                    rotation: area.containsMouse ? 4 : -5
                    scale: card.stickerPop
                    transformOrigin: Item.Center

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 240
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.4
                        }
                    }

                    // Its own small hard shadow.
                    Rectangle {
                        visible: !card.shell
                        x: 3
                        y: 3
                        width: parent.width
                        height: parent.height
                        radius: 19
                        color: card.stickerShadow
                        antialiasing: true
                    }

                    Rectangle {
                        visible: !card.shell
                        anchors.fill: parent
                        radius: 19
                        color: "#ffffff"
                        border.width: 3
                        border.color: card.navy
                        antialiasing: true
                    }

                    // The app's own icon (or the sender's picture), resolved
                    // in NotificationSource.qml. No icon at all -> a bell.
                    ClippingRectangle {
                        anchors.centerIn: parent
                        width: 42
                        height: 42
                        radius: 12
                        color: "transparent"
                        visible: card.icon !== "" && !card.materialIcon

                        Image {
                            anchors.fill: parent
                            asynchronous: true
                            fillMode: Image.PreserveAspectFit
                            // Apps send 512 px+ icons / avatars; this is 42 px.
                            sourceSize: Qt.size(Math.ceil(width * 3), Math.ceil(height * 3))
                            source: card.materialIcon ? "" : card.icon
                        }
                    }

                    // The shell's own notifications: the attribute badge.
                    ShellBadge {
                        anchors.fill: parent
                        size: parent.width
                        visible: card.shell
                        glyph: card.shell ? card.icon.substring(9) : ""
                    }

                    // No icon at all -> a bell.
                    MaterialIcon {
                        anchors.centerIn: parent
                        size: 36
                        visible: card.icon === ""
                        color: card.navy
                        name: "notifications_active"
                    }
                }

                // ----- the words -----
                // App name, as a chip.
                Rectangle {
                    x: card.textX
                    y: 10
                    height: 20
                    width: Math.min(appText.implicitWidth + 18, card.faceW - card.textX - 110)
                    radius: 10
                    color: Theme.chipFill
                    antialiasing: true

                    Text {
                        id: appText
                        anchors.fill: parent
                        anchors.leftMargin: 9
                        anchors.rightMargin: 9
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: card.app
                        color: Theme.chipInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                }

                // A lit diamond and the time.
                Row {
                    x: card.faceW - 20 - width
                    y: 10
                    height: 20
                    spacing: 7

                    DiamondDot {
                        anchors.verticalCenter: parent.verticalCenter
                        lit: true
                        size: 9
                        litColor: card.critical ? "#FF6F9C" : Theme.accentMint
                        lineColor: card.navy
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "now"
                        color: Theme.pInkSub
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }

                Text {
                    x: card.textX
                    y: card.hasBody ? 31 : 38
                    width: card.faceW - card.textX - 20
                    elide: Text.ElideRight
                    text: card.title
                    color: Theme.pInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 19
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }

                Text {
                    x: card.textX
                    y: 57
                    width: card.faceW - card.textX - 20
                    visible: card.hasBody
                    text: card.body
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    lineHeight: 0.92
                    color: Theme.pInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }
            }

            // The body's soft settle toward the bottom, and the plate's
            // gradient (pink when critical).
            Gradient {
                id: bodyGradient
                GradientStop { position: 0.0; color: Theme.pSurface }
                GradientStop { position: 1.0; color: Theme.pSurfaceHover }
            }
            Gradient {
                id: plateGradient
                GradientStop { position: 0.0; color: card.plateTop }
                GradientStop { position: 1.0; color: card.plateBottom }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        enabled: !card.leaving && !card.swipedOut
        drag.target: slide
        drag.axis: Drag.XAxis
        drag.minimumX: -card.width
        drag.maximumX: card.width

        onContainsMouseChanged: card.hoverToggled(area.containsMouse)

        onPressed: {
            settle.stop()
            card.swiped = false
        }

        onReleased: {
            const dx = slide.x
            card.swiped = Math.abs(dx) > 4
            if (Math.abs(dx) >= card.swipeDistance) {
                card.swipedOut = true
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
            if (mouse.button === Qt.RightButton)
                card.dismissed()
            else if (mouse.button === Qt.MiddleButton)
                card.closed()
            else
                card.activated()
        }
    }
}
