import QtQuick
import QtQuick.Shapes

// A character as drawn. Placed with its feet at (0, 0) of the parent;
// everything comes from its state `st` and the shared `world`.
//   kuro   dark glass ball, two long eyes
//   mochi  rice cake with a face, a leaf on top
//   shiro  light ball, two long eyes
//   momo   peach with a leaf and a seam, long eyes
//   robo   small robot, rounded square with an antenna, eyes glowing on a screen
//   bao    steamed bun with pleats on top, a face like Mochi's
Item {
    id: root
    required property var st
    readonly property var world: st.world
    readonly property bool cake: st.skin === "mochi" || st.skin === "bao"
    readonly property bool cloud: st.skin === "kumo"
    readonly property bool glass: st.skin === "kuro"
    readonly property bool robo: st.skin === "robo"
    readonly property bool face: st.cakeFace
    readonly property real w: st.size
    readonly property real h: st.bodyH

    readonly property var looks: ({
        mochi: { top: "#fffaf3", mid: "#f6ebdf", bottom: "#e9d8c8", rim: Qt.rgba(0.45, 0.33, 0.28, 0.35), eye: "#3a2a28", shine: 0.8 },
        kuro:  { top: "#47424e", mid: "#26232b", bottom: "#151318", rim: Qt.rgba(1, 1, 1, 0.10), eye: "#f4efe8", shine: 0.22 },
        shiro: { top: "#ffffff", mid: "#f3f0eb", bottom: "#dcd7cf", rim: Qt.rgba(0, 0, 0, 0.16), eye: "#2b2730", shine: 0.9 },
        momo:  { top: "#ffd9c2", mid: "#ffa98f", bottom: "#ee7d6c", rim: Qt.rgba(0.55, 0.2, 0.15, 0.3), eye: "#4a2323", shine: 0.55 },
        robo:  { top: "#d9dde3", mid: "#a9b1bc", bottom: "#7f8996", rim: Qt.rgba(0, 0, 0, 0.25), eye: "#ffffff", shine: 0.6 },
        bao:   { top: "#fffef9", mid: "#f7f0e2", bottom: "#e6d9c2", rim: Qt.rgba(0.45, 0.36, 0.25, 0.3), eye: "#3a2a28", shine: 0.75 },
        neko:  { top: "#ffe2c2", mid: "#f7b47a", bottom: "#e48f52", rim: Qt.rgba(0.5, 0.28, 0.12, 0.3), eye: "#3b2a22", shine: 0.6 },
        kumo:  { top: "#ffffff", mid: "#f1f6fc", bottom: "#d6e2f0", rim: Qt.rgba(0.3, 0.4, 0.55, 0.22), eye: "#34404f", shine: 0.85 },
        tako:  { top: "#ffb0ba", mid: "#ff7f8f", bottom: "#e85d72", rim: Qt.rgba(0.55, 0.15, 0.2, 0.3), eye: "#4a1f27", shine: 0.6 },
        hiyoko: { top: "#fff6b8", mid: "#ffdf5c", bottom: "#f6bf2f", rim: Qt.rgba(0.55, 0.4, 0.05, 0.3), eye: "#3a2a12", shine: 0.7 },
        arai:  { top: "#d6d6dc", mid: "#a6a6b0", bottom: "#7a7a85", rim: Qt.rgba(0, 0, 0, 0.25), eye: "#f6f1ea", shine: 0.45 }
    })
    // with a colour of his own (setting "tint") the gradient comes from it
    readonly property var look: st.tinted
        ? { top: Qt.lighter(st.tint, 1.35), mid: st.tint, bottom: Qt.darker(st.tint, 1.45),
            rim: "transparent", eye: world.inkFor(st.tint), shine: 0.5 }
        : looks[st.skin] || looks.mochi

    readonly property real bodyY: -h - st.lift - st.hover + st.sink * (h + 14)

    // soft shadow on the floor, smaller the higher he is
    Rectangle {
        width: root.w * 0.9 * (1 - Math.min(root.st.lift + root.st.hover, 60) / 120)
        height: 7
        radius: 3.5
        x: -width / 2
        y: -3.5
        color: "black"
        // up in the air (hanging, climbing, flying) the sky draws it on the
        // floor instead (FloorShadow in shell.qml)
        visible: root.st.place !== "sky"
        opacity: 0.22 * (1 - root.st.sink) * (1 - Math.min(root.st.lift + root.st.hover, 60) / 90)
    }

    // ── hands: two small balls that follow the body a little late ──
    component Hand: Rectangle {
        id: hand
        property real side: -1
        property real tx: 0
        property real ty: 0
        property real k: 0               // holding on to a spot on the screen (st.gripKL/KR)
        width: root.w * 0.22; height: width; radius: width / 2
        x: tx - width / 2
        y: ty - height / 2
        // a short overshooting catch-up; SpringAnimation never settled here and kept
        // both windows redrawing at ~35 fps
        // (not while juggling: there they must be exactly where the balls are)
        Behavior on tx { enabled: !root.st.juggling && hand.k === 0 && root.st.lift < 1; NumberAnimation { duration: 170; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
        Behavior on ty { enabled: !root.st.juggling && hand.k === 0 && root.st.lift < 1; NumberAnimation { duration: 170; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
        // in front of his body they would vanish in it: a line in the eye colour around them
        readonly property bool overBody: root.st.handsFront || root.st.juggling
        visible: root.world.hands && root.st.handsOut > 0.02 && root.st.tuck < 0.98 && root.st.sink < 0.9
        z: overBody ? 3 : 0
        scale: root.st.handsOut * (1 - root.st.tuck)
        // the cloud's hands are as see-through as the cloud
        opacity: root.cloud ? 0.8 : 1
        // the same stuff as the body: glass as clear as his, rounder towards
        // the bottom, and a small spot of light
        color: root.glass ? root.st.glassFill : root.look.mid
        border.width: overBody ? 1.6 : root.world.ring || !root.glass ? 1 : 0
        border.color: overBody ? (root.glass ? root.world.alpha(root.st.glassInk, 0.75) : Qt.darker(root.look.mid, 1.35))
                    : root.world.ring ? root.world.alpha(root.world.primary, 0.7) : root.look.rim
        Rectangle {
            anchors.fill: parent
            anchors.margins: 0.5
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, root.glass ? 0.08 : 0.18) }
                GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, root.glass ? 0.28 : 0.12) }
            }
        }
        Rectangle {
            x: parent.width * 0.2; y: parent.height * 0.16
            width: parent.width * 0.36; height: width * 0.62
            radius: height / 2
            rotation: -26
            color: "white"
            opacity: root.glass ? 0.5 : root.look.shine * 0.8
        }
    }
    // a hand that holds on (k 1) sits on its spot on the screen, however the
    // body turns or moves under it (st.gripL / gripR are the offsets for that)
    Hand {
        side: -1
        k: root.st.gripL ? root.st.gripKL : 0
        tx: -root.w * (0.36 + 0.2 * root.st.handsOut) * root.st.sx + (k > 0 ? root.st.handLX + (root.st.gripL.x - root.st.handLX) * k : root.st.handLX)
        ty: root.bodyY + root.h * 0.66 + (k > 0 ? root.st.handLY + (root.st.gripL.y - root.st.handLY) * k : root.st.handLY) + root.st.lift * 0.18
    }
    Hand {
        side: 1
        k: root.st.gripR ? root.st.gripKR : 0
        tx: root.w * (0.36 + 0.2 * root.st.handsOut) * root.st.sx + (k > 0 ? root.st.handRX + (root.st.gripR.x - root.st.handRX) * k : root.st.handRX)
        ty: root.bodyY + root.h * 0.66 + (k > 0 ? root.st.handRY + (root.st.gripR.y - root.st.handRY) * k : root.st.handRY) - root.st.lift * 0.12
    }

    // the grappling gun in his right hand, pointing where he aims (gunAim, 0 up)
    Item {
        visible: root.st.gun > 0.02
        x: root.w * (0.36 + 0.2 * root.st.handsOut) * root.st.sx + root.st.handRX
        y: root.bodyY + root.h * 0.66 + root.st.handRY
        scale: root.st.gun * root.w / 58 * 1.45
        rotation: root.st.gunAim
        z: 2
        // grip, body, barrel, and the hook waiting at the muzzle; light metal,
        // so it shows on Kuro's dark glass too
        Rectangle { x: -3; y: -2; width: 6; height: 10; radius: 2; color: "#8a929d"; border.width: 1; border.color: "#3b3f46" }
        Rectangle { x: -5; y: -10; width: 10; height: 10; radius: 3; color: "#c3c9d1"; border.width: 1; border.color: "#3b3f46" }
        Rectangle { x: -2.5; y: -20; width: 5; height: 11; radius: 2; color: "#a3abb6"; border.width: 1; border.color: "#3b3f46" }
        Rectangle { x: -4; y: -6; width: 8; height: 2; radius: 1; color: root.world.primary }
        // the hook waiting at the muzzle, its prongs pointing ahead
        Shape {
            visible: !root.st.rope
            y: -21
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "#d4d9e0"; strokeWidth: 1.6; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: -4; startY: -4
                PathQuad { x: 0; y: 1; controlX: -4; controlY: 1 }
                PathQuad { x: 4; y: -4; controlX: 4; controlY: 1 }
            }
        }
    }

    // a banana in the free hand (oneHand: 1 the right holds, so the left is free)
    Item {
        id: nana
        visible: root.st.bananaOut
        readonly property bool inLeft: root.st.oneHand >= 0
        x: inLeft ? -root.w * (0.36 + 0.2 * root.st.handsOut) * root.st.sx + root.st.handLX
                : root.w * (0.36 + 0.2 * root.st.handsOut) * root.st.sx + root.st.handRX
        y: root.bodyY + root.h * 0.66 + (inLeft ? root.st.handLY : root.st.handRY)
        scale: root.w / 58
        rotation: inLeft ? 25 : -25
        z: 2
        // the fruit, shorter with every bite
        Shape {
            visible: root.st.banana > 0.02
            preferredRendererType: Shape.CurveRenderer
            readonly property real len: 4 + 14 * root.st.banana
            ShapePath {
                fillColor: root.st.peeled > 0.5 ? "#fbf1c7" : "#ffd23f"
                strokeColor: root.st.peeled > 0.5 ? "#d9c58d" : "#c99a16"; strokeWidth: 1
                startX: -2; startY: 0
                PathQuad { x: 0; y: -parent.len; controlX: -6; controlY: -parent.len * 0.5 }
                PathQuad { x: 3; y: 0; controlX: 1; controlY: -parent.len * 0.5 }
                PathLine { x: -2; y: 0 }
            }
        }
        // the peel: three flaps hanging down from his hand as it opens
        Repeater {
            model: 3
            Rectangle {
                required property int index
                visible: root.st.peeled > 0.05
                width: 4; height: 11; radius: 2
                x: -2; y: 0
                color: "#ffd23f"
                border.width: 0.8; border.color: "#c99a16"
                transformOrigin: Item.Top
                rotation: (index - 1) * 38 * root.st.peeled
            }
        }
    }

    // seeds on the floor in front of Hiyoko, fewer with every peck
    Item {
        visible: root.st.snackOut && root.st.snackKind === "seeds"
        x: root.st.peckDir * root.w * 0.62
        y: -2
        Repeater {
            model: 4
            Rectangle {
                required property int index
                visible: index < Math.ceil(root.st.snack * 4)
                width: 4; height: 3; radius: 1.5
                x: (index - 1.5) * 4.5 - 2; y: -(index % 2) * 1.5 - 1.5
                color: "#c9a25a"; border.width: 0.5; border.color: "#8a6a2c"
            }
        }
    }
    // a snack held at his mouth, smaller with every bite
    Item {
        visible: root.st.snackOut && root.st.snack > 0.02 && root.st.snackKind !== "seeds"
        x: 0
        y: root.bodyY + root.h * 0.6
        scale: root.w / 58 * (0.55 + 0.45 * root.st.snack)
        z: 2
        // steamed bun: round and white with a little twist on top
        Rectangle {
            visible: root.st.snackKind === "bun"
            x: -9; y: -8; width: 18; height: 14; radius: 7
            // golden, so it shows against Bao's own white
            color: "#f1d9a8"; border.width: 1.2; border.color: "#a77b3f"
            Rectangle { x: 7; y: 1; width: 4; height: 3; radius: 1.5; color: "#c99a5b" }
        }
        // dango: three balls on a stick, pink, white, green
        Item {
            visible: root.st.snackKind === "dango"
            Rectangle { x: -0.8; y: -22; width: 1.6; height: 26; color: "#c9a26b" }
            Repeater {
                model: ["#a8d08d", "#fbf6ea", "#f5a3b7"]
                Rectangle {
                    required property string modelData
                    required property int index
                    visible: index >= 3 - Math.ceil(root.st.snack * 3)
                    x: -5.5; y: -21 + index * 7; width: 11; height: 11; radius: 5.5
                    color: modelData; border.width: 0.8; border.color: Qt.darker(modelData, 1.25)
                }
            }
        }
        // onigiri: a white triangle with a strip of nori
        Shape {
            visible: root.st.snackKind === "onigiri"
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#fbfbf6"; strokeColor: "#d9d9cf"; strokeWidth: 1; joinStyle: ShapePath.RoundJoin
                startX: 0; startY: -11
                PathLine { x: 9; y: 5 }
                PathLine { x: -9; y: 5 }
                PathLine { x: 0; y: -11 }
            }
            ShapePath {
                fillColor: "#2b3a2c"; strokeWidth: 0
                startX: -4; startY: 0
                PathLine { x: 4; y: 0 }
                PathLine { x: 4; y: 5 }
                PathLine { x: -4; y: 5 }
            }
        }
        // Neko's fish: a little blue-grey fish, tail and eye
        Shape {
            visible: root.st.snackKind === "fish"
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#8fb3d1"; strokeColor: "#4f7594"; strokeWidth: 1; joinStyle: ShapePath.RoundJoin
                startX: -10; startY: 0
                PathQuad { x: 6; y: 0; controlX: -2; controlY: -8 }
                PathLine { x: 11; y: -5 }
                PathLine { x: 11; y: 5 }
                PathLine { x: 6; y: 0 }
                PathQuad { x: -10; y: 0; controlX: -2; controlY: 8 }
            }
        }
        Rectangle { visible: root.st.snackKind === "fish"; x: -7; y: -1.5; width: 2.2; height: 2.2; radius: 1.1; color: "#26323d" }
        // Arai's berries: three, red and dark
        Repeater {
            model: root.st.snackKind === "berries" ? [[-5, 0, "#d1344b"], [1, -3, "#7a2440"], [5, 2, "#d1344b"]] : []
            Rectangle {
                required property var modelData
                required property int index
                visible: index >= 3 - Math.ceil(root.st.snack * 3)
                x: modelData[0] - 4; y: modelData[1] - 4; width: 8; height: 8; radius: 4
                color: modelData[2]; border.width: 0.8; border.color: Qt.darker(modelData[2], 1.4)
            }
        }
        // Robo's oil can
        Item {
            visible: root.st.snackKind === "oil"
            Rectangle { x: -6; y: -10; width: 12; height: 15; radius: 2; color: "#c0392b"; border.width: 1; border.color: "#7b241c" }
            Rectangle { x: -6; y: -6; width: 12; height: 3; color: "#f1c40f" }
            Rectangle { x: 4; y: -15; width: 2; height: 7; rotation: 30; color: "#7f8c8d" }
        }
    }
    // three juggled balls: an arc each, a third of a cycle apart
    Repeater {
        model: root.st.juggling ? 3 : 0
        Rectangle {
            required property int index
            // p 0 … 0.5: from the left hand's throw to the right hand, 0.5 … 1 back
            // (the left hand throws when p = 0, the right one when p = 0.5)
            readonly property real p: (root.st.jugT / root.st.jugCycle + index / 3) % 1
            readonly property bool toRight: p < 0.5
            readonly property real u: toRight ? p * 2 : p * 2 - 1
            // where the hands are when they throw (Character.jugX/Y at q = 0), the ball on the palm
            z: 3
            readonly property real handX: -root.st.jugX(0)
            readonly property real handY: root.bodyY + root.h * 0.66 + root.st.jugY(0) - 6
            width: 9; height: 9; radius: 4.5
            color: ["#ff7aa2", "#ffd54a", "#7ad3ff"][index]
            border.width: 1; border.color: Qt.darker(color, 1.4)
            x: (toRight ? -1 : 1) * handX * (1 - 2 * u) - width / 2
            y: handY - Math.sin(u * Math.PI) * root.h * (toRight ? 1.05 : 0.85) - height / 2
        }
    }
    // Robo's wrench, and sparks where it hits the frame
    Item {
        visible: root.st.tooling
        x: root.w * (0.36 + 0.2 * root.st.handsOut) * root.st.sx + root.st.handRX
        y: root.bodyY + root.h * 0.66 + root.st.handRY
        z: 2
        rotation: 30
        scale: root.w / 58
        Rectangle { x: -1.5; y: -2; width: 3; height: 15; radius: 1.5; color: "#aeb6bf"; border.width: 0.6; border.color: "#5d6d7e" }
        Rectangle { x: -4; y: 11; width: 8; height: 6; radius: 2; color: "#aeb6bf"; border.width: 0.6; border.color: "#5d6d7e" }
    }
    Repeater {
        model: root.st.tooling ? 6 : 0
        Rectangle {
            required property int index
            readonly property real p: (root.st.sparkT * 2.2 + index * 0.17) % 1
            readonly property real ang: (index * 47 % 140 - 70) * Math.PI / 180
            width: 3; height: 3; radius: 1.5
            color: index % 2 ? "#ffd54a" : "#ff9f43"
            x: root.w * 0.55 + Math.sin(ang) * p * 26
            y: -3 - Math.cos(ang) * p * 22 + p * p * 14
            opacity: 1 - p
        }
    }

    // the body pivots on its feet for squash, on its centre for rolling
    Item {
        id: body
        width: root.w
        height: root.h
        x: -width / 2
        y: root.bodyY
        transform: [
            Scale {
                // squashed against a side (melting into a bar): pivots on that side
                origin.x: body.width / 2 * (1 + root.st.squashSide); origin.y: body.height
                xScale: root.st.sx * (1 - root.st.breath * 0.012)
                yScale: root.st.sy * (1 + root.st.breath * 0.025)
            },
            Rotation { origin.x: body.width / 2; origin.y: body.height; angle: root.st.lean },
            Rotation { origin.x: body.width / 2; origin.y: body.height / 2; angle: root.st.rot },
            Translate { x: root.st.tremble }
        ]

        // the leaf lags behind the body, like a hat that arrives late
        Item {
            id: leafItem
            visible: root.st.skin === "mochi" || root.st.skin === "momo"
            // green when he is in the accent colour himself
            readonly property color leaf: root.st.skin === "momo" || root.st.tinted && root.st.tintMode === "accent" ? "#6fae5c" : root.world.primary
            x: body.width * 0.5
            y: 3
            property real sway: 0
            property real target: -root.st.lean * 1.6 + (root.st.moving ? -Math.sign(root.st.gazeX) * 14 : 0)
            onTargetChanged: sway = target
            Behavior on sway { SpringAnimation { spring: 3.2; damping: 0.16; epsilon: 0.2 } }
            rotation: sway
            Shape {
                x: -2; y: -19
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 0
                    fillColor: leafItem.leaf
                    startX: 2; startY: 19
                    PathCubic { x: 15; y: 0; control1X: 0; control1Y: 6; control2X: 6; control2Y: -1 }
                    PathCubic { x: 2; y: 19; control1X: 17; control1Y: 9; control2X: 10; control2Y: 17 }
                }
                ShapePath {
                    strokeWidth: 1.2
                    strokeColor: Qt.darker(leafItem.leaf, 1.5)
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: 3; startY: 18
                    PathQuad { x: 12; y: 4; controlX: 6; controlY: 9 }
                }
            }
        }

        // the robot's antenna, swaying a little late like the leaf
        Item {
            visible: root.robo
            x: body.width * 0.5
            y: 1
            property real sway: 0
            property real target: -root.st.lean * 1.4 + (root.st.moving ? -Math.sign(root.st.gazeX) * 12 : 0)
            onTargetChanged: sway = target
            Behavior on sway { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 } }
            rotation: sway
            Rectangle { x: -1.2; y: -13; width: 2.4; height: 14; radius: 1.2; color: "#7f8996" }
            Rectangle {
                x: -4; y: -19; width: 8; height: 8; radius: 4
                color: root.world.primary
                border.width: 1; border.color: Qt.darker(root.world.primary, 1.4)
            }
        }

        // ears, tails, the cloud's bumps: behind the body
        SkinBack { st: root.st; look: root.look; w: body.width; h: body.height }

        // Kumo: one outline of four arcs (so it can be see-through without
        // the overlaps showing), light, with niri's blur behind (shell.qml)
        Shape {
            id: cloudShape
            visible: root.cloud
            preferredRendererType: Shape.CurveRenderer
            readonly property real u: body.width
            opacity: 0.86
            ShapePath {
                strokeColor: root.world.ring ? root.world.alpha(root.world.primary, 0.7) : root.look.rim
                strokeWidth: 1
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: 0; y2: body.height
                    GradientStop { position: 0.0; color: Qt.alpha(root.look.top, 0.92) }
                    GradientStop { position: 0.7; color: Qt.alpha(root.look.mid, 0.82) }
                    GradientStop { position: 1.0; color: Qt.alpha(root.look.bottom, 0.8) }
                }
                startX: 0.2 * cloudShape.u; startY: 0.7 * cloudShape.u
                PathArc { x: 0.1614 * cloudShape.u; y: 0.3038 * cloudShape.u; radiusX: 0.2 * cloudShape.u; radiusY: radiusX }
                PathArc { x: 0.571 * cloudShape.u; y: 0.1388 * cloudShape.u; radiusX: 0.25 * cloudShape.u; radiusY: radiusX }
                PathArc { x: 0.8779 * cloudShape.u; y: 0.3702 * cloudShape.u; radiusX: 0.22 * cloudShape.u; radiusY: radiusX }
                PathArc { x: 0.82 * cloudShape.u; y: 0.7 * cloudShape.u; radiusX: 0.17 * cloudShape.u; radiusY: radiusX }
                PathLine { x: 0.2 * cloudShape.u; y: 0.7 * cloudShape.u }
            }
        }
        Rectangle {
            visible: !root.glass && !root.cloud
            anchors.fill: parent
            radius: root.cake ? height * 0.47 : root.robo ? width * 0.3 : width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.look.top }
                GradientStop { position: 0.75; color: root.look.mid }
                GradientStop { position: 1.0; color: root.look.bottom }
            }
            border.width: 1
            border.color: root.world.ring ? root.world.alpha(root.world.primary, 0.7) : root.look.rim
        }
        // kuro is glass like the terminal: the window tint at the frame opacity,
        // niri blurs what is behind (blur region in shell.qml), and a soft spot
        // of light; the accent ring like the focus ring only when wanted
        Rectangle {
            visible: root.glass
            anchors.fill: parent
            radius: width / 2
            color: root.st.glassFill
            border.width: root.world.ring ? 1 : 0
            border.color: root.world.alpha(root.world.primary, 0.7)
            // darker towards the bottom, so it reads as a ball and not a disc
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.07) }
                    GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.28) }
                }
            }
        }
        // the spot of light: a soft halo with a brighter core
        Rectangle {
            visible: root.glass
            x: body.width * 0.17; y: body.height * 0.12
            width: body.width * 0.36; height: body.height * 0.24
            radius: height / 2
            rotation: -28
            color: "white"
            opacity: 0.10
        }
        Rectangle {
            visible: !root.cloud
            x: body.width * 0.2; y: body.height * (root.cake ? 0.12 : 0.15)
            width: body.width * 0.22; height: body.height * 0.11
            radius: height / 2
            rotation: -24
            color: "white"
            opacity: root.glass ? 0.5 : root.look.shine
        }

        // the peach's seam
        Shape {
            visible: root.st.skin === "momo"
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.rgba(0.6, 0.22, 0.16, 0.35); strokeWidth: 1.4
                fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: body.width * 0.5; startY: body.height * 0.06
                PathQuad { x: body.width * 0.44; y: body.height * 0.4; controlX: body.width * 0.38; controlY: body.height * 0.2 }
            }
        }
        // the bun's pleats, gathered at the top
        Shape {
            visible: root.st.skin === "bao"
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.rgba(0.55, 0.45, 0.32, 0.45); strokeWidth: 1.3
                fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: body.width * 0.5; startY: body.height * 0.04
                PathQuad { x: body.width * 0.3; y: body.height * 0.2; controlX: body.width * 0.36; controlY: body.height * 0.06 }
                PathMove { x: body.width * 0.5; y: body.height * 0.04 }
                PathQuad { x: body.width * 0.7; y: body.height * 0.2; controlX: body.width * 0.64; controlY: body.height * 0.06 }
                PathMove { x: body.width * 0.5; y: body.height * 0.04 }
                PathQuad { x: body.width * 0.44; y: body.height * 0.22; controlX: body.width * 0.44; controlY: body.height * 0.1 }
                PathMove { x: body.width * 0.5; y: body.height * 0.04 }
                PathQuad { x: body.width * 0.57; y: body.height * 0.22; controlX: body.width * 0.57; controlY: body.height * 0.1 }
            }
        }
        // the robot's face is a dark screen
        Rectangle {
            visible: root.robo
            x: body.width * 0.16; y: body.height * 0.26
            width: body.width * 0.68; height: body.height * 0.44
            radius: height * 0.38
            color: "#1d2128"
            border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.4)
        }

        // whiskers, mask, beak, spots, legs, rain: on the body, under the eyes
        SkinFront { st: root.st; look: root.look; w: body.width; h: body.height }

        // red with rage: the colour rises from below
        Rectangle {
            readonly property real heat: !root.glass && !root.cloud && root.st.mood === "angry" && root.st.level >= 3 ? 1 : 0
            opacity: heat
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutQuad } }
            visible: opacity > 0.01
            anchors.fill: parent
            radius: root.cake ? height * 0.47 : root.robo ? width * 0.3 : width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 0.23, 0.19, 0.22) }
                GradientStop { position: 0.6; color: Qt.rgba(1, 0.23, 0.19, 0.5) }
                GradientStop { position: 1.0; color: Qt.rgba(0.9, 0.12, 0.1, 0.6) }
            }
        }
        // Shiro's bow, on the left of her head (the anger vein sits on the right)
        Item {
            id: bow
            visible: root.st.skin === "shiro"
            x: body.width * 0.2; y: body.height * 0.1
            rotation: -18
            readonly property color c: root.st.tinted ? Qt.lighter(root.world.primary, 1.1) : "#ff7aa2"
            // two loops as filled ellipses (one path with two loops through
            // the same point left one of them empty in the curve renderer)
            Repeater {
                model: [-1, 1]
                Rectangle {
                    required property int modelData
                    width: 9; height: 6.5; radius: height / 2
                    x: modelData * 4.6 - width / 2; y: -height / 2 + 0.5
                    rotation: modelData * 22
                    color: bow.c
                    border.width: 1; border.color: Qt.darker(bow.c, 1.35)
                }
            }
            Rectangle {
                width: 4.5; height: 4.5; radius: 2
                x: -2.25; y: -2.25
                color: Qt.darker(parent.c, 1.15)
            }
        }

        Face {
            visible: root.face
            st: root.st
            ink: root.st.tinted ? root.look.eye : "#3a2a28"
            x: body.width / 2
            y: body.height * 0.55
        }
        LongEyes {
            visible: !root.face
            st: root.st
            ink: root.robo ? root.world.primary : root.glass ? root.st.glassInk : root.look.eye
            lashes: root.st.skin === "shiro"
            x: body.width / 2
            y: body.height * (root.robo ? 0.48 : 0.47)
            scale: root.robo ? 0.78 : 1
        }
    }

    // a heart (kiss) or a star (high five) rising from between two
    Item {
        visible: root.st.popKind !== ""
        readonly property real p: root.st.popT
        readonly property bool star: root.st.popKind === "star"
        x: root.st.towards * root.w * 0.55
        y: root.bodyY + root.h * 0.25 - p * 34
        opacity: Math.min(1, (1 - p) * 2.2)
        scale: 0.6 + Math.min(1, p * 4) * (star ? 1 : 0.7)
        rotation: star ? p * 90 : Math.sin(p * Math.PI * 3) * 8
        Shape {
            visible: !parent.star
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#ff5d8f"; strokeColor: Qt.rgba(1, 1, 1, 0.8); strokeWidth: 1
                startX: 0; startY: 7
                PathCubic { x: 0; y: -3; control1X: -9; control1Y: 0; control2X: -6; control2Y: -9 }
                PathCubic { x: 0; y: 7; control1X: 6; control1Y: -9; control2X: 9; control2Y: 0 }
            }
        }
        Shape {
            visible: parent.star
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#ffd54a"; strokeColor: Qt.rgba(1, 1, 1, 0.8); strokeWidth: 1
                startX: 0; startY: -10
                PathQuad { x: 10; y: 0; controlX: 1.5; controlY: -1.5 }
                PathQuad { x: 0; y: 10; controlX: 1.5; controlY: 1.5 }
                PathQuad { x: -10; y: 0; controlX: -1.5; controlY: 1.5 }
                PathQuad { x: 0; y: -10; controlX: -1.5; controlY: -1.5 }
            }
        }
    }

    // sweat while the machine works hard, beside his head
    Sweat {
        st: root.st
        spread: root.w * 0.5
        x: 0
        y: root.bodyY + root.h * 0.22
        visible: root.st.sink < 0.6
    }

    // sleep: a "z" rising beside him, not above (the bubble lives above)
    Repeater {
        model: 2
        Text {
            required property int index
            readonly property real p: (root.st.zPhase + index * 0.5) % 1
            visible: root.st.sleeping && root.st.sink < 0.5 && root.world.sleepAnim
            text: "z"
            font.pixelSize: 20
            font.bold: true
            scale: 0.55 + p * 0.45
            transformOrigin: Item.BottomLeft
            color: root.world.dark ? "#ede0db" : "#3a2a28"
            opacity: Math.sin(p * Math.PI) * 0.85
            x: root.w * 0.38 + p * 16
            y: -root.h * 0.9 - p * 34
        }
    }
}
