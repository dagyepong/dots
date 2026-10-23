import QtQuick
import QtQuick.Shapes

// What a strong feeling adds to a face, by mood and level (st.level):
//   angry   2 an anger vein, 3 also a bubble of curses above his head
//   sad     3 tears running down
//   scared  1–3 a cold drop at the temple, 3 pale lines over the eyes
//   blush   1–3 hatched pink cheeks, 2–3 hearts rising
//   happy   3 sparkles around him
// Centred like the face it belongs to: `ex`, `ey` say where its eyes sit,
// `cx`, `cy` where its cheeks are, `headTop` where the head ends. Animated marks
// step on one 30 fps timer, and only while they show.
Item {
    id: m
    required property var st
    property real k: 1
    property real ex: 10
    property real ey: 0
    property real cx: 17
    property real cy: 8
    property real headTop: -28
    property bool ownCheeks: false       // the long-eyed faces have none of their own
    readonly property string mood: st.sleeping ? "asleep" : st.shownMood
    readonly property int lvl: st.level
    readonly property bool vein: mood === "angry" && lvl >= 2
    readonly property bool curse: mood === "angry" && lvl >= 3
    readonly property bool tears: mood === "sad" && lvl >= 3
    readonly property bool gloom: mood === "scared" && lvl >= 3
    readonly property bool cold: mood === "scared"
    readonly property bool blush: mood === "blush"
    readonly property bool hearts: mood === "blush" && lvl >= 2
    readonly property bool sparkles: mood === "happy" && lvl >= 3
    readonly property bool animated: vein && lvl >= 3 || curse || tears || hearts || sparkles
    property real phase: 0               // seconds, wraps at a minute
    Timer {
        interval: 33; repeat: true
        running: m.animated && m.visible && m.opacity > 0
        onTriggered: m.phase = (m.phase + 0.033) % 60
    }

    // ── cheeks of their own: shy, blushing, or red with rage ──────
    Repeater {
        model: m.ownCheeks ? [-1, 1] : []
        Rectangle {
            required property int modelData
            readonly property bool on: m.blush || m.mood === "shy" || m.mood === "happy" || m.mood === "proud" || m.mood === "angry" && m.lvl >= 3
            width: 8.5 * m.k * (m.blush ? 1 + m.lvl * 0.08 : 1); height: width * 0.55; radius: height / 2
            x: modelData * m.cx - width / 2
            y: m.cy - height / 2
            color: m.mood === "angry" ? "#ff5a5a" : "#ff7a9c"
            opacity: on ? (m.blush ? 0.55 + m.lvl * 0.12 : m.mood === "happy" || m.mood === "proud" ? 0.4 : 0.6) : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }
    }
    // blush: three short strokes over each cheek
    Repeater {
        model: m.blush ? [-1, 1] : []
        Shape {
            required property int modelData
            x: modelData * m.cx; y: m.cy
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "#e0456e"; strokeWidth: 1.2 * m.k
                fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: -3.2 * m.k; startY: 1.6 * m.k
                PathLine { x: -1.6 * m.k; y: -1.6 * m.k }
                PathMove { x: -0.4 * m.k; y: 1.6 * m.k }
                PathLine { x: 1.2 * m.k; y: -1.6 * m.k }
                PathMove { x: 2.4 * m.k; y: 1.6 * m.k }
                PathLine { x: 4 * m.k; y: -1.6 * m.k }
            }
        }
    }

    // ── anger: the vein, a cross of four bent strokes ─────────────
    Item {
        visible: m.vein
        x: m.ex * 1.35; y: m.headTop + 6 * m.k
        scale: m.k * (m.lvl >= 3 ? 1.15 + 0.12 * Math.sin(m.phase * Math.PI * 5) : 1)
        Repeater {
            model: 4
            Shape {
                required property int index
                rotation: index * 90
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "#e53935"; strokeWidth: 1.9
                    fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: 1.4; startY: -5
                    PathQuad { x: 5; y: -1.4; controlX: 1.6; controlY: -1.6 }
                }
            }
        }
    }
    // furious: curses in a bubble, changing every quarter second
    Item {
        visible: m.curse
        x: m.ex * 0.4; y: m.headTop - 6 * m.k
        readonly property var words: ["#@!", "%&!", "$#@!", "*!?#", "@#%!", "&%$!"]
        rotation: 5 * Math.sin(m.phase * Math.PI * 3)
        Rectangle {
            id: curseBox
            width: curseText.implicitWidth + 12; height: curseText.implicitHeight + 6
            x: -width * 0.15; y: -height
            radius: height / 2
            color: m.st.world.bubbleBg
            border.width: 1.5; border.color: "#e53935"
            Text {
                id: curseText
                anchors.centerIn: parent
                text: parent.parent.words[Math.floor(m.phase * 4) % parent.parent.words.length]
                color: "#e53935"
                font.pixelSize: Math.max(11, 12 * m.k)
                font.bold: true
            }
        }
        Rectangle {
            width: 6; height: 6; rotation: 45
            x: 3; y: -4
            color: m.st.world.bubbleBg
            border.width: 1.5; border.color: "#e53935"
            z: -1
        }
    }

    // ── tears: two drops down each cheek ──────────────────────────
    Repeater {
        model: m.tears ? 6 : 0
        Shape {
            required property int index
            readonly property real side: index % 2 ? 1 : -1
            readonly property real p: (m.phase * 1.1 + (index >> 1) * 0.33) % 1
            x: side * (m.ex + (1 + p * 2.5) * m.k)
            y: m.ey + 6 * m.k + p * 26 * m.k
            opacity: Math.sin(Math.min(1, p * 1.15) * Math.PI)
            scale: m.k * 1.3
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#7cc7ff"; strokeColor: Qt.rgba(1, 1, 1, 0.7); strokeWidth: 0.6
                startX: 0; startY: -5
                PathCubic { x: 0; y: 4; control1X: 3; control1Y: -1; control2X: 3.5; control2Y: 4 }
                PathCubic { x: 0; y: -5; control1X: -3.5; control1Y: 4; control2X: -3; control2Y: -1 }
            }
        }
    }

    // ── fright: pale lines over the eyes, a cold drop ─────────────
    Repeater {
        model: m.gloom ? 5 : 0
        Rectangle {
            required property int index
            readonly property real h: (index % 2 ? 7 : 10) * m.k
            width: 1.5 * m.k; height: h; radius: width / 2
            x: (index - 2) * m.ex * 0.55 - width / 2
            y: m.headTop + 3 * m.k
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0.42, 0.42, 0.86, 0.75) }
                GradientStop { position: 1; color: Qt.rgba(0.42, 0.42, 0.86, 0) }
            }
        }
    }
    Shape {
        visible: m.cold
        x: m.ex * 1.9; y: m.ey - 5 * m.k
        scale: m.k * (1 + m.lvl * 0.12)
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "#9ad8ff"; strokeColor: Qt.rgba(1, 1, 1, 0.75); strokeWidth: 0.8
            startX: 0; startY: -6
            PathCubic { x: 0; y: 5; control1X: 3.6; control1Y: -1.2; control2X: 4.2; control2Y: 5 }
            PathCubic { x: 0; y: -6; control1X: -4.2; control1Y: 5; control2X: -3.6; control2Y: -1.2 }
        }
    }

    // ── hearts rising when he blushes ─────────────────────────────
    Repeater {
        model: m.hearts ? (m.lvl >= 3 ? 3 : 2) : 0
        Shape {
            required property int index
            readonly property real p: (m.phase * 0.7 + index * 0.37) % 1
            readonly property real side: index % 2 ? -1 : 1
            x: side * m.ex * (1.2 + index * 0.3) + Math.sin((p + index) * Math.PI * 2) * 3 * m.k
            y: m.headTop - p * 22 * m.k
            opacity: Math.sin(p * Math.PI)
            scale: m.k * (0.7 + p * 0.5)
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#ff5d8f"; strokeColor: Qt.rgba(1, 1, 1, 0.6); strokeWidth: 0.6
                startX: 0; startY: 5
                PathCubic { x: 0; y: -2; control1X: -6; control1Y: 0; control2X: -4; control2Y: -6 }
                PathCubic { x: 0; y: 5; control1X: 4; control1Y: -6; control2X: 6; control2Y: 0 }
            }
        }
    }

    // ── sparkles of great joy ─────────────────────────────────────
    Repeater {
        model: m.sparkles ? [[-2.5, -0.3], [2.4, -0.9], [-1.7, -1.5], [1.9, 0.6]] : []
        Shape {
            required property var modelData
            required property int index
            x: modelData[0] * m.ex
            y: modelData[1] < 0 ? m.headTop * -modelData[1] * 0.8 : m.ey + modelData[1] * 10 * m.k
            scale: m.k * 1.5 * Math.max(0, Math.sin((m.phase * 1.6 + index * 0.27) * Math.PI * 2))
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#ffd54a"; strokeWidth: 0
                startX: 0; startY: -6
                PathQuad { x: 6; y: 0; controlX: 1; controlY: -1 }
                PathQuad { x: 0; y: 6; controlX: 1; controlY: 1 }
                PathQuad { x: -6; y: 0; controlX: -1; controlY: 1 }
                PathQuad { x: 0; y: -6; controlX: -1; controlY: -1 }
            }
        }
    }
}
