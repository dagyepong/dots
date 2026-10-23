import QtQuick
import QtQuick.Shapes

// A character melted into the screen frame: only a dome with eyes rises out
// of the frame's inner edge, joined to it by two soft fillets, like a drop of
// the frame itself. Placed with (0, 0) on the frame edge under his centre.
// By default every figure takes the frame's colour and blends in (setting
// "dockTint"); in a bar he can also leave the bar flat and only show his face
// inside it (setting "barStyle").
Item {
    id: root
    required property var st
    readonly property var world: st.world
    readonly property bool frameTint: world.dockTint === "frame"
    // DMS draws this dome as part of its frame: only the face is his
    readonly property bool hosted: world.frameHost && frameTint && !flat && (st.dockShift <= 0 || world.frameOffsets)
                                   && st.slot < world.frameDomes
    readonly property bool glass: frameTint || st.glass
    // only the face, inside the bar: nothing sticks out
    readonly property bool flat: (turn === 90 || turn === -90) && world.barFlat && st.dockSide === "bar"
    // out of the bar for a moment while it is measured without the faces
    opacity: flat && world.barHide ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: 180 } }
    readonly property real barWidth: turn > 0 ? world.insets.left : world.insets.right
    readonly property var look: ({
        mochi: { fill: "#f6ebdf", top: "#fffaf3", eye: "#3a2a28" },
        kuro:  { fill: "#26232b", top: "#47424e", eye: "#f4efe8" },
        shiro: { fill: "#f3f0eb", top: "#ffffff", eye: "#2b2730" },
        momo:  { fill: "#ffa98f", top: "#ffd9c2", eye: "#4a2323" },
        robo:  { fill: "#a9b1bc", top: "#d9dde3", eye: "#1d2128" },
        bao:   { fill: "#f7f0e2", top: "#fffef9", eye: "#3a2a28" }
    })[st.skin] || ({ fill: "#26232b", top: "#47424e", eye: "#f4efe8" })

    readonly property real rise: st.dockRise
    // 0: the dome points up out of the bottom frame; 90 / -90: sideways out
    // of a bar on the left / right. The eyes stay upright.
    property real turn: 0
    readonly property real k: st.size / 58
    // dome half width, height, fillet width; the breath swells it a little
    readonly property real bw: st.size * 0.6 * (1 + st.breath * 0.015)
    // sideways the eyes sit next to each other across the dome, so it bulges further
    readonly property bool across: turn === 90 || turn === -90
    // the beat swells his own dome; one DMS draws stays as it is, so then
    // only the face moves (pulseHop) and flashes (pulseScale)
    readonly property real dh: st.size * (across ? 0.66 : 0.46) * rise * (1 + st.breath * 0.04 + (hosted ? 0 : st.pulse * 0.4))
    readonly property real pulseHop: st.pulse * st.size * (hosted ? 0.04 : 0.06)
    readonly property real pulseScale: 1 + (hosted ? st.pulse * 0.25 : 0)
    readonly property real f: st.size * 0.3 * Math.min(1, rise)

    // in the frame's colour: what the frame or bar really shows right beside him
    // (measured, opaque), until then its colour at its transparency. Glass over
    // a light window would look grey, the bar beside it shows the wallpaper.
    // the foot of the outline, on the frame's edge
    // exactly on it: half a pixel further in, frame glass and his would lie
    // on top of each other there and draw a dark hairline
    readonly property real foot: 0
    // where niri blurs (xray) under him: twelve slices that follow the dome's
    // outline from inside, so no wallpaper shows beside it (blur region in shell.qml)
    readonly property bool blurred: glass && !hosted && st.place === "dock" && !flat && rise > 0.05
    function sliceHalf(k) {
        const yt = -dh * Math.min(0.97, (k + 1) / 12)
        const x = crossAt(yt)
        return isNaN(x) ? 0 : -x
    }
    // the dome lives on its own surface with niri's xray blur: behind it the
    // blurred wallpaper, as behind the frame, so the frame's glass colour
    // matches at once, whatever window lies under him
    readonly property color fill: frameTint ? world.alpha(world.frameColor, world.glassOpacity)
        : st.glass ? st.glassFill
        : st.tinted ? st.tint : look.fill
    readonly property color ink: frameTint ? world.inkFor(world.frameColor)
        : st.tinted ? world.inkFor(st.tint) : look.eye

    visible: rise > 0.01
    readonly property var slices: [sl0, sl1, sl2, sl3, sl4, sl5, sl6, sl7, sl8, sl9, sl10, sl11]

    // a point of the left half of the outline, t from 0 (foot) to 2 (top)
    function outline(t) {
        const c = t <= 1
            ? [[-bw - f, 0.5], [-bw - f * 0.3, 0], [-bw * 0.99, -dh * 0.1], [-bw * 0.93, -dh * 0.34]]
            : [[-bw * 0.93, -dh * 0.34], [-bw * 0.86, -dh * 0.86], [-bw * 0.52, -dh], [0, -dh]]
        const u = t <= 1 ? t : t - 1, v = 1 - u
        const b = [v * v * v, 3 * v * v * u, 3 * v * u * u, u * u * u]
        return [b[0] * c[0][0] + b[1] * c[1][0] + b[2] * c[2][0] + b[3] * c[3][0],
                b[0] * c[0][1] + b[1] * c[1][1] + b[2] * c[2][1] + b[3] * c[3][1]]
    }
    // where the outline crosses height y (local, negative upwards): x < 0, or NaN
    function crossAt(y) {
        if (-dh < y) {
            let prev = outline(0)
            for (let i = 1; i <= 80; i++) {
                const p = outline(i / 40)
                if (p[1] <= y) return prev[0] + (p[0] - prev[0]) * (y - prev[1]) / (p[1] - prev[1] || 1)
                prev = p
            }
        }
        return NaN
    }

    Item {
    visible: !root.flat && !root.hosted
    rotation: root.turn
    transformOrigin: Item.TopLeft
    // the blur slices (see sliceHalf)
    Item { id: sl0; readonly property real half: root.blurred ? root.sliceHalf(0) : 0
        x: -half; width: half * 2; y: -root.dh * Math.min(0.97, 1 / 12); height: root.foot - y }
    Item { id: sl1; readonly property real half: root.blurred ? root.sliceHalf(1) : 0
        x: -half; width: half * 2; y: -root.dh * Math.min(0.97, 2 / 12); height: root.dh * Math.min(0.97, 2 / 12) - root.dh * 1 / 12 }
    Item { id: sl2; readonly property real half: root.blurred ? root.sliceHalf(2) : 0
        x: -half; width: half * 2; y: -root.dh * Math.min(0.97, 3 / 12); height: root.dh * Math.min(0.97, 3 / 12) - root.dh * 2 / 12 }
    Item { id: sl3; readonly property real half: root.blurred ? root.sliceHalf(3) : 0
        x: -half; width: half * 2; y: -root.dh * Math.min(0.97, 4 / 12); height: root.dh * Math.min(0.97, 4 / 12) - root.dh * 3 / 12 }
    Item { id: sl4; readonly property real half: root.blurred ? root.sliceHalf(4) : 0
        x: -half; width: half * 2; y: -root.dh * Math.min(0.97, 5 / 12); height: root.dh * Math.min(0.97, 5 / 12) - root.dh * 4 / 12 }
    Item { id: sl5; readonly property real half: root.blurred ? root.sliceHalf(5) : 0
        x: -half; width: half * 2; y: -root.dh * Math.min(0.97, 6 / 12); height: root.dh * Math.min(0.97, 6 / 12) - root.dh * 5 / 12 }
    Item { id: sl6; readonly property real half: root.blurred ? root.sliceHalf(6) : 0
        x: -half; width: half * 2; y: -root.dh * Math.min(0.97, 7 / 12); height: root.dh * Math.min(0.97, 7 / 12) - root.dh * 6 / 12 }
    Item { id: sl7; readonly property real half: root.blurred ? root.sliceHalf(7) : 0
        x: -half; width: half * 2; y: -root.dh * Math.min(0.97, 8 / 12); height: root.dh * Math.min(0.97, 8 / 12) - root.dh * 7 / 12 }
    Item { id: sl8; readonly property real half: root.blurred ? root.sliceHalf(8) : 0
        x: -half; width: half * 2; y: -root.dh * Math.min(0.97, 9 / 12); height: root.dh * Math.min(0.97, 9 / 12) - root.dh * 8 / 12 }
    Item { id: sl9; readonly property real half: root.blurred ? root.sliceHalf(9) : 0
        x: -half; width: half * 2; y: -root.dh * Math.min(0.97, 10 / 12); height: root.dh * Math.min(0.97, 10 / 12) - root.dh * 9 / 12 }
    Item { id: sl10; readonly property real half: root.blurred ? root.sliceHalf(10) : 0
        x: -half; width: half * 2; y: -root.dh * Math.min(0.97, 11 / 12); height: root.dh * Math.min(0.97, 11 / 12) - root.dh * 10 / 12 }
    Item { id: sl11; readonly property real half: root.blurred ? root.sliceHalf(11) : 0
        x: -half; width: half * 2; y: -root.dh * Math.min(0.97, 12 / 12); height: root.dh * Math.min(0.97, 12 / 12) - root.dh * 11 / 12 }
    Shape {
        preferredRendererType: Shape.CurveRenderer
        // the body: fillet, side, dome, side, fillet, back along the frame edge
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.fill
            startX: -root.bw - root.f; startY: root.foot
            PathCubic {
                x: -root.bw * 0.93; y: -root.dh * 0.34
                control1X: -root.bw - root.f * 0.3; control1Y: 0
                control2X: -root.bw * 0.99; control2Y: -root.dh * 0.1
            }
            PathCubic {
                x: 0; y: -root.dh
                control1X: -root.bw * 0.86; control1Y: -root.dh * 0.86
                control2X: -root.bw * 0.52; control2Y: -root.dh
            }
            PathCubic {
                x: root.bw * 0.93; y: -root.dh * 0.34
                control1X: root.bw * 0.52; control1Y: -root.dh
                control2X: root.bw * 0.86; control2Y: -root.dh * 0.86
            }
            PathCubic {
                x: root.bw + root.f; y: root.foot
                control1X: root.bw * 0.99; control1Y: -root.dh * 0.1
                control2X: root.bw + root.f * 0.3; control2Y: 0
            }
            PathLine { x: root.bw + root.f; y: root.foot }
            PathLine { x: -root.bw - root.f; y: root.foot }
        }
        // light from above, so the dome reads as round and not as a flat bump
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: -root.dh; x2: 0; y2: 0
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, root.glass ? 0.08 : 0.35) }
                GradientStop { position: 0.7; color: Qt.rgba(1, 1, 1, 0) }
            }
            startX: -root.bw * 0.93; startY: -root.dh * 0.34
            PathCubic {
                x: 0; y: -root.dh
                control1X: -root.bw * 0.86; control1Y: -root.dh * 0.86
                control2X: -root.bw * 0.52; control2Y: -root.dh
            }
            PathCubic {
                x: root.bw * 0.93; y: -root.dh * 0.34
                control1X: root.bw * 0.52; control1Y: -root.dh
                control2X: root.bw * 0.86; control2Y: -root.dh * 0.86
            }
            PathLine { x: -root.bw * 0.93; y: -root.dh * 0.34 }
        }
        // the ring only over the dome: where he joins the frame there is no
        // edge, the frame has none either. In the accent colour when he wears
        // one, a faint shade on his own colours, none when he is the frame.
        ShapePath {
            fillColor: "transparent"
            strokeWidth: root.world.ring || !root.glass ? 1 : 0
            strokeColor: root.world.ring ? root.world.alpha(root.world.primary, 0.6)
                : root.glass ? "transparent" : Qt.rgba(0, 0, 0, 0.15)
            capStyle: ShapePath.RoundCap
            startX: -root.bw * 0.97; startY: -root.dh * 0.2
            PathCubic {
                x: 0; y: -root.dh
                control1X: -root.bw * 0.9; control1Y: -root.dh * 0.8
                control2X: -root.bw * 0.53; control2Y: -root.dh
            }
            PathCubic {
                x: root.bw * 0.97; y: -root.dh * 0.2
                control1X: root.bw * 0.53; control1Y: -root.dh
                control2X: root.bw * 0.9; control2Y: -root.dh * 0.8
            }
        }
    }

    // a small spot of light on the dome
    Rectangle {
        width: root.bw * 0.3; height: root.dh * 0.14
        radius: height / 2
        x: -root.bw * 0.78; y: -root.dh * 0.7
        rotation: -32
        color: "white"
        opacity: (root.glass ? 0.35 : 0.6) * Math.min(1, root.rise)
    }
    }
    // where the face sits, turned along with the dome
    // flat: in the middle of the bar, on the other side of its edge
    readonly property real faceDist: flat ? -barWidth / 2
        : dh * (cakeFace ? 0.42 : across ? 0.56 : 0.5) + st.faceLift
    readonly property real faceX: Math.sin(turn * Math.PI / 180) * (faceDist + pulseHop)
    readonly property real faceY: -Math.cos(turn * Math.PI / 180) * (faceDist + pulseHop)

    readonly property bool cakeFace: st.cakeFace
    // Robo keeps his screen, eyes glowing in the accent colour
    Rectangle {
        visible: root.st.skin === "robo"
        width: root.st.size * 0.62
        height: root.flat ? root.st.size * 0.34 : Math.min(root.dh * 0.62, root.st.size * 0.34)
        radius: height * 0.4
        x: root.faceX - width / 2; y: root.faceY - height / 2
        color: "#1d2128"
        opacity: Math.min(1, root.rise * 1.6 - 0.4)
    }
    LongEyes {
        visible: !root.cakeFace
        st: root.st
        ink: root.st.skin === "robo" ? root.world.primary : root.ink
        lashes: root.st.skin === "shiro"
        x: root.faceX + root.st.tremble
        y: root.faceY
        rotation: root.st.faceTilt + root.st.faceSpin
        opacity: Math.min(1, root.rise * 1.6 - 0.4)
        scale: 0.86 * root.pulseScale
    }
    Face {
        visible: root.cakeFace
        st: root.st
        ink: root.ink
        x: root.faceX + root.st.tremble
        y: root.faceY
        rotation: root.st.faceTilt + root.st.faceSpin
        opacity: Math.min(1, root.rise * 1.6 - 0.4)
        scale: 0.8 * root.pulseScale
    }
    // the two dancing hands (Character.dockMove): their place in his size,
    // along the edge and outwards, turned with the dome
    component DanceHand: Rectangle {
        id: dhand
        property real hx: 0
        property real hy: 0
        readonly property real lx: (root.turn === 180 ? -hx : hx) * root.st.size
        readonly property real ly: hy * root.st.size
        readonly property real a: root.turn * Math.PI / 180
        visible: root.st.dockHands > 0.02 && !root.flat && root.rise > 0.6
        width: root.st.size * 0.22; height: width; radius: width / 2
        x: lx * Math.cos(a) - ly * Math.sin(a) - width / 2
        y: lx * Math.sin(a) + ly * Math.cos(a) - height / 2
        scale: Math.min(1, root.st.dockHands * 1.4)
        color: root.frameTint ? root.world.alpha(root.world.frameColor, Math.min(1, root.world.glassOpacity + 0.25)) : root.fill
        Rectangle {
            x: parent.width * 0.22; y: parent.height * 0.18
            width: parent.width * 0.34; height: width * 0.62; radius: height / 2
            rotation: -26
            color: "white"; opacity: 0.45
        }
    }
    DanceHand { hx: root.st.dLX; hy: root.st.dLY }
    DanceHand { hx: root.st.dRX; hy: root.st.dRY }

    // a hand that pokes out of the dome towards a neighbour (st.pokeFromDock)
    Rectangle {
        readonly property real dir: root.turn === 180 ? -root.st.dockPokeDir : root.st.dockPokeDir
        readonly property real lx: dir * (root.bw * 0.72 + root.st.dockPoke * root.st.size * 0.4)
        readonly property real ly: -root.dh * 0.42
        readonly property real a: root.turn * Math.PI / 180
        visible: root.st.dockPoke > 0.02 && !root.flat
        width: root.st.size * 0.22; height: width; radius: width / 2
        x: lx * Math.cos(a) - ly * Math.sin(a) - width / 2
        y: lx * Math.sin(a) + ly * Math.cos(a) - height / 2
        scale: Math.min(1, root.st.dockPoke * 1.6)
        color: root.frameTint ? root.world.alpha(root.world.frameColor, Math.min(1, root.world.glassOpacity + 0.25)) : root.fill
        Rectangle {
            x: parent.width * 0.22; y: parent.height * 0.18
            width: parent.width * 0.34; height: width * 0.62; radius: height / 2
            rotation: -26
            color: "white"; opacity: 0.45
        }
    }
    Sweat {
        st: root.st
        spread: root.st.size * 0.38
        x: root.faceX
        y: root.faceY - root.st.size * 0.05
        visible: root.rise > 0.6
    }
}
