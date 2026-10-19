import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The frame the bar's playful popups (Calendar, Battery, Weather, Media, Discord) share, so each
// of those files is only its own card. It is what BatteryPopup / WeatherPopup
// used to repeat: a HyprlandFocusGrab that dismisses on a click anywhere else
// (the bar's own window excepted), a PopupWindow that the bar places under its
// button (Bar.qml popupX / popupY / popupGravity, so it follows the bar to any
// edge), and the card drawn inside a ScaleHost so it matches the monitor's scale.
//
// What it adds:
//   - the card pops in (a little overshoot) out of the edge the bar is on, and
//     shrinks all the way back into it on the way out, the same language as the
//     desktop clock. The window stays up until the swallow is
//     done. Press the next popup's button before it is: the old card is put
//     away at once (services/PopupHandoff.qml), so two never show together.
//   - the window is only unmapped a few frames AFTER the card has shrunk to
//     nothing (`settling`), so the last picture the compositor gets is an empty
//     one. Unmapped the moment `reveal` hit 0, the last picture it had was the
//     frame before, with a small copy of the card still in it, and Hyprland
//     faded that frozen copy out: a small card that stays and fades. The taller
//     the card, the more of it is left in that frame (the media panel's turntable
//     is the tallest).
//   - a `bare` card (the equalizer console) goes in and out the same
//     way as every other card: it grows out of its pill and shrinks all the way
//     back into it. (It used to shrink to the nearest point on the window's
//     edge instead; that is gone so Media and Discord match Weather, Battery
//     and Calendar.)
//   - `reveal` (0..1, overshooting a little) is public, so a card can stage its
//     own entrance: cascades, springs, anything keyed to it.
//   - Escape closes; every other key is handed on through `keyed(event)`.
//
// Use it like this: everything declared inside lands on the card's face, whose
// size is `contentWidth` x `contentHeight` (design pixels).
//
//   SekaiPopup {
//       id: root
//       contentWidth: 328
//       contentHeight: stack.implicitHeight + 32
//       Column { id: stack; x: 16; y: 16; ... }
//   }
//
// The window is `bleed` bigger than the card on every side except the one
// facing the bar, so a sticker that sits a few pixels over the card's edge, or
// the pop's overshoot, is not cut off. (Nothing may poke out on the bar's side:
// the window starts there.)
Scope {
    id: host

    property var parentWindow: null    // the bar's PanelWindow
    property Item anchorItem: null     // the button to centre under
    property bool open: false

    // `centered: true` puts the card in the middle of the monitor instead of under
    // `anchorItem` (the equalizer console does): the window is placed from the
    // screen's size, it has bleed room on all four sides (no bar edge to touch),
    // and the card grows out of its own middle and shrinks back into it.
    property bool centered: false

    // This monitor's scale (scale.json), read off the bar's window.
    readonly property real uiScale: host.parentWindow && host.parentWindow.uiScale ? host.parentWindow.uiScale : 1

    // The bar is drawn in the Capsule style (Bar.qml barStyle 3; a standing bar
    // draws Float instead, so it reports 0 there). The card then wears the bar's
    // colours: rim outline, rim-lit shadow, body fill (Pill.capRim).
    readonly property bool capsuleStyle: !!host.parentWindow && host.parentWindow.barStyle === 3

    // The room inside the card's outline.
    property real contentWidth: 320
    property real contentHeight: 200

    readonly property real bleed: 14

    // Which edge the bar is on, so the card grows out of it (and goes back into
    // it) and the window's flat side is the one touching the bar. Bar.qml's
    // popupX / popupY / popupGravity put that edge against the bar.
    readonly property string barEdge: host.parentWindow && host.parentWindow.barPosition
        ? host.parentWindow.barPosition : "top"
    readonly property real padT: !host.centered && host.barEdge === "top" ? 6 : host.bleed
    // (A bottom bar gets the same 6 px of air a top bar has, between it and the card.)
    readonly property real padB: !host.centered && host.barEdge === "bottom" ? 6 : host.bleed
    readonly property real padL: !host.centered && host.barEdge === "left" ? 0 : host.bleed
    readonly property real padR: !host.centered && host.barEdge === "right" ? 0 : host.bleed

    // 0 = away, 1 = shown; overshoots past 1 while popping in.
    property real reveal: 0

    // True for a moment after the card has gone (see the top of this file): the
    // window stays mapped, showing nothing, so the compositor's last picture of
    // it is an empty one. 80 ms is a few frames, even when a heavy card is slow
    // to draw them.
    property bool settling: false

    function settle() {
        host.settling = true
        settleTimer.restart()
    }

    Timer {
        id: settleTimer
        interval: 80
        onTriggered: host.settling = false
    }

    // The point the card grows out of and shrinks back into: the middle of the
    // button it belongs to, in the card's own design pixels. It is a little way
    // OUTSIDE the card (the bar is above it), so on the way out the whole card
    // slides into the pill and leaves the window there: no small piece of it is
    // left behind to fade.
    //
    // The popup window is anchored by ONE corner and grows away from it (Bar.qml popupGravity):
    // a top or left bar's window has its top-left corner at anchor.rect, but a bottom bar's grows
    // UP from it (its top is a whole window height above) and a right bar's grows LEFT. The
    // origin has to be measured from the window's real top-left corner, or the card on a bottom
    // or right bar grows out of (and shrinks into) the wrong place, as if the bar were on the
    // top / left.
    readonly property int gravity: host.parentWindow ? host.parentWindow.popupGravity : (Edges.Bottom | Edges.Right)
    readonly property real windowLeft: popup.anchor.rect.x - ((host.gravity & Edges.Left) ? popup.implicitWidth : 0)
    readonly property real windowTop: popup.anchor.rect.y - ((host.gravity & Edges.Top) ? popup.implicitHeight : 0)

    readonly property real originX: host.centered ? card.width / 2 : host.anchorItem
        ? (host.anchorCenterX - host.windowLeft) / host.uiScale - host.padL
        : host.contentWidth / 2
    readonly property real originY: host.centered ? card.height / 2 : host.anchorItem
        ? (host.anchorCenterY - host.windowTop) / host.uiScale - host.padT
        : (host.barEdge === "bottom" ? host.contentHeight : 0)

    signal closeRequested()
    signal keyed(var event)

    default property alias content: body.data

    // For a card that draws its own body and wants none of the shell's chrome
    // (no navy outline, white ring or hard shadow): set `bare: true` and put the
    // card in `bareContent` instead of the default slot. The card is then exactly
    // `contentWidth + 2 x Theme.borderWidth` by `contentHeight + 2 x
    // Theme.borderWidth + Theme.shadowOffset` big (so the numbers stay the same
    // whichever way a card is built), with nothing around it. EqualizerPopup.qml
    // (the console) is the one that uses it.
    property bool bare: false
    property alias bareContent: bareBody.data

    readonly property real anchorCenterX: {
        void host.open
        return anchorItem ? anchorItem.mapToItem(null, anchorItem.width / 2, 0).x : 0
    }

    readonly property real anchorCenterY: {
        void host.open
        return anchorItem ? anchorItem.mapToItem(null, 0, anchorItem.height / 2).y : 0
    }

    readonly property bool grabWanted: open
    onGrabWantedChanged: {
        if (grabWanted)
            grabDelay.restart()
        else {
            grabDelay.stop()
            grab.active = false
        }
    }

    Timer {
        id: grabDelay
        interval: 80
        onTriggered: grab.active = host.grabWanted
    }

    HyprlandFocusGrab {
        id: grab
        windows: [popup, host.parentWindow]
        onCleared: host.closeRequested()
    }

    // Two fixed animations, started from the change of `open` (a Behavior whose
    // easing is chosen by a binding on the same flag can start with the other
    // direction's easing). Both start from wherever `reveal` is, so pressing the
    // button again halfway just turns the card round.
    Connections {
        target: host

        function onOpenChanged() {
            if (host.open) {
                PopupHandoff.opening()
                swallow.stop()
                settleTimer.stop()
                host.settling = false
                popIn.restart()
            } else {
                popIn.stop()
                swallow.restart()
            }
        }
    }

    // Another popup is opening: if this one is still on its way out, put it
    // away now rather than leave it shrinking next to the newcomer.
    Connections {
        target: PopupHandoff

        function onSerialChanged() {
            if (!host.open && host.reveal > 0) {
                swallow.stop()
                popIn.stop()
                host.reveal = 0
                host.settle()
            }
        }
    }

    NumberAnimation {
        id: popIn
        target: host
        property: "reveal"
        to: 1
        duration: 340
        easing.type: Easing.OutBack
        easing.overshoot: 1.3
    }

    NumberAnimation {
        id: swallow
        target: host
        property: "reveal"
        to: 0
        duration: 170
        easing.type: Easing.InCubic
        // The card is gone: hold the (now empty) window a few frames longer.
        onFinished: host.settle()
    }

    PopupWindow {
        id: popup
        visible: (host.open || host.reveal > 0.001 || host.settling) && host.parentWindow !== null

        anchor.window: host.parentWindow
        // Where the popup sits is decided by the bar (Bar.qml popupX /
        // popupY / popupGravity), so it follows the bar to any edge.
        // (Centered: every bar window starts at its screen's own corner, so the
        // middle of the screen is measured from that; a window that grows left or
        // up from the anchor point needs its far edge there instead of its near one.)
        anchor.rect.x: host.centered && host.parentWindow && host.parentWindow.screen
            ? Math.round((host.parentWindow.screen.width - implicitWidth) / 2) + ((host.gravity & Edges.Left) ? implicitWidth : 0)
            : (host.parentWindow ? host.parentWindow.popupX(host.anchorCenterX, host.anchorCenterY, implicitWidth, implicitHeight) : 0)
        anchor.rect.y: host.centered && host.parentWindow && host.parentWindow.screen
            ? Math.round((host.parentWindow.screen.height - implicitHeight) / 2) + ((host.gravity & Edges.Top) ? implicitHeight : 0)
            : (host.parentWindow ? host.parentWindow.popupY(host.anchorCenterX, host.anchorCenterY, implicitWidth, implicitHeight) : 0)
        anchor.gravity: host.parentWindow ? host.parentWindow.popupGravity : (Edges.Bottom | Edges.Right)

        implicitWidth: Math.ceil((card.width + host.padL + host.padR) * host.uiScale)
        implicitHeight: Math.ceil((card.height + host.padT + host.padB) * host.uiScale)
        color: "transparent"

        // Keyboard. Best effort: it works whenever the compositor hands this
        // popup keyboard focus; the mouse never depends on it.
        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    host.closeRequested()
                    event.accepted = true
                } else {
                    host.keyed(event)
                }
            }
        }

        ScaleHost {
            anchors.fill: parent
            factor: host.uiScale
            // Nothing is clickable while the card is being swallowed.
            enabled: host.open

            Item {
                id: stage

                // Grows out of its button from nothing, and shrinks all the way
                // back into it. It fades in a touch as it starts, but never out: it
                // is whole until it has gone into the pill.
                x: host.padL
                y: host.padT
                width: card.width
                height: card.height
                opacity: host.open ? Math.min(1, host.reveal * 8) : 1
                transform: Scale {
                    origin.x: host.originX
                    origin.y: host.originY
                    xScale: Math.max(0, host.reveal)
                    yScale: Math.max(0, host.reveal)
                }

                Pill {
                    id: card
                    visible: !host.bare
                    capRim: host.capsuleStyle
                    cornerRadius: Theme.radiusOuter
                    ringWidth: Theme.borderWidth
                    innerRing: Theme.cardRing
                    fillColor: Theme.surface
                    implicitWidth: host.contentWidth + 2 * Theme.borderWidth
                    implicitHeight: host.contentHeight + 2 * Theme.borderWidth + Theme.shadowOffset

                    Item {
                        id: body
                        anchors.fill: parent
                    }
                }

                Item {
                    id: bareBody
                    width: card.width
                    height: card.height
                    visible: host.bare
                }
            }
        }
    }
}
