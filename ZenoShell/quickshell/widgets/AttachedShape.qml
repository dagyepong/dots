import QtQuick
import QtQuick.Shapes
import qs.theme

// A bar fused with the top edge of the screen: where it touches the edge it widens with two concave curves
// (the fillets), the bottom corners are rounded. Drawn in the area of the island, widened by `fillet` on each side.
Shape {
    id: root

    property real bodyWidth: 200      // width of the island
    property real bodyHeight: 34
    property real fillet: 14          // concave curves at the top
    property real corner: 18          // rounded bottom corners
    property color fillColor: Theme.island
    property color edgeColor: Theme.border
    property real edgeWidth: 1

    width: bodyWidth + fillet * 2
    height: bodyHeight
    preferredRendererType: Shape.CurveRenderer
    antialiasing: true

    readonly property real f: Math.min(fillet, bodyHeight / 2)
    readonly property real r: Math.min(corner, Math.max(1, bodyHeight - f), bodyWidth / 2)

    ShapePath {
        fillColor: root.fillColor
        strokeColor: root.edgeColor
        strokeWidth: root.edgeWidth
        joinStyle: ShapePath.RoundJoin

        // start at the top edge, left of the island, and go round clockwise
        startX: 0
        startY: 0
        // left fillet: from the edge down to the side of the island (curving outwards)
        PathArc {
            x: root.f; y: root.f
            radiusX: root.f; radiusY: root.f
            direction: PathArc.Clockwise
        }
        PathLine { x: root.f; y: root.height - root.r }
        PathArc {
            x: root.f + root.r; y: root.height
            radiusX: root.r; radiusY: root.r
            direction: PathArc.Counterclockwise
        }
        PathLine { x: root.width - root.f - root.r; y: root.height }
        PathArc {
            x: root.width - root.f; y: root.height - root.r
            radiusX: root.r; radiusY: root.r
            direction: PathArc.Counterclockwise
        }
        PathLine { x: root.width - root.f; y: root.f }
        // right fillet
        PathArc {
            x: root.width; y: 0
            radiusX: root.f; radiusY: root.f
            direction: PathArc.Clockwise
        }
        PathLine { x: 0; y: 0 }
    }
}
