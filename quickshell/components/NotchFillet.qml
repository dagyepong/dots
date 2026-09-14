// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T C H   F I L L E T                                                │
// │   the concave corner where the notch meets the screen edge               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import "../theme"

// A concave fillet where the notch meets the bezel. Rectangle `radius` only
// rounds corners inward, so this is drawn: the square minus a disc centred
// on its far corner.
Item {
    id: root

    property color color: Theme.island
    // Mirrored, for the notch's left side.
    property bool mirrored: false

    implicitWidth: Theme.radiusNotch * 2
    implicitHeight: Theme.radiusNotch * 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        transform: Scale {
            xScale: root.mirrored ? -1 : 1
            origin.x: root.width / 2
        }

        ShapePath {
            strokeWidth: 0
            fillColor: root.color

            startX: 0
            startY: 0

            PathLine { x: root.width; y: 0 }

            // Quarter arc around the far corner.
            PathAngleArc {
                centerX: root.width
                centerY: root.height
                radiusX: root.width
                radiusY: root.height
                startAngle: -90
                sweepAngle: -90
            }

            PathLine { x: 0; y: 0 }
        }
    }
}
