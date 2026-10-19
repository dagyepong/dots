import QtQuick
import qs.modules.common

// Rounded corners for a square picture inside a Pill, the way the bar's media
// pill (MediaPill.qml) does it and without a mask: redraw the pill's own frame
// (the ring, then the outline: the same two rounded rectangles Pill.qml draws)
// on top of the picture, only over its two corners on `edge`, so wherever the
// square picture overhangs the curve the frame covers it again. The middle of
// the edge is left to the pill's own ring, so a ring that carries a gradient
// (the dock's hover / running glow) shows no seam.
//
// Put it as the LAST child of the picture's box (a child of the Pill, at the
// left or right end, as tall as the pill's fill) and give it the pill's numbers.
Item {
    id: root

    // "left" or "right": which end of the box lies on the pill's rounded end.
    property string edge: "left"
    property real cornerRadius: 20      // the Pill's cornerRadius
    property real ringWidth: 5          // the Pill's ringWidth
    property real outlineWidth: Theme.borderWidth
    // The ring's colour at the top and bottom of the pill (the Pill's
    // ringColorTop / ringColorBottom) and the outline's.
    property color ringTop: Theme.ringWhite
    property color ringBottom: Theme.ringWhite
    property color outlineColor: Theme.line

    anchors.fill: parent
    z: 20

    readonly property bool leftEdge: root.edge !== "right"
    // How far down from the top (and up from the bottom) the corner patches reach.
    readonly property real reach: Math.min(root.height / 2, root.cornerRadius + 2)
    readonly property real frameW: root.width + root.cornerRadius * 4
    readonly property real frameH: root.height + root.ringWidth * 2

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
    }

    // The two corner patches (top, bottom). Each draws the frame at full height,
    // shifted so it sees its own end of it, and clips to its corner. It takes the
    // ring's colour about halfway down its patch, where the pill's own vertical
    // gradient has got to by then.
    Repeater {
        model: [true, false]

        delegate: Item {
            id: patch
            required property bool modelData
            readonly property bool isTop: patch.modelData
            readonly property real t: Math.min(1, (root.reach / 2) / Math.max(1, root.height))
            readonly property color ring: patch.isTop ? root.mix(root.ringTop, root.ringBottom, patch.t)
                                                    : root.mix(root.ringBottom, root.ringTop, patch.t)

            x: 0
            y: patch.isTop ? 0 : root.height - root.reach
            width: root.width
            height: root.reach
            clip: true

            Item {
                x: root.leftEdge ? -root.ringWidth : root.width + root.ringWidth - root.frameW
                y: (patch.isTop ? 0 : -(root.height - root.reach)) - root.ringWidth
                width: root.frameW
                height: root.frameH

                Rectangle {
                    anchors.fill: parent
                    radius: root.cornerRadius
                    color: "transparent"
                    border.width: root.ringWidth
                    border.color: patch.ring
                    antialiasing: true
                }
                Rectangle {
                    anchors.fill: parent
                    radius: root.cornerRadius
                    color: "transparent"
                    border.width: root.outlineWidth
                    border.color: root.outlineColor
                    antialiasing: true
                }
            }
        }
    }
}
