import QtQuick
import QtQuick.Shapes
import qs.theme

// The bar and the thin edges of the screen as ONE shape: the screen minus a rounded "hole" where the windows live.
Shape {
    id: root

    property real barW: 46          // width of the bar on the left
    property real edge: 8           // thickness of the frame on the other three sides
    property real radius: 22        // rounded corners of the hole

    preferredRendererType: Shape.CurveRenderer

    readonly property real hx: barW
    readonly property real hy: edge
    readonly property real hw: Math.max(0, width - barW - edge)
    readonly property real hh: Math.max(0, height - edge * 2)

    ShapePath {
        fillColor: Theme.island
        strokeWidth: -1
        fillRule: ShapePath.OddEvenFill

        // Whole screen
        startX: 0; startY: 0
        PathLine { x: root.width; y: 0 }
        PathLine { x: root.width; y: root.height }
        PathLine { x: 0; y: root.height }
        PathLine { x: 0; y: 0 }

        // The hole
        PathMove { x: root.hx + root.radius; y: root.hy }
        PathLine { x: root.hx + root.hw - root.radius; y: root.hy }
        PathArc { x: root.hx + root.hw; y: root.hy + root.radius; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Clockwise }
        PathLine { x: root.hx + root.hw; y: root.hy + root.hh - root.radius }
        PathArc { x: root.hx + root.hw - root.radius; y: root.hy + root.hh; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Clockwise }
        PathLine { x: root.hx + root.radius; y: root.hy + root.hh }
        PathArc { x: root.hx; y: root.hy + root.hh - root.radius; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Clockwise }
        PathLine { x: root.hx; y: root.hy + root.radius }
        PathArc { x: root.hx + root.radius; y: root.hy; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Clockwise }
    }
}
