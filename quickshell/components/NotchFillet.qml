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

    property color color: Theme.islandGround
    // Mirrored, for the notch's left side.
    property bool mirrored: false
    // How far down the glass's light from the top reaches in the shape the
    // fillet flares from (`GlassSheen`); 0 for none.
    property real sheenReach: 0

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

        ShapePath {
            strokeWidth: 0
            fillColor: "transparent"
            fillGradient: root.sheenReach > 0 ? sheen : null

            startX: 0
            startY: 0

            PathLine { x: root.width; y: 0 }

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

    LinearGradient {
        id: sheen

        x1: 0
        y1: 0
        x2: 0
        y2: root.sheenReach
        GradientStop { position: 0; color: Theme.glassSheen }
        GradientStop { position: 1; color: "transparent" }
    }
}
