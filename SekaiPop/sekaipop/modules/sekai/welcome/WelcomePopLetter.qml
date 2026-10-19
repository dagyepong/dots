import QtQuick
import "../../common/functions/WelcomeMath.js" as WM

// One letter of the SekaiPop logo. It does not grow where it stands: it bursts
// out of the middle of the logo, on its own spring, and goes back into the
// middle when the logo leaves.
//
//   in     Every slot has its own character (WM.BURST): when it starts, how long
//          it takes, how springy it is (how far it hops past its size), the angle
//          it starts at, and how far its flight bends sideways. It leaves the
//          middle at scale 0, flies out along a slightly curved line, hops past
//          its place and its size, swings through upright and settles crooked,
//          the way each letter rests (WM.letterRest). It is stretched tall while
//          it flies, squashed as it lands, and it starts out of focus.
//   layers The base (fill, gradient, gloss) is there from the first frame. The
//          rim grows round it, the hard extrusion slides out from behind a beat
//          later and hops past its length, the wave band rises up the bottom, the
//          halftone comes up in the corner while a matte band crosses it, and
//          last a hard shine sweeps across.
//   out    Everything is pulled into the middle: a short breath outward first
//          (WM.collapse), then an accelerating fall to the centre while it
//          shrinks, spins and goes out of focus. The letters that came in last
//          go first.
//   idle   Once the logo has landed it floats: one slow wave runs through the
//          whole word (every letter on the same wave, a little later than the
//          one before it), and a glint runs across it now and then (`glint`).
//
// A letter is built in two halves, `part` "back" (the rim and the extrusion) and
// "face" (the flat face), drawn by two copies of the letter that move exactly
// alike; the logo puts all the backs of a line behind all its faces, and one
// halftone, wave and shine over the faces of the whole word. (As `part` "all" it
// has its own textures, as on the icon of the second slide.)
//
// WelcomeLogo.qml sets `reveal` and `leave` (the logo's two runs), `slot` (which
// letter this is) and `origin`/`cellX`/`cellY` (where the middle is and where
// this letter's cell is, in the logo's coordinates); the layers and the motion
// are worked out here. The letter sets its own x and y: put it in a cell (an
// Item of its size), not straight in a Row.
WelcomeLetter {
    id: root

    // Which letter of the logo: 0..4 "Sekai", 5..7 "Pop", 8..10 the kana.
    property int slot: 0
    property real reveal: 0
    property real leave: 0
    property real unit: 1
    // The page's slow turn (radians) and how much of the floating is wanted
    // (0..1; eased by the logo so the floating starts gently).
    property real idle: 0
    property real idleAmp: 0
    // How fast the floating's phase changes along the word (radians per pixel).
    // The letters do not float each on a phase of its own: one slow wave runs
    // through the whole word, so the word moves as one piece.
    property real idleSkew: 0
    // The idle glint, 0..1 over the whole word (0 = not running).
    property real glint: 0
    // Where the letter's cell is (its top left) and where the middle is, in the
    // logo's coordinates; baseY is a further drop of the line.
    property real cellX: 0
    property real cellY: 0
    property point origin: Qt.point(0, 0)
    property real baseY: 0

    readonly property var burst: WM.burstOf(root.slot)
    readonly property real p: WM.letterProgress(root.reveal, root.slot)
    readonly property real pe: WM.burstSpring(root.p, root.slot)
    readonly property real lp: WM.leaveProgress(root.leave, root.slot)
    readonly property real lc: WM.collapse(root.lp)
    readonly property bool leaving: root.leave > 0
    readonly property var rest: WM.letterRest(root.slot)

    // How far out the letter is: 1 at its place, 0 in the middle (above 1 on the
    // hop past its place, a little above 1 on the breath before it leaves).
    readonly property real out: root.leaving ? 1 - root.lc : root.pe

    // where its middle rests, and the line from there to the logo's middle
    readonly property real restY: root.baseY + root.rest[1] * root.pixelSize
    readonly property real vx: root.origin.x - (root.cellX + root.width / 2)
    readonly property real vy: root.origin.y - (root.cellY + root.restY + root.height / 2)
    // the flight bends sideways: nothing at either end, most half way
    readonly property real bend: 4 * WM.clamp01(root.out) * (1 - WM.clamp01(root.out)) * root.burst.swirl
    readonly property real sq: root.leaving ? 0.8 * WM.squash(root.lp) : WM.squash(root.p * 1.5)

    // the layers, each starting a little after the one before it
    readonly property real rimRun: WM.easeOutCubic(WM.layerRun(root.p, 0.04, 0.34))
    readonly property real shadowRun: WM.popSpring(WM.layerRun(root.p, 0.16, 0.5))
    // where this letter is in the word's glint (the glint reaches the letters
    // one after the other, from the left)
    readonly property real glintLocal: root.glint > 0 && root.glint < 1
                                       ? WM.clamp01(root.glint * 1.6 - root.slot * 0.045) : 0

    outlineBuild: root.rimRun
    extrudeBuild: root.shadowRun
    waveRun: WM.easeOutCubic(WM.layerRun(root.p, 0.3, 0.45))
    wavePhase: (1 - WM.layerRun(root.p, 0.3, 0.7)) * 0.9 + root.idleAmp * root.idle / (2 * Math.PI)
    dotsRun: WM.easeOutCubic(WM.layerRun(root.p, 0.45, 0.4))
    // the halftone's matte crosses the letter once while it lands (and again with
    // each glint); the lattice drifts while the logo idles
    matteRun: root.glintLocal > 0 ? root.glintLocal
              : (root.p > 0 && root.p < 1 ? WM.layerRun(root.p, 0.4, 0.55) : -1)
    dotDrift: root.p * 0.6 + root.idleAmp * root.idle / (2 * Math.PI)
    shineRun: root.glintLocal > 0 ? root.glintLocal : WM.layerRun(root.p, 0.6, 0.38)

    // Not `visible`: a letter that has not started is at scale 0 and opacity 0
    // instead (and is not drawn).
    opacity: root.leaving ? 1 - WM.clamp01((root.lp - 0.8) / 0.2) : Math.min(1, root.p * 10)
    scale: Math.max(0, root.out)
    transformOrigin: Item.Center
    rotation: root.rest[0]
              + (root.leaving ? -root.lc * root.burst.tilt * 1.3 : (1 - root.pe) * root.burst.tilt)
              + root.idleAmp * 1.6 * Math.sin(root.idle - root.idleSkew * (root.cellX + root.width / 2) + 1)

    x: root.vx * (1 - root.out) - root.vy * root.bend
    y: root.restY + root.vy * (1 - root.out) + root.vx * root.bend
       + root.idleAmp * 2.2 * root.unit * Math.sin(root.idle - root.idleSkew * (root.cellX + root.width / 2))

    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: 1 - 0.16 * root.sq
        yScale: 1 + 0.22 * root.sq
    }

    // Out of focus for the first part of the way in, and again on the way out
    // (WelcomeLetter draws the blur; its layer exists only while the blur is
    // above 0).
    blur: root.leaving ? 0.9 * WM.clamp01((root.lp - 0.3) / 0.7)
                       : 1 - WM.clamp01(root.p / 0.28)
}
