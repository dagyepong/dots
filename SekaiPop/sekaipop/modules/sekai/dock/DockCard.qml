import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The card that pops out of the dock (Dock.qml): the window overview, the
// right-click menu, a folder's apps and the media player are all this card with
// different things inside. It is a Pill in the same housing as the dock itself,
// placed over a flat dock, beside a standing one (on the screen side), pointing
// at the key it belongs to.
//
// The caller (Dock.qml) gives it the dock's pill, the key's centre in the
// card's own coordinate space (`anchorX` / `anchorY`, design pixels) and says
// when it is `open`. Put the content inside it as children, at x: pad, y: pad,
// and set contentWidth / contentHeight to the size of that content.
//
// maskX / maskY / maskW / maskH are the card plus the gap down to the dock
// (design pixels): the dock's input mask uses them, so the pointer can travel
// from the key onto the card without leaving the dock's input area.
Pill {
    id: card

    property string position: "bottom"
    property Item dockPill: null
    property real anchorX: 0
    property real anchorY: 0
    // Extra distance from the dock: keys that are magnified stick out past it.
    property real clearance: 0
    property bool open: false

    property real contentWidth: 100
    property real contentHeight: 50

    readonly property real gap: 16
    readonly property real pad: 16
    readonly property real edge: 8

    readonly property bool vertical: card.position === "left" || card.position === "right"
    readonly property real hostW: card.parent ? card.parent.width : 0
    readonly property real hostH: card.parent ? card.parent.height : 0

    // `true` while the pointer is on the card (or the gap down to the dock).
    readonly property bool hovered: hoverer.hovered
    signal hoverStateChanged(bool on)

    cornerRadius: Theme.radiusOuter
    ringWidth: Theme.borderWidth + Theme.outerRingWidth
    ringColorTop: Theme.surfaceRing
    ringColorBottom: Theme.surfaceRing
    fillColor: Theme.surface

    width: card.contentWidth + 2 * (card.ringWidth + card.pad) + card.shadowDx
    height: card.contentHeight + 2 * (card.ringWidth + card.pad) + card.shadowDy

    readonly property real px: card.dockPill ? card.dockPill.x : 0
    readonly property real py: card.dockPill ? card.dockPill.y : 0
    readonly property real pw: card.dockPill ? card.dockPill.width : 0
    readonly property real ph: card.dockPill ? card.dockPill.height : 0

    x: card.vertical
        ? (card.position === "left" ? card.px + card.pw + card.gap + card.clearance
                                    : card.px - card.width - card.gap - card.clearance)
        : Math.max(card.edge, Math.min(card.anchorX - card.width / 2, card.hostW - card.width - card.edge))
    y: card.vertical
        ? Math.max(card.edge, Math.min(card.anchorY - card.height / 2, card.hostH - card.height - card.edge))
        : (card.position === "bottom" ? card.py - card.height - card.gap - card.clearance
                                      : card.py + card.ph + card.gap + card.clearance)

    readonly property real maskX: card.vertical && card.position === "left" ? card.px + card.pw : card.x
    readonly property real maskY: (!card.vertical && card.position === "top") ? card.py + card.ph : card.y
    readonly property real maskW: !card.vertical ? card.width
        : (card.position === "left" ? card.x + card.width - (card.px + card.pw) : card.px - card.x)
    readonly property real maskH: card.vertical ? card.height
        : (card.position === "bottom" ? card.py - card.y : card.y + card.height - (card.py + card.ph))

    // Pops up from the dock.
    property real shown: card.open ? 1 : 0
    Behavior on shown {
        NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
    }
    visible: card.shown > 0.01
    z: 40
    scale: 0.8 + 0.2 * Math.min(1.1, card.shown)
    opacity: Math.min(1, card.shown * 1.6)
    transformOrigin: card.vertical
        ? (card.position === "left" ? Item.Left : Item.Right)
        : (card.position === "bottom" ? Item.Bottom : Item.Top)

    // `margin` makes the card's ring and the gap down to the dock count as "on
    // the card" too (the input mask already covers them).
    HoverHandler {
        id: hoverer
        margin: card.gap + card.ringWidth + 2
        onHoveredChanged: card.hoverStateChanged(hovered)
    }
}
