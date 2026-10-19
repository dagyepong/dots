import QtQuick
import qs.modules.common

// The strip of film the Overview's workspace cards are frames of: a dark
// 35 mm-style base with a column of sprocket holes down each side, four
// holes to every frame like real film. Purely a backdrop — Overview.qml
// sizes and places it and puts the cards (and the click-eater) on top.
//
// The holes are drawn from the same numbers the cards are laid out with
// (`frameStep`, `frameHeight`, `topOffset`), so each frame sits exactly
// between its four holes, and they move with `scrollOffset` when the
// column scrolls: it looks like the film is being wound past the lens.
//
// No Canvas here: a hole is a small rounded Rectangle, so nothing has to be
// repainted when the strip is resized or scrolled, only moved.
Item {
    id: root

    // How the cards are laid out on the strip (all in this item's pixels).
    property int frames: 5              // how many frames (workspace cards)
    property real frameStep: 220        // frame top -> next frame top
    property real frameHeight: 200      // one frame's height
    property real topOffset: 36         // strip top -> first frame top
    property real scrollOffset: 0       // how far the column is scrolled up
    property real sideWidth: 38         // strip edge -> frame, where the holes are

    property real radius: 6

    readonly property real pitch: root.frameStep / 4
    readonly property real holeW: 13
    readonly property real holeH: Math.max(8, Math.min(22, root.pitch * 0.42))
    // The holes are this far from the strip's outer edge.
    readonly property real holeInset: Math.round((root.sideWidth - root.holeW) / 2) - 1

    // Hard offset shadow, same convention as every other card here.
    Rectangle {
        x: 6
        y: 7
        width: root.width
        height: root.height
        radius: root.radius
        color: "#000000"
        opacity: 0.4
    }

    // ===== the film =====
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: ScrapbookTheme.filmBase
        border.width: 3
        border.color: ScrapbookTheme.filmEdge
        clip: true

        // A soft sheen down the left, so it reads as glossy acetate and not flat black.
        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: parent.width * 0.45
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#12ffffff" }
                GradientStop { position: 1.0; color: "#00ffffff" }
            }
        }

        // Thin pale lines along both edges, the way a film base has its edge
        // rails.
        Rectangle { x: 5; y: 4; width: 1; height: parent.height - 8; color: "#22ffffff" }
        Rectangle { x: parent.width - 6; y: 4; width: 1; height: parent.height - 8; color: "#22ffffff" }

        // ===== sprocket holes: 4 per frame, a column on each side =====
        Repeater {
            model: root.frames * 8

            delegate: Item {
                id: hole

                required property int index

                readonly property int frameIndex: Math.floor(hole.index / 8)
                readonly property int holeSlot: Math.floor((hole.index % 8) / 2)   // 0..3 within the frame
                readonly property bool onRight: hole.index % 2 === 1
                readonly property real centerY: root.topOffset - root.scrollOffset
                    + hole.frameIndex * root.frameStep + root.frameHeight / 2
                    + (hole.holeSlot - 1.5) * root.pitch

                width: root.holeW
                height: root.holeH
                x: hole.onRight ? root.width - root.holeInset - root.holeW : root.holeInset
                y: Math.round(hole.centerY - root.holeH / 2)
                visible: hole.y > -root.holeH && hole.y < root.height

                Rectangle {
                    anchors.fill: parent
                    radius: 3.5
                    color: ScrapbookTheme.filmHole
                    border.width: 1
                    border.color: ScrapbookTheme.filmHoleShade
                }
                // inner shadow along the top, so the hole looks cut through
                Rectangle {
                    x: 2
                    y: 1
                    width: parent.width - 4
                    height: 3
                    radius: 1.5
                    color: ScrapbookTheme.filmHoleShade
                    opacity: 0.55
                }
            }
        }
    }
}
