import QtQuick
import QtQuick.Shapes

// The minimal face: two long eyes and nothing else. Every mood is a shape
// of the eyes, in three levels for angry, sad, happy, scared and blush
// (st.level). Shiro has lashes in every mood (`lashes`). Centred on (0, 0).
Item {
    id: eyes
    required property var st
    property color ink: "white"
    property bool lashes: false
    readonly property real k: st.size / 58
    readonly property string mood: st.sleeping ? "asleep" : st.shownMood
    readonly property int lvl: st.level
    readonly property real gx: st.gazeX * 4 * k
    readonly property real gy: (st.thinking ? -0.9 : st.gazeY + (mood === "shy" || mood === "blush" && lvl === 1 || mood === "sad" && lvl === 1 ? 0.8 : 0)) * 3 * k

    // two short strokes out of the eye, outwards and up (or down)
    component Lashes: Shape {
        id: ls
        property real side: 1
        property real ax: 0
        property real ay: 0
        property bool down: false
        readonly property real d: down ? 1 : -1
        readonly property real l: 3.6 * eyes.k
        visible: eyes.lashes
        preferredRendererType: Shape.CurveRenderer
        // the second lash sits further down the outer edge (open) or further in (shut)
        readonly property real bx: down ? ax - side * 2.4 * eyes.k : ax + side * 0.6 * eyes.k
        readonly property real by: down ? ay : ay + 2.8 * eyes.k
        ShapePath {
            strokeColor: eyes.ink; strokeWidth: 1.5 * eyes.k
            fillColor: "transparent"; capStyle: ShapePath.RoundCap
            startX: ls.ax; startY: ls.ay
            PathLine { x: ls.ax + ls.side * ls.l * 0.6; y: ls.ay + ls.d * ls.l * 0.8 }
            PathMove { x: ls.bx; y: ls.by }
            PathLine { x: ls.bx + ls.side * ls.l * (ls.down ? 0.3 : 0.9); y: ls.by + ls.d * ls.l * (ls.down ? 0.95 : 0.45) }
        }
    }

    Repeater {
        model: [-1, 1]
        Item {
            id: eye
            required property int modelData
            readonly property real side: modelData
            x: side * 9.5 * eyes.k + eyes.gx
            y: eyes.gy

            // width and height for each mood; the lid squeezes the height
            readonly property real ew: ({ surprised: 7.5, smug: 6, sleepy: 8, asleep: 9, scared: 8 })[eyes.mood] || 6
            readonly property real eh: eyes.mood === "sad" ? [13, 9, 13, 11][eyes.lvl]
                : eyes.mood === "happy" ? 13
                : eyes.mood === "scared" ? [17, 13, 17, 19][eyes.lvl]
                : ({ surprised: 19, smug: 6.5, sleepy: 3.2, asleep: 2.6, shy: 11, blush: 11,
                     curious: side < 0 ? 18 : 12 })[eyes.mood] || 15
            readonly property bool arc: eyes.st.kissing || eyes.mood === "happy" && eyes.lvl >= 2 || eyes.mood === "proud" || eyes.mood === "blush" && eyes.lvl >= 2
            readonly property bool squeeze: eyes.mood === "strained" && !eyes.st.kissing
            readonly property bool frown: eyes.mood === "angry" && !eyes.st.kissing
            // fright from level 2: rings with a small pupil
            readonly property bool ring: eyes.mood === "scared" && eyes.lvl >= 2

            // the plain eye; also the ring of fright
            Rectangle {
                id: plain
                visible: !eye.arc && !eye.squeeze && !eye.frown
                width: eye.ew * eyes.k
                height: Math.max(2.2, eye.eh * eyes.k * (eyes.mood === "asleep" ? 1 : eyes.st.lid))
                x: -width / 2
                y: -height / 2 + (eyes.mood === "smug" ? 3 * eyes.k : 0) + (eyes.mood === "sad" ? 2 * eyes.k : 0)
                radius: width / 2
                rotation: eyes.mood === "sad" ? eye.side * [-14, -10, -14, -18][eyes.lvl] : 0
                color: eye.ring ? "transparent" : eyes.ink
                border.width: eye.ring ? 2 * eyes.k : 0
                border.color: eyes.ink
                Behavior on height { enabled: eyes.st.lid > 0.99; NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                Rectangle {
                    visible: eye.ring && eyes.st.lid > 0.5
                    width: (eyes.lvl >= 3 ? 2.2 : 3) * eyes.k; height: width; radius: width / 2
                    anchors.centerIn: parent
                    color: eyes.ink
                }
                // lashes at the outer top, or hanging down from a closed eye
                Lashes { side: eye.side;
                    readonly property bool shut: plain.height < 5 * eyes.k
                    ax: plain.width / 2 + eye.side * plain.width * 0.36
                    ay: shut ? plain.height : plain.height * 0.1
                    down: shut
                }
            }
            // anger: the top of each eye cut off towards the middle, like a frown,
            // deeper the angrier he is
            Shape {
                id: fr
                visible: eye.frown
                readonly property real w: 7 * eyes.k
                readonly property real h: (eyes.lvl >= 3 ? 13 : 14) * eyes.k * Math.max(0.3, eyes.st.lid)
                readonly property real cut: [3, 3, 6, 8][eyes.lvl] * eyes.k
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: eyes.ink
                    strokeColor: eyes.ink; strokeWidth: 1.2 * eyes.k
                    joinStyle: ShapePath.RoundJoin
                    // the outer top stays high, the inner top drops by `cut`
                    startX: -fr.w / 2; startY: -fr.h / 2 + (eye.side < 0 ? 0 : fr.cut)
                    PathLine { x: fr.w / 2; y: -fr.h / 2 + (eye.side < 0 ? fr.cut : 0) }
                    PathLine { x: fr.w / 2; y: fr.h / 2 - fr.w / 2 }
                    PathArc { x: -fr.w / 2; y: fr.h / 2 - fr.w / 2; radiusX: fr.w / 2; radiusY: fr.w / 2 }
                    PathLine { x: -fr.w / 2; y: -fr.h / 2 + (eye.side < 0 ? 0 : fr.cut) }
                }
                Lashes { side: eye.side; ax: eye.side * fr.w / 2; ay: -fr.h / 2 }
            }
            // strain: squeezed shut, > <
            Shape {
                visible: eye.squeeze
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: eyes.ink; strokeWidth: 3 * eyes.k
                    fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                    startX: eye.side * 3.5 * eyes.k; startY: -5 * eyes.k
                    PathLine { x: -eye.side * 3.5 * eyes.k; y: 0 }
                    PathLine { x: eye.side * 3.5 * eyes.k; y: 5 * eyes.k }
                }
                Lashes { side: eye.side; ax: eye.side * 3.5 * eyes.k; ay: -5 * eyes.k }
            }
            // joy: the eyes bend into arcs, rounder the happier he is
            Shape {
                id: arcShape
                visible: eye.arc
                readonly property real bend: (eyes.mood === "happy" && eyes.lvl >= 3 ? -8 : -6) * eyes.k
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: eyes.ink; strokeWidth: (eyes.mood === "happy" && eyes.lvl >= 3 ? 3.8 : 3.4) * eyes.k
                    fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: -4.5 * eyes.k; startY: 2.5 * eyes.k
                    PathQuad { x: 4.5 * eyes.k; y: 2.5 * eyes.k; controlX: 0; controlY: arcShape.bend }
                }
                Lashes { side: eye.side; ax: eye.side * 4.2 * eyes.k; ay: 1.6 * eyes.k }
            }
        }
    }

    FaceMarks {
        st: eyes.st
        k: eyes.k
        ex: 9.5 * eyes.k; ey: 0
        cx: 15 * eyes.k; cy: 9 * eyes.k
        headTop: -27 * eyes.k
        ownCheeks: true
    }
}
