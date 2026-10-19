import QtQuick
import QtQuick.Effects
import "../../common/functions/WelcomeMath.js" as WM

// The central ignition of the logo's entrance, and the small flash where the
// exit meets in the middle: the centre of the composition is where everything
// comes from and goes to, so it gets its own cue.
//
//   glow   a soft disc of light that swells and fades
//   ring   a thin ring that runs outward and thins as it goes
//   star   the four-point sparkle, flashing once, turning a quarter
//
// `run` (0..1, the logo's WM.ignitionRun) plays the entrance; `flash` (0..1, a
// bell the logo works out for the exit) plays a smaller version of the glow and
// the star. Sized by `size`, centred on this item's own centre.
Item {
    id: root

    property real size: 120
    property real unit: 1
    property real run: 0
    property real flash: 0
    property color glowColor: "#ffffff"
    property color ringColor: "#ffffff"
    property color starFill: "#ffefce"
    property color starInk: "#232235"

    readonly property real u: WM.clamp01(root.run)
    // glow: rises fast, falls slowly; the exit's flash adds its own
    readonly property real glowIn: Math.sin(Math.PI * Math.pow(root.u, 0.55))
    readonly property real glowAmt: Math.max(root.run > 0 && root.run < 1 ? root.glowIn : 0, root.flash)
    readonly property real glowGrow: Math.max(0.25 + 1.15 * WM.easeOutCubic(root.u), 0.45 + 0.35 * root.flash)
    readonly property real ringT: WM.easeOutCubic(WM.clamp01((root.u - 0.04) / 0.72))
    readonly property real starAmt: Math.max(Math.sin(Math.PI * WM.clamp01(root.u / 0.6)) * 1.05,
                                             root.flash * 0.6)

    width: 1
    height: 1
    visible: root.glowAmt > 0.002 || (root.run > 0 && root.run < 1)

    Rectangle {
        id: disc

        width: root.size * 0.8
        height: width
        x: -width / 2
        y: -height / 2
        radius: width / 2
        color: root.glowColor
        opacity: 0.9 * root.glowAmt
        scale: root.glowGrow
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 40
            blur: 1.0
        }
    }

    Rectangle {
        width: root.size * 1.3 * root.ringT
        height: width
        x: -width / 2
        y: -height / 2
        radius: width / 2
        color: "transparent"
        border.color: root.ringColor
        border.width: Math.max(0.6, 5 * root.unit * (1 - root.ringT))
        opacity: root.run > 0 && root.run < 1 ? Math.pow(1 - root.ringT, 0.7) : 0
        visible: opacity > 0.01
    }

    WelcomeSparkle {
        size: root.size * 0.5
        x: -size / 2
        y: -size / 2
        fill: root.starFill
        ink: root.starInk
        pop: root.starAmt
        rotation: -45 + 90 * root.u
    }
}
