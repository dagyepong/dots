import QtQuick
import QtQuick.Shapes
import qs.theme

// The same idea as AttachedShape, but fused with the RIGHT edge: a body that comes out of the edge toward the left and
// widens with two concave curves (above and below) where it touches it. `bodyDepth` is how far it comes out,
// `bodyLength` its height. The line along the edge is not stroked, so it melts into the frame.
Shape {
    id: root

    property real bodyDepth: 240
    property real bodyLength: 80
    property real fillet: 14
    property real corner: 18
    property color fillColor: Theme.island
    property color edgeColor: Theme.border
    property real edgeWidth: 1

    width: bodyDepth
    height: bodyLength + fillet * 2
    preferredRendererType: Shape.CurveRenderer
    antialiasing: true

    readonly property real f: Math.min(fillet, bodyDepth / 2)
    readonly property real r: Math.min(corner, Math.max(1, bodyDepth - f), bodyLength / 2)
    readonly property real dd: width
    readonly property real tt: height

    // fill (closed)
    ShapePath {
        fillColor: root.fillColor
        strokeColor: "transparent"
        strokeWidth: -1
        startX: root.dd; startY: 0
        PathArc { x: root.dd - root.f; y: root.f; radiusX: root.f; radiusY: root.f; direction: PathArc.Clockwise }
        PathLine { x: root.r; y: root.f }
        PathArc { x: 0; y: root.f + root.r; radiusX: root.r; radiusY: root.r; direction: PathArc.Counterclockwise }
        PathLine { x: 0; y: root.tt - root.f - root.r }
        PathArc { x: root.r; y: root.tt - root.f; radiusX: root.r; radiusY: root.r; direction: PathArc.Counterclockwise }
        PathLine { x: root.dd - root.f; y: root.tt - root.f }
        PathArc { x: root.dd; y: root.tt; radiusX: root.f; radiusY: root.f; direction: PathArc.Clockwise }
        PathLine { x: root.dd; y: 0 }
    }

    // border (open: nothing along the edge)
    ShapePath {
        fillColor: "transparent"
        strokeColor: root.edgeColor
        strokeWidth: root.edgeWidth
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.FlatCap
        startX: root.dd; startY: 0
        PathArc { x: root.dd - root.f; y: root.f; radiusX: root.f; radiusY: root.f; direction: PathArc.Clockwise }
        PathLine { x: root.r; y: root.f }
        PathArc { x: 0; y: root.f + root.r; radiusX: root.r; radiusY: root.r; direction: PathArc.Counterclockwise }
        PathLine { x: 0; y: root.tt - root.f - root.r }
        PathArc { x: root.r; y: root.tt - root.f; radiusX: root.r; radiusY: root.r; direction: PathArc.Counterclockwise }
        PathLine { x: root.dd - root.f; y: root.tt - root.f }
        PathArc { x: root.dd; y: root.tt; radiusX: root.f; radiusY: root.f; direction: PathArc.Clockwise }
    }
}
