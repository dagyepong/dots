import QtQuick
import QtQuick.Shapes

// A small wavy accent line, drawn on (the reference has two of them beside the
// logo): a dark stroke with a paler stroke on top, so it reads as an outlined
// line. `draw` (0..1) is how much of it exists, from its left end.
//
//   WelcomeSquiggle { length: 60; draw: 0.5 }
Item {
    id: root

    property real length: 60
    property real amplitude: 5
    property real cycles: 2
    property real stroke: 3
    property real draw: 1
    property color fill: "#ffefce"
    property color ink: "#232235"

    readonly property var pts: {
        const a = [];
        const n = 40;
        const upto = Math.max(0, Math.min(1, root.draw)) * n;
        const last = Math.floor(upto);
        for (let i = 0; i <= last && i <= n; i++)
            a.push(Qt.point(root.length * i / n, root.amplitude * Math.sin(2 * Math.PI * root.cycles * i / n)));
        const f = upto - last;
        if (f > 0.001 && last < n) {
            const t = (last + f) / n;
            a.push(Qt.point(root.length * t, root.amplitude * Math.sin(2 * Math.PI * root.cycles * t)));
        }
        return a;
    }

    width: root.length
    height: root.amplitude * 2
    visible: root.draw > 0.01 && root.pts.length > 1

    Shape {
        x: 0
        y: root.amplitude
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.ink
            strokeWidth: root.stroke * 2.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline { path: root.pts }
        }

        ShapePath {
            strokeColor: root.fill
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline { path: root.pts }
        }
    }
}
