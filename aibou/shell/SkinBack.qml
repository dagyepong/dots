import QtQuick
import QtQuick.Shapes

// What sits behind a figure's body: ears and tails (Neko, Arai). Lives in Creature's body item before the
// body itself, so it turns and squashes with it; (0, 0) is the body's top left.
Item {
    id: back
    required property var st
    required property var look
    property real w: 0
    property real h: 0
    readonly property string skin: st.skin
    readonly property real k: w / 58
    // like the leaf: lags a little behind the body
    property real sway: 0
    property real target: -st.lean * 1.4 + (st.moving ? -Math.sign(st.gazeX) * 10 : 0)
    onTargetChanged: sway = target
    Behavior on sway { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
    // a wag of the tail when he is glad (a few swings, then still again)
    property real wag: 0
    readonly property bool tailed: skin === "neko" || skin === "arai"
    readonly property bool glad: st.shownMood === "happy" || st.shownMood === "proud"
    onGladChanged: if (glad && tailed) wagAnim.restart()
    SequentialAnimation {
        id: wagAnim
        loops: 3
        NumberAnimation { target: back; property: "wag"; to: 1; duration: 140; easing.type: Easing.InOutSine }
        NumberAnimation { target: back; property: "wag"; to: -1; duration: 280; easing.type: Easing.InOutSine }
        NumberAnimation { target: back; property: "wag"; to: 0; duration: 140; easing.type: Easing.InOutSine }
    }
    readonly property color fur: look.mid
    readonly property color rim: look.rim === "transparent" ? Qt.darker(look.mid, 1.3) : look.rim

    // ── Neko: pointed ears, pink inside, and a curled tail on the right ──
    Repeater {
        model: back.skin === "neko" ? [-1, 1] : []
        Item {
            required property int modelData
            x: back.w * (0.5 + modelData * 0.26); y: back.h * 0.15
            rotation: modelData * 16 + back.sway * 0.6
            Shape {
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: back.fur; strokeColor: back.rim; strokeWidth: 1; joinStyle: ShapePath.RoundJoin
                    startX: -9 * back.k; startY: 5 * back.k
                    PathQuad { x: 0; y: -19 * back.k; controlX: -7 * back.k; controlY: -12 * back.k }
                    PathQuad { x: 9 * back.k; y: 5 * back.k; controlX: 7 * back.k; controlY: -12 * back.k }
                    PathLine { x: -9 * back.k; y: 5 * back.k }
                }
                ShapePath {
                    fillColor: "#ffb3c1"; strokeWidth: 0
                    startX: -4.5 * back.k; startY: 2 * back.k
                    PathQuad { x: 0; y: -12 * back.k; controlX: -3.5 * back.k; controlY: -7 * back.k }
                    PathQuad { x: 4.5 * back.k; y: 2 * back.k; controlX: 3.5 * back.k; controlY: -7 * back.k }
                }
            }
        }
    }
    Item {
        visible: back.skin === "neko"
        x: back.w * 0.84; y: back.h * 0.84
        rotation: 18 + back.wag * 26 + back.sway * 0.8
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: back.rim; strokeWidth: 7.6 * back.k; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: 0; startY: 0
                PathCubic { x: 9 * back.k; y: -30 * back.k; control1X: 20 * back.k; control1Y: -4 * back.k; control2X: 18 * back.k; control2Y: -24 * back.k }
            }
            ShapePath {
                strokeColor: back.fur; strokeWidth: 5.8 * back.k; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: 0; startY: 0
                PathCubic { x: 9 * back.k; y: -30 * back.k; control1X: 20 * back.k; control1Y: -4 * back.k; control2X: 18 * back.k; control2Y: -24 * back.k }
            }
        }
    }

    // ── Arai: round ears with dark insides, a ringed tail on the left ──
    Repeater {
        model: back.skin === "arai" ? [-1, 1] : []
        Rectangle {
            required property int modelData
            width: 15 * back.k; height: width; radius: width / 2
            x: back.w * (0.5 + modelData * 0.3) - width / 2; y: back.h * 0.1 - height / 2
            rotation: back.sway * 0.5
            color: back.fur; border.width: 1; border.color: back.rim
            Rectangle {
                width: parent.width * 0.5; height: width; radius: width / 2
                anchors.centerIn: parent; anchors.verticalCenterOffset: parent.height * 0.06
                color: "#45454f"
            }
        }
    }
    // a big bushy tail standing up behind him: one smooth outline, narrow
    // at his body, widest in the middle, round at the tip and a little bent;
    // the dark rings are bands of the same outline, so they fit it exactly
    Item {
        id: araiTail
        visible: back.skin === "arai"
        x: back.w * 0.2; y: back.h * 0.78
        rotation: -34 - back.wag * 20 + back.sway * 0.8
        readonly property real len: 52 * back.k
        // half the width at t (0 at his body … 1 the tip), and the bend
        function half(t) { return back.k * (4.5 + 6 * Math.sin(Math.PI * t * 0.75)) * Math.sqrt(Math.max(0, 1 - Math.pow(t, 6))) }
        function bend(t) { return -back.k * 7 * t * t }
        // the outline from t0 to t1: up the left side, back down the right
        function band(t0, t1) {
            const pts = [], n = Math.max(6, Math.round((t1 - t0) * 70))
            for (let i = 0; i <= n; i++) { const t = t0 + (t1 - t0) * i / n; pts.push(Qt.point(bend(t) - half(t), -t * len)) }
            for (let i = n; i >= 0; i--) { const t = t0 + (t1 - t0) * i / n; pts.push(Qt.point(bend(t) + half(t), -t * len)) }
            pts.push(pts[0])
            return pts
        }
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#c3c3cb"; strokeColor: Qt.rgba(0, 0, 0, 0.32); strokeWidth: 1; joinStyle: ShapePath.RoundJoin
                PathPolyline { path: araiTail.band(0, 1) }
            }
        }
        Repeater {
            model: [[0.2, 0.33], [0.46, 0.59], [0.71, 0.82], [0.9, 1]]
            Shape {
                required property var modelData
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "#3f3f49"; strokeWidth: 0
                    PathPolyline { path: araiTail.band(modelData[0], modelData[1]) }
                }
            }
        }
    }
}
