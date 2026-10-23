import QtQuick
import QtQuick.Shapes

// What sits on a figure's body, under its eyes: Neko's nose and whiskers,
// Arai's mask and muzzle, Hiyoko's beak and tuft, Tako's spots and the
// little legs along its bottom, the rain cloud over a sad Kumo. Lives in
// Creature's body item after the body; (0, 0) is the body's top left.
Item {
    id: front
    required property var st
    required property var look
    property real w: 0
    property real h: 0
    readonly property string skin: st.skin
    readonly property real k: w / 58
    readonly property string mood: st.sleeping ? "asleep" : st.shownMood

    // ── Neko: a small pink nose and whiskers ──
    Item {
        visible: front.skin === "neko"
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#ff8fa3"; strokeWidth: 0
                startX: front.w * 0.5 - 2.6 * front.k; startY: front.h * 0.6
                PathLine { x: front.w * 0.5 + 2.6 * front.k; y: front.h * 0.6 }
                PathLine { x: front.w * 0.5; y: front.h * 0.6 + 2.6 * front.k }
            }
            ShapePath {
                strokeColor: Qt.rgba(0.23, 0.16, 0.13, 0.4); strokeWidth: 1.1 * front.k
                fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: front.w * 0.3; startY: front.h * 0.62
                PathLine { x: front.w * 0.06; y: front.h * 0.58 }
                PathMove { x: front.w * 0.3; y: front.h * 0.67 }
                PathLine { x: front.w * 0.07; y: front.h * 0.7 }
                PathMove { x: front.w * 0.7; y: front.h * 0.62 }
                PathLine { x: front.w * 0.94; y: front.h * 0.58 }
                PathMove { x: front.w * 0.7; y: front.h * 0.67 }
                PathLine { x: front.w * 0.93; y: front.h * 0.7 }
            }
        }
    }

    // ── Arai: a light face with a dark band of a mask over the eyes, a
    // dark stripe up the forehead, light brows, a white muzzle and cheeks
    // and a black nose ──
    Item {
        visible: front.skin === "arai"
        // white cheeks and muzzle under the mask
        Repeater {
            model: [-1, 1]
            Rectangle {
                required property int modelData
                width: front.w * 0.3; height: front.h * 0.24; radius: height / 2
                x: front.w * (0.5 + modelData * 0.24) - width / 2; y: front.h * 0.58
                color: "#efedea"
            }
        }
        Rectangle {
            width: front.w * 0.44; height: front.h * 0.3; radius: height / 2
            x: front.w * 0.5 - width / 2; y: front.h * 0.52
            color: "#f4f2ef"
        }
        // the stripe up the forehead
        Rectangle {
            width: front.w * 0.08; height: front.h * 0.24; radius: width / 2
            x: front.w * 0.5 - width / 2; y: front.h * 0.06
            color: "#4a4a54"
        }
        // light brows over the mask
        Repeater {
            model: [-1, 1]
            Rectangle {
                required property int modelData
                width: front.w * 0.22; height: front.h * 0.065; radius: height / 2
                x: front.w * (0.5 + modelData * 0.21) - width / 2; y: front.h * 0.17
                rotation: modelData * -10
                color: "#f1efec"
            }
        }
        // the mask: one band, dipping under each eye, narrow over the nose
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#34343d"; strokeWidth: 0
                startX: front.w * 0.07; startY: front.h * 0.4
                PathQuad { x: front.w * 0.5; y: front.h * 0.36; controlX: front.w * 0.3; controlY: front.h * 0.2 }
                PathQuad { x: front.w * 0.93; y: front.h * 0.4; controlX: front.w * 0.7; controlY: front.h * 0.2 }
                PathQuad { x: front.w * 0.86; y: front.h * 0.66; controlX: front.w * 1.0; controlY: front.h * 0.56 }
                PathQuad { x: front.w * 0.58; y: front.h * 0.56; controlX: front.w * 0.72; controlY: front.h * 0.68 }
                PathQuad { x: front.w * 0.42; y: front.h * 0.56; controlX: front.w * 0.5; controlY: front.h * 0.5 }
                PathQuad { x: front.w * 0.14; y: front.h * 0.66; controlX: front.w * 0.28; controlY: front.h * 0.68 }
                PathQuad { x: front.w * 0.07; y: front.h * 0.4; controlX: front.w * 0.0; controlY: front.h * 0.56 }
            }
        }
        // the nose at the tip of the muzzle, a small mouth under it
        Rectangle {
            width: front.w * 0.13; height: width * 0.72; radius: height / 2
            x: front.w * 0.5 - width / 2; y: front.h * 0.62
            color: "#22222a"
            Rectangle { x: parent.width * 0.22; y: parent.height * 0.18; width: parent.width * 0.3; height: parent.height * 0.28; radius: height / 2; color: "white"; opacity: 0.35 }
        }
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "#5a5a63"; strokeWidth: 1.1 * front.k; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: front.w * 0.5; startY: front.h * 0.7
                PathLine { x: front.w * 0.5; y: front.h * 0.75 }
                PathQuad { x: front.w * 0.43; y: front.h * 0.76; controlX: front.w * 0.47; controlY: front.h * 0.79 }
                PathMove { x: front.w * 0.5; y: front.h * 0.75 }
                PathQuad { x: front.w * 0.57; y: front.h * 0.76; controlX: front.w * 0.53; controlY: front.h * 0.79 }
            }
        }
    }

    // ── Hiyoko: an orange beak and a little tuft on top ──
    Shape {
        visible: front.skin === "hiyoko"
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "#ff9f1c"; strokeColor: "#d27a08"; strokeWidth: 0.8; joinStyle: ShapePath.RoundJoin
            startX: front.w * 0.5 - 4.2 * front.k; startY: front.h * 0.6
            PathLine { x: front.w * 0.5; y: front.h * 0.6 - 3 * front.k }
            PathLine { x: front.w * 0.5 + 4.2 * front.k; y: front.h * 0.6 }
            PathLine { x: front.w * 0.5; y: front.h * 0.6 + 3.6 * front.k }
            PathLine { x: front.w * 0.5 - 4.2 * front.k; y: front.h * 0.6 }
        }
    }
    Item {
        visible: front.skin === "hiyoko"
        x: front.w * 0.5; y: front.h * 0.04
        property real sway: 0
        property real target: -front.st.lean * 1.6 + (front.st.moving ? -Math.sign(front.st.gazeX) * 14 : 0)
        onTargetChanged: sway = target
        Behavior on sway { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 3 } }
        rotation: sway
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.darker(front.look.mid, 1.15); strokeWidth: 2.2 * front.k
                fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: 0; startY: 2 * front.k
                PathQuad { x: -3 * front.k; y: -9 * front.k; controlX: -4 * front.k; controlY: -3 * front.k }
                PathMove { x: 0; y: 2 * front.k }
                PathQuad { x: 1.5 * front.k; y: -11 * front.k; controlX: 2.5 * front.k; controlY: -4 * front.k }
                PathMove { x: 0; y: 2 * front.k }
                PathQuad { x: 5 * front.k; y: -7 * front.k; controlX: 5 * front.k; controlY: -1 * front.k }
            }
        }
    }

    // ── Tako: darker spots on the head, little legs along the bottom ──
    Repeater {
        model: front.skin === "tako" ? [[0.27, 0.24, 2.8], [0.38, 0.12, 1.9], [0.72, 0.2, 2.4]] : []
        Rectangle {
            required property var modelData
            width: modelData[2] * 2 * front.k; height: width; radius: width / 2
            x: front.w * modelData[0] - width / 2; y: front.h * modelData[1] - height / 2
            color: Qt.darker(front.look.mid, 1.18); opacity: 0.55
        }
    }
    Repeater {
        model: front.skin === "tako" ? 5 : 0
        Rectangle {
            required property int index
            readonly property real d: front.w * 0.21
            width: d; height: d * 0.9; radius: height / 2
            x: front.w * (0.1 + index * 0.2) - d / 2
            // a small ripple along them while he breathes
            y: front.h - height * 0.92 + (index % 2 ? 1 : -1) * front.st.breath * 1.4 * front.k
            color: front.look.bottom
            border.width: 1; border.color: front.look.rim === "transparent" ? Qt.darker(front.look.bottom, 1.25) : front.look.rim
        }
    }

    // ── Tako, frightened: a puff of ink round its feet that fades ──
    property real ink: 0
    onMoodChanged: if (skin === "tako" && mood === "scared") inkAnim.restart()
    SequentialAnimation {
        id: inkAnim
        NumberAnimation { target: front; property: "ink"; from: 0; to: 0.35; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: front; property: "ink"; to: 1; duration: 1400; easing.type: Easing.OutQuad }
        ScriptAction { script: front.ink = 0 }
    }
    Repeater {
        model: front.skin === "tako" && front.ink > 0 ? [[-0.42, 0, 9], [-0.18, -0.05, 12], [0.12, -0.03, 11], [0.4, 0.02, 9], [0, 0.04, 14]] : []
        Rectangle {
            required property var modelData
            readonly property real grow: 0.5 + front.ink * 1.1
            width: modelData[2] * 2 * front.k * grow; height: width; radius: width / 2
            x: front.w * (0.5 + modelData[0] * (1 + front.ink * 0.6)) - width / 2
            y: front.h * (0.92 + modelData[1]) - height / 2 - front.ink * 6 * front.k
            color: "#2b2233"; opacity: (1 - front.ink) * 0.75
        }
    }

    // ── Kumo: sad, a little grey cloud rains on him; cross, it flashes ──
    Item {
        id: weather
        readonly property bool rain: front.skin === "kumo" && (front.mood === "sad" || front.mood === "angry" && front.st.level >= 2)
        readonly property bool flash: rain && front.mood === "angry"
        visible: rain
        x: front.w * 0.5; y: -front.h * 0.5
        property real t: 0
        NumberAnimation on t { running: weather.rain; from: 0; to: 1; duration: 700; loops: Animation.Infinite }
        Repeater {
            model: [[-9, 0, 7], [0, -4, 9], [9, 0, 7]]
            Rectangle {
                required property var modelData
                width: modelData[2] * 2 * front.k; height: width; radius: width / 2
                x: modelData[0] * front.k - width / 2; y: modelData[1] * front.k - height / 2
                color: weather.flash ? "#6e7686" : "#9aa4b4"
            }
        }
        Repeater {
            model: weather.flash ? 0 : 4
            Rectangle {
                required property int index
                readonly property real p: (weather.t + index * 0.27) % 1
                width: 2 * front.k; height: 5 * front.k; radius: width / 2
                x: (-10 + index * 6.5) * front.k; y: 6 * front.k + p * front.h * 0.42
                color: "#6fb7ff"; opacity: 1 - p * 0.7
            }
        }
        Shape {
            visible: weather.flash && weather.t < 0.5
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#ffd54a"; strokeColor: "#d6a400"; strokeWidth: 0.8; joinStyle: ShapePath.RoundJoin
                startX: 1 * front.k; startY: 5 * front.k
                PathLine { x: -4 * front.k; y: 15 * front.k }
                PathLine { x: 0; y: 15 * front.k }
                PathLine { x: -3 * front.k; y: 25 * front.k }
                PathLine { x: 5 * front.k; y: 12 * front.k }
                PathLine { x: 1 * front.k; y: 12 * front.k }
                PathLine { x: 4 * front.k; y: 5 * front.k }
            }
        }
    }
}
