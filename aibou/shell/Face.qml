import QtQuick
import QtQuick.Shapes

// Eyes, cheeks and mouth. Centred on (0, 0).
// Moods: neutral happy proud curious sleepy shy surprised sad smug angry strained
// scared blush; angry, sad, happy, scared and blush show in three levels (st.level)
Item {
    id: face
    required property var st
    readonly property real k: st.size / 68
    readonly property string mood: st.sleeping ? "asleep" : st.shownMood
    readonly property int lvl: st.level
    // closed in joy: ^ ^ (a little happy keeps the eyes open)
    readonly property bool arcs: st.kissing || mood === "happy" && lvl >= 2 || mood === "proud" || mood === "blush" && lvl >= 2
    readonly property real gx: st.gazeX * 3.2 * k
    readonly property real gy: (st.thinking ? -0.8 : st.gazeY + (mood === "shy" || mood === "blush" || mood === "sad" && lvl === 1 ? 0.7 : 0)) * 2.2 * k
    property color ink: "#3a2a28"

    // ── eyes ──────────────────────────────────────────────────────
    Repeater {
        model: [-1, 1]
        Item {
            id: eye
            required property int modelData
            readonly property real side: modelData
            readonly property real big: face.mood === "surprised" ? 1.35
                                      : face.mood === "curious" ? (side < 0 ? 1.2 : 0.9) : 1
            x: side * 11 * face.k + face.gx
            y: -4 * face.k + face.gy

            // open eye with a highlight; the lid squeezes it for blinking
            Rectangle {
                visible: !face.arcs && ["asleep", "sleepy", "smug", "strained", "scared"].indexOf(face.mood) < 0
                width: 7 * face.k * eye.big
                height: Math.max(1.6, 10 * face.k * eye.big * face.st.lid)
                x: -width / 2; y: -height / 2
                radius: width / 2
                color: face.ink
                Rectangle {
                    visible: face.st.lid > 0.6
                    width: parent.width * 0.42; height: width; radius: width / 2
                    x: parent.width * 0.48; y: parent.height * 0.14
                    color: "white"
                }
            }
            // fright: wide white eyes with small pupils, smaller the more he fears
            Rectangle {
                visible: face.mood === "scared"
                width: 8.5 * face.k; height: Math.max(1.6, 10.5 * face.k * face.st.lid)
                x: -width / 2; y: -height / 2
                radius: width / 2
                color: "white"
                border.width: 1.4 * face.k; border.color: face.ink
                Rectangle {
                    width: (face.lvl >= 3 ? 2.2 : face.lvl === 2 ? 3 : 4.2) * face.k; height: width; radius: width / 2
                    anchors.centerIn: parent
                    color: face.ink
                }
            }
            // half-closed: sleepy and smug
            Rectangle {
                visible: face.mood === "sleepy" || face.mood === "smug"
                width: 8 * face.k
                height: 4.5 * face.k * Math.max(face.st.lid, 0.3)
                x: -width / 2; y: -height / 2 + 1.5 * face.k
                radius: height / 2
                color: face.ink
            }
            // ^ ^ for joy and pride
            Shape {
                visible: face.arcs
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: face.ink; strokeWidth: 2.3 * face.k
                    fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                    startX: -4.5 * face.k; startY: 2.5 * face.k
                    PathLine { x: 0; y: -2.5 * face.k }
                    PathLine { x: 4.5 * face.k; y: 2.5 * face.k }
                }
            }
            // strain: squeezed shut, > <
            Shape {
                visible: face.mood === "strained"
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: face.ink; strokeWidth: 2.3 * face.k
                    fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                    startX: eye.side * 3.5 * face.k; startY: -3.5 * face.k
                    PathLine { x: -eye.side * 3.5 * face.k; y: 0 }
                    PathLine { x: eye.side * 3.5 * face.k; y: 3.5 * face.k }
                }
            }
            // asleep: a soft arc
            Shape {
                visible: face.mood === "asleep"
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: face.ink; strokeWidth: 2 * face.k
                    fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: -4.5 * face.k; startY: 0
                    PathQuad { x: 4.5 * face.k; y: 0; controlX: 0; controlY: 3.5 * face.k }
                }
            }
            // brows: sad and scared lean outwards, angry frown inwards,
            // steeper the stronger the feeling
            Rectangle {
                visible: face.mood === "sad" || face.mood === "angry" || face.mood === "scared"
                width: 7 * face.k; height: (face.lvl >= 3 ? 2.3 : 1.8) * face.k; radius: height / 2
                x: -width / 2
                y: (face.mood === "angry" ? -8 : face.mood === "scared" ? -10.5 : -9) * face.k
                rotation: eye.side * (face.mood === "angry" ? [-14, -14, -24, -32][face.lvl]
                                      : [10, 10, 18, 26][face.lvl])
                color: face.ink
            }
        }
    }

    // ── cheeks ────────────────────────────────────────────────────
    Repeater {
        model: [-1, 1]
        Rectangle {
            required property int modelData
            width: 9 * face.k; height: 5 * face.k; radius: height / 2
            x: modelData * 19 * face.k - width / 2 + face.gx * 0.4
            y: 2.5 * face.k
            scale: face.mood === "blush" ? 1.1 + face.lvl * 0.1 : 1
            // flushed when angry or straining, pale with fright
            color: face.mood === "angry" || face.mood === "strained" ? "#ff6f6f" : face.mood === "blush" ? "#ff6f97" : "#ff8fa3"
            opacity: face.mood === "blush" || face.mood === "shy" || face.mood === "angry" && face.lvl >= 2 || face.mood === "strained" ? 0.85
                   : face.mood === "scared" ? 0.12
                   : face.mood === "happy" || face.mood === "proud" ? 0.6 : 0.38
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }
    }

    // ── mouth ─────────────────────────────────────────────────────
    // furious: gritted teeth
    Rectangle {
        visible: face.mood === "angry" && face.lvl >= 3 && !face.st.thinking
        width: 11 * face.k; height: 6 * face.k; radius: 2 * face.k
        x: -width / 2 + face.gx * 0.5
        y: 6 * face.k - height / 2 + face.gy * 0.4
        color: "white"
        border.width: 1.3 * face.k; border.color: face.ink
        Rectangle { width: parent.width - 2; height: 1 * face.k; x: 1; anchors.verticalCenter: parent.verticalCenter; color: face.ink }
        Rectangle { width: 1 * face.k; height: parent.height; x: parent.width / 3; color: face.ink }
        Rectangle { width: 1 * face.k; height: parent.height; x: parent.width * 2 / 3; color: face.ink }
    }
    // terrified: the mouth wide open
    Rectangle {
        visible: face.mood === "scared" && face.lvl >= 3 && !face.st.thinking
        width: 6 * face.k; height: 7.5 * face.k; radius: 2.5 * face.k
        x: -width / 2 + face.gx * 0.5
        y: 6.5 * face.k - height / 2
        color: face.ink
    }
    Text {
        visible: !(face.mood === "angry" || face.mood === "scared") || face.lvl < 3 || face.st.thinking
        readonly property string glyph: face.mood === "happy" ? ["‿", "‿", "▽", "▽"][face.lvl]
            : face.mood === "sad" && face.lvl >= 3 ? "﹏"
            : face.mood === "scared" ? (face.lvl === 1 ? "~" : "o")
            : ({
            asleep: "‿", proud: "▽", surprised: "o", blush: "ω",
            sad: "︵", sleepy: "‿", smug: "ω", shy: "ω", curious: "o", angry: "︵", strained: "~",
            neutral: "ω" })[face.mood] || "ω"
        // a kiss: lips pursed
        text: face.st.thinking ? "~" : face.st.kissing ? "3" : glyph
        color: face.ink
        font.pixelSize: (face.mood === "curious" || face.mood === "surprised" || face.mood === "scared" ? 8
                       : face.mood === "happy" && face.lvl >= 3 ? 14 : 11) * face.k
        font.bold: true
        x: -width / 2 + face.gx * 0.5
        y: -height / 2 + 5.5 * face.k + face.gy * 0.4
    }

    FaceMarks {
        st: face.st
        k: face.k
        ex: 11 * face.k; ey: -4 * face.k
        cx: 19 * face.k; cy: 5 * face.k
        headTop: -31 * face.k
    }
}
