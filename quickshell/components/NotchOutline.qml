// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T C H   O U T L I N E                                              │
// │   the hairline round an attached island · open along the screen edge     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import QtQuick.Shapes

import "../theme"

// One stroke from the screen edge down the left fillet, round the shape and
// up the right fillet. Nothing runs along the top, where the shape meets the
// edge. Drawn half a pixel inside the fill, as a Rectangle border is.
Item {
    id: root

    // The shape's left and right edges and its height, in the parent's frame.
    property real shapeLeft: 0
    property real shapeRight: 0
    property real shapeHeight: 0
    // The shape's lower corners.
    property real radius: 0
    property color color: Theme.borderIn(QsWindow.window)
    // How far inside the rim the stroke runs, for the glass's thick edge.
    property int inset: 0

    // The fillet's radius: NotchFillet's square is its diameter wide.
    readonly property real fillet: Theme.radiusNotch * 2
    readonly property real r: Math.max(0, Math.min(root.radius,
        (root.shapeRight - root.shapeLeft) / 2, root.shapeHeight - root.fillet))

    // The stroke's centre inside the shape's edge, and the lower corners'
    // radius there; the fillets' arcs grow by as much as the corners shrink.
    readonly property real d: root.inset + 0.5
    readonly property real ri: Math.max(0, root.r - root.d)

    anchors.fill: parent

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 1
            strokeColor: root.color
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            startX: root.shapeLeft - root.fillet
            startY: -root.d

            PathArc {
                x: root.shapeLeft + root.d
                y: root.fillet
                radiusX: root.fillet + root.d
                radiusY: root.fillet + root.d
            }
            PathLine { x: root.shapeLeft + root.d; y: root.shapeHeight - root.r }
            PathArc {
                x: root.shapeLeft + root.r
                y: root.shapeHeight - root.d
                radiusX: root.ri
                radiusY: root.ri
                direction: PathArc.Counterclockwise
            }
            PathLine { x: root.shapeRight - root.r; y: root.shapeHeight - root.d }
            PathArc {
                x: root.shapeRight - root.d
                y: root.shapeHeight - root.r
                radiusX: root.ri
                radiusY: root.ri
                direction: PathArc.Counterclockwise
            }
            PathLine { x: root.shapeRight - root.d; y: root.fillet }
            PathArc {
                x: root.shapeRight + root.fillet
                y: -root.d
                radiusX: root.fillet + root.d
                radiusY: root.fillet + root.d
            }
        }
    }
}
