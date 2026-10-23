import QtQuick
import QtQuick.Shapes

// Drops of sweat running down beside his head while the machine works hard:
// one drop at light strain, three when it is heavy. Centred on his head.
// Steps on a 30 fps timer and only while there is strain, so a calm machine
// costs nothing.
Item {
    id: sw
    required property var st
    property real spread: st.size * 0.5
    readonly property real level: st.world.sweat
    readonly property bool on: level > 0.05 && !st.sleeping && visible
    property real phase: 0
    Timer {
        interval: 33; repeat: true; running: sw.on
        onTriggered: sw.phase = (sw.phase + 0.033 / 1.7) % 1
    }
    Repeater {
        model: !sw.on ? 0 : sw.level > 0.55 ? 3 : sw.level > 0.25 ? 2 : 1
        Shape {
            required property int index
            readonly property real p: (sw.phase + index * 0.41) % 1
            readonly property real side: index === 1 ? -1 : 1
            x: side * (sw.spread + index * 2)
            y: -sw.st.size * 0.1 + p * sw.st.size * 0.42
            opacity: Math.sin(Math.min(1, p * 1.25) * Math.PI) * 0.95
            scale: sw.st.size / 58 * (index === 2 ? 1.05 : 1.3)
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#9ad8ff"
                strokeColor: Qt.rgba(1, 1, 1, 0.75)
                strokeWidth: 0.8
                startX: 0; startY: -6
                PathCubic { x: 0; y: 5; control1X: 3.6; control1Y: -1.2; control2X: 4.2; control2Y: 5 }
                PathCubic { x: 0; y: -6; control1X: -4.2; control1Y: 5; control2X: -3.6; control2Y: -1.2 }
            }
        }
    }
}
