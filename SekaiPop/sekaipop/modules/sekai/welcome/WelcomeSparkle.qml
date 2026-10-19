import QtQuick
import QtQuick.Shapes

// The four-point sparkle from the reference logo: cream star, dark outline,
// sides curved in. `pop` (0..1+) is how far in it is; it scales the sparkle,
// so a value past 1 (the spring's overshoot) makes it hop a little bigger.
Item {
    id: root

    property real size: 40
    property color fill: "#ffefce"
    property color ink: "#232235"
    property real stroke: Math.max(1.6, root.size * 0.075)
    property real pop: 1
    // 0..1: a slow twinkle, driven from outside while the logo idles.
    property real twinkle: 0

    width: root.size
    height: root.size
    visible: root.pop > 0.001
    transformOrigin: Item.Center
    scale: Math.max(0, root.pop) * (1 + 0.1 * root.twinkle)
    rotation: (1 - Math.min(1, root.pop)) * -50 + 6 * root.twinkle

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.ink
            strokeWidth: root.stroke
            fillColor: root.fill
            joinStyle: ShapePath.RoundJoin
            startX: root.width / 2
            startY: root.stroke / 2

            PathQuad { x: root.width - root.stroke / 2; y: root.height / 2; controlX: root.width * 0.56; controlY: root.height * 0.44 }
            PathQuad { x: root.width / 2; y: root.height - root.stroke / 2; controlX: root.width * 0.56; controlY: root.height * 0.56 }
            PathQuad { x: root.stroke / 2; y: root.height / 2; controlX: root.width * 0.44; controlY: root.height * 0.56 }
            PathQuad { x: root.width / 2; y: root.stroke / 2; controlX: root.width * 0.44; controlY: root.height * 0.44 }
        }
    }
}
