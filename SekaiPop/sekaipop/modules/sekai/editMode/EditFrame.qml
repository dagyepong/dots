import QtQuick
import qs.services
import qs.modules.common

// The frame round Edit Desktop's card: navy outline, white ring, navy
// outline — the same three layers every Pill is made of, wrapped round the
// shrunken wallpaper. It is drawn ON TOP of the wallpaper, and that is what
// gives the card its rounded corners: the wallpaper itself is a plain
// rectangle (QML has no rounded clip), but the ring is thicker than the
// corner needs (see `frame` below), so the wallpaper's square corners end up
// hidden under it and only the rounded hole shows the picture.
//
// The rings are Rectangles with a border and no fill: a border's outer
// corner has `radius`, its inner corner `radius - border.width`. Three of
// them, grown outwards from the card's edge:
//
//     distance from the card   0 .. 3     navy  (the inner outline)
//                              3 .. 11    white (the ring)
//                              11 .. 14   navy  (the outer outline)
//
// For the corner to be hidden the frame needs a thickness of at least
// 0.29 x the card's corner radius; 14 against 22 leaves plenty to spare.
Item {
    id: root

    property var screenObj: null
    property real uiScale: 1

    readonly property string screenName: root.screenObj ? root.screenObj.name : ""
    readonly property real p: EditMode.progressFor(root.screenName)

    visible: EditMode.editing(root.screenName) && root.p > 0.001
    opacity: Math.max(0, Math.min(1, root.p * 2))

    readonly property var target: EditMode.cardRect(root.width, root.height, root.uiScale)
    readonly property real sc: 1 + (root.target.s - 1) * Math.max(0, root.p)
    readonly property real cardX: root.target.x * root.p
    readonly property real cardY: root.target.y * root.p
    readonly property real cardW: root.width * root.sc
    readonly property real cardH: root.height * root.sc

    // The frame grows from nothing as the card does (a ring drawn at full
    // thickness round a full-screen desktop would sit off-screen anyway).
    readonly property real frame: EditMode.frameWidth * root.uiScale * Math.min(1, Math.max(0, root.p))
    readonly property real line: Math.min(3 * root.uiScale, root.frame / 4)
    readonly property real cardR: EditMode.cardRadius * root.uiScale

    // Three rings, each covering `from`..`to` pixels out from the card's
    // edge (spelled out rather than made an inline component: inline
    // components cannot see this file's ids).

    // white ring (drawn first, so the two outlines sit on top of its edges)
    Rectangle {
        readonly property real to: root.frame - root.line
        x: root.cardX - to
        y: root.cardY - to
        width: root.cardW + to * 2
        height: root.cardH + to * 2
        radius: root.cardR + to
        color: "transparent"
        border.width: Math.max(0, to - root.line)
        border.color: Theme.pRingWhite
        antialiasing: true
    }

    // inner navy outline, against the picture
    Rectangle {
        readonly property real to: root.line
        x: root.cardX - to
        y: root.cardY - to
        width: root.cardW + to * 2
        height: root.cardH + to * 2
        radius: root.cardR + to
        color: "transparent"
        border.width: to
        border.color: Theme.colBorder
        antialiasing: true
    }

    // outer navy outline
    Rectangle {
        readonly property real to: root.frame
        x: root.cardX - to
        y: root.cardY - to
        width: root.cardW + to * 2
        height: root.cardH + to * 2
        radius: root.cardR + to
        color: "transparent"
        border.width: root.line
        border.color: Theme.colBorder
        antialiasing: true
    }
}
