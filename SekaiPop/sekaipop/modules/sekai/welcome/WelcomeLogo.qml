import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.modules.common
import "../../common/functions/WelcomeMath.js" as WM

// The SekaiPop logo, built the way the logo in the reference video is: a
// composition of separately animated layers that end up as one piece.
//
//   letters   chunky rounded letters in two stacked lines (the second shifted
//             right). Each is two WelcomePopLetters that move exactly alike: a
//             back (gradient rim and extrusion) and a face (fill and gloss), each
//             letter with its own spring; the backs of a line sit behind all its
//             faces
//   textures  ONE wave texture, ONE halftone and ONE hard shine for the whole
//             word, in the word's own coordinates, shown only through the faces
//             (a track matte): a matte band and a shine cross the word once, the
//             wave flows through all the letters as one. A letter that lands late
//             is already inside the running texture; nothing is per letter
//   kana      a small line above, three letters of their own, on arcs
//   accents   four sparkles, a squiggle and two diamonds, each with its own pop
//   stroke    the combined treatment: a light outer stroke round the whole word
//             (a blur cut at a level, so it is even at any thickness), a darker
//             copy of it moved down and right, and a halftone of its own that a
//             matte crosses; it comes up after the letters and sits behind them
//   wave      a travelling wave warps the whole assembled word (the logo, stroke
//             and all, drawn into one texture and shown on a grid that a vertex
//             shader moves), while a light sweep crosses it
//
// Two numbers run it, both 0..1 and both linear in time: `reveal` over
// WM.LOGO_RUN_MS (the entrance, a burst out of the middle) and `leave` over
// WM.LOGO_LEAVE_MS (the exit, everything collapsing back into the middle).
// WelcomeMath.js has what each layer does when. `idle` is a phase (radians) that
// the page turns slowly once the logo has landed; every letter floats on its own
// phase and the sparkles twinkle.
//
// The wave pass needs shaders/welcome_warp.{vert,frag}.qsb, and the letters'
// moving halftone shaders/welcome_dots.frag.qsb (run shaders/compile-shaders.sh).
// Without them the logo still comes in whole: the wave and the sweep are skipped
// and the letters keep their still dots.
Item {
    id: root

    property real unit: 1
    property real reveal: 0
    property real leave: 0
    property real idle: 0
    property bool idling: false

    // The palette comes from the shell theme, so the logo follows the unit theme.
    property color fill: Qt.tint(Theme.pal.B, Qt.rgba(1, 1, 1, 0.16))
    property color ink: Theme.pal.deep
    property color haloColor: Qt.tint(Theme.pal.B, Qt.rgba(1, 1, 1, 0.78))
    property color haloShadow: Qt.tint(Theme.pal.B, Qt.rgba(0.1, 0.25, 0.2, 0.15))
    property color haloDots: Qt.tint(Theme.pal.B, Qt.rgba(0.05, 0.25, 0.2, 0.2))
    property color sparkFill: "#ffefce"
    // the dots' and the wave's ink: the fill, darker
    readonly property color dotInk: Qt.darker(root.fill, 1.4)
    // The wave texture's three tones, all made of the letter's own colour so it
    // reads on any palette and keeps its hue: a deeper shade for the body of the
    // wave, a slightly deeper one for the second wave behind it, a light one for
    // the crest line on its edge. (Mixing in the dark ink instead pulled them
    // toward grey.)
    readonly property color waveDeep: Qt.darker(root.fill, 1.22)
    readonly property color waveMid: Qt.darker(root.fill, 1.08)
    readonly property color waveCrest: Qt.tint(root.fill, Qt.rgba(1, 1, 1, 0.7))
    // The small line above the word: hiragana "se ka i". (Katakana is
    // "\u30bb\u30ab\u30a4".)
    property var kana: ["\u305b", "\u304b", "\u3044"]

    // Sized so the whole mark (kana, sparkles and stroke included) is about 60% of
    // the page width and 32% of its height, as the logo in the video is.
    readonly property real size: 114 * root.unit
    readonly property var axes: ({ "wght": 1000, "ROND": 100, "wdth": 100 })
    // The margin round the word. The stroke, its shadow and the sparkles are drawn
    // in it, and anything that reaches past it is cut off flat, so it has to be
    // wider than the stroke and its shadow with room to spare.
    readonly property real pad: 80 * root.unit
    // the stroke's width when it is all the way out, and how wide it is now
    readonly property real strokeFull: 17 * root.unit
    readonly property real strokeR: root.strokeFull * root.strokeK

    readonly property bool leaving: root.leave > 0
    // where everything comes from and goes to, in `comp`'s coordinates
    readonly property point origin: Qt.point(root.pad + root.width / 2, root.pad + root.size * 0.95)

    // the combined passes
    readonly property real strokeK: root.leaving ? 1 - WM.leaveStroke(root.leave) : WM.strokeRun(root.reveal)
    readonly property real halftoneK: root.leaving ? 0 : WM.halftoneRun(root.reveal)
    readonly property real warpU: root.leaving ? 0 : WM.warpRun(root.reveal)
    readonly property real sweepU: root.leaving ? 0 : WM.sweepRun(root.reveal)
    readonly property bool warping: root.warpU > 0 && root.warpU < 1

    // How much of the floating is on: eased, so it starts gently once the logo
    // has landed instead of jumping to wherever the phase happens to be.
    property real idleAmp: root.idling ? 1 : 0

    Behavior on idleAmp {
        NumberAnimation { duration: 900; easing.type: Easing.InOutSine }
    }

    // One slow wave of floating runs through the whole word (see WelcomePopLetter)
    readonly property real idleSkew: 2 * Math.PI / (root.width * 1.6)

    // The word's textures run on the word's clock, not on a letter's: all of
    // them are read from the logo's reveal, so every letter is inside the same
    // stretch of the same pass at the same moment.
    readonly property real fxWave: root.leaving ? 1 : WM.fxWaveRun(root.reveal)
    readonly property real fxDots: root.leaving ? 1 : WM.fxDotsRun(root.reveal)
    readonly property real fxMatteU: root.leaving ? 0 : WM.fxMatteRun(root.reveal)
    readonly property real fxShineU: root.leaving ? 0 : WM.fxShineRun(root.reveal)
    // a glint (idle) is the same matte and shine passes again
    readonly property real shineU: root.glint > 0 ? root.glint : root.fxShineU
    readonly property real matteU: root.glint > 0 ? root.glint : root.fxMatteU
    // one phase for the whole wave texture and one drift for the whole lattice;
    // both loop seamlessly with the page's idle phase
    // (two whole cycles per turn of the idle phase: the ripple visibly travels)
    readonly property real fxPhase: (1 - root.fxWave) * 0.9 + root.idleAmp * root.idle / (2 * Math.PI) * 2

    // Where each line's ink sits (the cap height and the baseline of its first
    // letter), in the logo's coordinates: the wave texture is laid on these.
    FontMetrics {
        id: fm1

        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.size)
        font.weight: Font.Black
        font.variableAxes: root.axes
    }

    FontMetrics {
        id: fm2

        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.size * 0.9)
        font.weight: Font.Black
        font.variableAxes: root.axes
    }

    readonly property real l1X: root.pad
    readonly property real l1Y: root.pad + 4 * root.unit
    readonly property real l2Y: root.pad + root.size * 0.77
    // (tightBoundingRect() does not announce a change of font, so each of these
    // reads the metrics' ascent and descent first: they do announce it, and the
    // measurement is taken again when the font is really set. Without that it was
    // taken once, before the font, for the default 9 px one, and the wave was
    // built for a letter 9 px tall.)
    readonly property rect t1: (fm1.ascent + fm1.descent > 0) ? fm1.tightBoundingRect("S") : Qt.rect(0, 0, 0, 0)
    readonly property rect t2: (fm2.ascent + fm2.descent > 0) ? fm2.tightBoundingRect("P") : Qt.rect(0, 0, 0, 0)
    readonly property real l1Top: root.l1Y + fm1.ascent + root.t1.y
    readonly property real l1Bottom: root.l1Top + root.t1.height
    readonly property real l2Top: root.l2Y + fm2.ascent + root.t2.y
    readonly property real l2Bottom: root.l2Top + root.t2.height

    // The polygon of one wave band over a line: its top edge is a ripple of the
    // given wavelength in the logo's x (so the ripple is one and the same across
    // every letter and both lines), slid by `phase`; its bottom is flat.
    function wavePoly(x0, x1, yBottom, yEdge, amp, wavelength, phase) {
        const a = [];
        const n = 48;
        a.push(Qt.point(x0, yBottom));
        for (let i = 0; i <= n; i++) {
            const x = x0 + (x1 - x0) * i / n;
            a.push(Qt.point(x, yEdge + amp * Math.sin(2 * Math.PI * (x / wavelength + phase))));
        }
        a.push(Qt.point(x1, yBottom));
        return a;
    }

    // Just the ripple, as a line (for the bright crest along a wave's edge).
    function waveLine(x0, x1, yEdge, amp, wavelength, phase) {
        const a = [];
        const n = 48;
        for (let i = 0; i <= n; i++) {
            const x = x0 + (x1 - x0) * i / n;
            a.push(Qt.point(x, yEdge + amp * Math.sin(2 * Math.PI * (x / wavelength + phase))));
        }
        return a;
    }

    // A glint now and then: a hard shine runs across the word (letter by letter,
    // left to right) and the halftone's matte crosses with it, as in the video as
    // each letter lands. It only runs while the logo idles.
    property real glint: 0

    // When the idling stops (the page is leaving), a glint in the middle of its
    // run would stop where it is and hang over the letters as they collapse.
    onIdlingChanged: if (!root.idling) root.glint = 0

    SequentialAnimation {
        running: root.idling
        loops: Animation.Infinite

        PauseAnimation { duration: 3600 }
        NumberAnimation { target: root; property: "glint"; from: 0.001; to: 0.999; duration: 1300; easing.type: Easing.InOutSine }
        ScriptAction { script: root.glint = 0 }
    }

    implicitWidth: line1Back.implicitWidth + 12 * root.unit
    implicitHeight: root.size * 1.78
    width: root.implicitWidth
    height: root.implicitHeight

    // One cell of a line: the letter sits in an Item of its own size (so the Row
    // can lay the line out), and the letter moves itself inside that cell.
    component Cell: Item {
        id: cell

        property alias letter: letterItem
        required property string modelData
        required property int index
        property int slotBase: 0
        property string part: "all"
        property real lineX: 0
        property real lineY: 0
        property real pixelSize: root.size
        // the small kana: no dots or waves, a thinner rim and a shorter extrusion
        property bool dots: true
        property bool small: false

        width: letterItem.implicitWidth
        height: letterItem.implicitHeight

        WelcomePopLetter {
            id: letterItem

            slot: cell.slotBase + cell.index
            reveal: root.reveal
            leave: root.leave
            unit: root.unit
            idle: root.idle
            idleAmp: root.idleAmp
            idleSkew: root.idleSkew
            glint: root.glint
            part: cell.part
            cellX: cell.lineX + cell.x
            cellY: cell.lineY
            origin: root.origin
            text: cell.modelData
            pixelSize: Math.round(cell.pixelSize)
            axes: root.axes
            fill: root.fill
            outlineColor: root.ink
            halftone: cell.dots
            wave: cell.dots
        }

        // (Binding gives the letter's own defaults back when `small` is off.)
        Binding { target: letterItem; property: "outline"; value: Math.max(1.5, root.size * 0.027); when: cell.small }
        Binding { target: letterItem; property: "extrudeX"; value: root.size * 0.02; when: cell.small }
        Binding { target: letterItem; property: "extrudeY"; value: root.size * 0.03; when: cell.small }
    }

    // One line of the word, in one half: `part` "back" is the rims and the
    // extrusions, "face" is the faces. Both halves lay out the same.
    component Line: Item {
        id: line

        property var chars: []
        property int slotBase: 0
        property real pixelSize: root.size
        property string part: "face"

        implicitWidth: lineRow.implicitWidth
        implicitHeight: lineRow.implicitHeight

        Row {
            id: lineRow

            spacing: -root.size * 0.04

            Repeater {
                model: line.chars

                Cell {
                    slotBase: line.slotBase
                    lineX: line.x
                    lineY: line.y
                    pixelSize: line.pixelSize
                    part: line.part
                }
            }
        }
    }

    // A decorative sparkle: it comes out of the middle a short way, hops past its
    // size and turns into place, and it goes back the same way.
    component Decor: WelcomeSparkle {
        required property int order
        property real homeX: 0
        property real homeY: 0
        property real fly: 0.6
        property real twinkleAt: 0

        readonly property real run: root.leaving ? 0 : WM.decorRun(root.reveal, order)
        readonly property real gone: WM.leaveDecor(root.leave)

        fill: root.sparkFill
        ink: root.ink
        pop: root.leaving ? Math.max(0, 1 - WM.easeInBack(gone, 1.4)) : WM.springEx(run, 0.42, 15, 0.56)
        x: homeX + (root.origin.x - homeX - width / 2) * (1 - pop) * fly
        y: homeY + (root.origin.y - homeY - height / 2) * (1 - pop) * fly
        twinkle: root.idling ? Math.sin(root.idle * 2 + twinkleAt) : 0
    }

    // Everything inside `comp` is the logo as one piece (stroke, dots and letters);
    // the wave pass takes a picture of it and shows that picture moving. Its box
    // is bigger than the logo, so the stroke and the sparkles are not cut off.
    Item {
        id: comp

        x: -root.pad
        y: -root.pad
        width: root.width + root.pad * 2
        height: root.height + root.pad * 2

        // ---- the combined stroke: the whole logo's outline, pushed out evenly ----
        // The silhouette of everything (letters, rims, kana, sparkles) is drawn
        // again round a circle, so the union is that silhouette grown by the same
        // distance all the way round: a stroke that follows every curve, not a
        // blur cut at a level. It grows from the letters outward as it comes in
        // (and back in on the way out), so it hugs them the whole time. The
        // shaded copy is the same stroke moved down and right. Both sit behind
        // the letters; the dots of the stroke are laid over the light copy.
        Item {
            id: dilGroup

            width: comp.width
            height: comp.height

            ShaderEffect {
                property variant source: bodyTex

                width: comp.width
                height: comp.height
            }

            Repeater {
                model: 28

                ShaderEffect {
                    required property int index

                    readonly property real angle: index / 28 * 2 * Math.PI

                    property variant source: bodyTex

                    x: root.strokeR * Math.cos(angle)
                    y: root.strokeR * Math.sin(angle)
                    width: comp.width
                    height: comp.height
                }
            }
        }

        ShaderEffectSource {
            id: dilTex

            sourceItem: dilGroup
            hideSource: true
            visible: false
            width: comp.width
            height: comp.height
            // As live as the letters it is made from.
            live: bodyTex.live
            onLiveChanged: if (!live) scheduleUpdate()
        }

        // a blurred silhouette: only how near the letters are, for the dots' shading
        MultiEffect {
            id: blurFx

            source: bodyTex
            width: comp.width
            height: comp.height
            blurEnabled: true
            blur: 1.0
            blurMax: Math.min(64, Math.round(root.strokeFull * 1.5))
            visible: false
        }

        ShaderEffectSource {
            id: blurTex

            sourceItem: blurFx
            hideSource: true
            visible: false
            width: comp.width
            height: comp.height
            live: bodyTex.live
            onLiveChanged: if (!live) scheduleUpdate()
        }

        Rectangle {
            id: haloBlock

            width: comp.width
            height: comp.height
            visible: false
            layer.enabled: true
            color: "#ffffff"
        }

        MultiEffect {
            id: haloShade

            source: haloBlock
            x: 3 * root.unit
            y: 7 * root.unit
            width: comp.width
            height: comp.height
            z: -3
            colorization: 1.0
            colorizationColor: root.haloShadow
            maskEnabled: true
            maskSource: dilTex
            opacity: Math.min(1, root.strokeK * 4)
        }

        MultiEffect {
            id: haloFace

            source: haloBlock
            width: comp.width
            height: comp.height
            z: -2
            colorization: 1.0
            colorizationColor: root.haloColor
            maskEnabled: true
            maskSource: dilTex
            opacity: Math.min(1, root.strokeK * 4)
        }

        // the stroke's halftone (shaders/welcome_halo.frag): dots biggest beside
        // the letters, gone before the stroke's edge, swollen on the lower right
        // side of every letter; a matte band crosses it while it comes up and
        // again with each glint, and the lattice drifts
        ShaderEffect {
            id: haloDotsFx

            property variant field: blurTex
            property color dotColor: Qt.rgba(root.haloDots.r, root.haloDots.g, root.haloDots.b, 1)
            property size size: Qt.size(width, height)
            property size shadeOffset: Qt.size(7 * root.unit / comp.width, 12 * root.unit / comp.height)
            property real spacing: 8 * root.unit
            property real shade: root.halftoneK
            property real matte: root.glint > 0 ? root.glint
                                 : (root.reveal > 0 && root.reveal < 1 ? WM.seg(root.reveal, WM.HALFTONE_AT, WM.HALFTONE_MS) : -1)
            property real drift: 0.35 * root.halftoneK + root.idleAmp * root.idle / (2 * Math.PI)
            property real amount: 0.9

            width: comp.width
            height: comp.height
            fragmentShader: Directories.shader("welcome_halo.frag.qsb")
        }

        ShaderEffectSource {
            id: haloDotsTex

            sourceItem: haloDotsFx
            hideSource: true
            visible: false
            width: comp.width
            height: comp.height
        }

        MultiEffect {
            source: haloDotsTex
            width: comp.width
            height: comp.height
            z: -1
            maskEnabled: true
            maskSource: dilTex
            opacity: root.strokeK * Math.min(1, root.halftoneK * 3)
            visible: haloDotsFx.status !== ShaderEffect.Error
        }

        // ---- the logo itself ----
        Item {
            id: body

            width: comp.width
            height: comp.height

            // ---- the word's textures: one field, in the logo's coordinates ----
            // (Hidden; the two layers below show it through the faces.)
            Item {
                id: fxGroup

                width: comp.width
                height: comp.height

                // The wave texture, as in the reference: along the bottom of each
                // line a body of wave in a deeper tone of the letters' own colour,
                // a second wave of another length behind it, and a bright crest
                // line riding the edge of the first. It rises as it comes in, and
                // its ripple is one wave across every letter and both lines, and
                // travels left to right (the same phase everywhere, so the letters
                // are cut from one flowing sheet).
                Shape {
                    id: waveSheet

                    // each line: where it spans, where its ink is, how tall it is
                    readonly property var lines: [
                        { x0: root.l1X - 14 * root.unit, x1: root.l1X + line1Back.implicitWidth + 14 * root.unit, bottom: root.l1Bottom, h: root.t1.height },
                        { x0: line2Back.x - 14 * root.unit, x1: line2Back.x + line2Back.implicitWidth + 14 * root.unit, bottom: root.l2Bottom, h: root.t2.height }
                    ]
                    readonly property real rise: root.fxWave
                    // the strength of the ripple comes up with the wave itself
                    readonly property real swell: 0.4 + 0.6 * root.fxWave

                    anchors.fill: parent
                    visible: root.fxWave > 0.001
                    preferredRendererType: Shape.CurveRenderer

                    // second wave, behind: higher, shorter, a middle tone
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: Qt.rgba(root.waveMid.r, root.waveMid.g, root.waveMid.b, 0.55)

                        PathPolyline {
                            path: root.wavePoly(waveSheet.lines[0].x0, waveSheet.lines[0].x1, waveSheet.lines[0].bottom + root.size * 0.2,
                                                waveSheet.lines[0].bottom - waveSheet.lines[0].h * (0.46 * waveSheet.rise + 0.09),
                                                waveSheet.lines[0].h * 0.08 * waveSheet.swell, root.size * 0.62, 0.35 - root.fxPhase * 1.6)
                        }
                    }

                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: Qt.rgba(root.waveMid.r, root.waveMid.g, root.waveMid.b, 0.55)

                        PathPolyline {
                            path: root.wavePoly(waveSheet.lines[1].x0, waveSheet.lines[1].x1, waveSheet.lines[1].bottom + root.size * 0.2,
                                                waveSheet.lines[1].bottom - waveSheet.lines[1].h * (0.46 * waveSheet.rise + 0.09),
                                                waveSheet.lines[1].h * 0.08 * waveSheet.swell, root.size * 0.62, 0.35 - root.fxPhase * 1.6)
                        }
                    }

                    // the body of the wave: the deeper tone
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: Qt.rgba(root.waveDeep.r, root.waveDeep.g, root.waveDeep.b, 0.9)

                        PathPolyline {
                            path: root.wavePoly(waveSheet.lines[0].x0, waveSheet.lines[0].x1, waveSheet.lines[0].bottom + root.size * 0.2,
                                                waveSheet.lines[0].bottom - waveSheet.lines[0].h * 0.46 * waveSheet.rise,
                                                waveSheet.lines[0].h * 0.14 * waveSheet.swell, root.size * 0.8, -root.fxPhase)
                        }
                    }

                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: Qt.rgba(root.waveDeep.r, root.waveDeep.g, root.waveDeep.b, 0.9)

                        PathPolyline {
                            path: root.wavePoly(waveSheet.lines[1].x0, waveSheet.lines[1].x1, waveSheet.lines[1].bottom + root.size * 0.2,
                                                waveSheet.lines[1].bottom - waveSheet.lines[1].h * 0.46 * waveSheet.rise,
                                                waveSheet.lines[1].h * 0.14 * waveSheet.swell, root.size * 0.8, -root.fxPhase)
                        }
                    }

                    // the crest: a bright line along the edge of the body
                    ShapePath {
                        strokeColor: Qt.rgba(root.waveCrest.r, root.waveCrest.g, root.waveCrest.b, 0.9)
                        strokeWidth: Math.max(2, root.size * 0.03)
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        PathPolyline {
                            path: root.waveLine(waveSheet.lines[0].x0, waveSheet.lines[0].x1,
                                                waveSheet.lines[0].bottom - waveSheet.lines[0].h * 0.46 * waveSheet.rise,
                                                waveSheet.lines[0].h * 0.14 * waveSheet.swell, root.size * 0.8, -root.fxPhase)
                        }
                    }

                    ShapePath {
                        strokeColor: Qt.rgba(root.waveCrest.r, root.waveCrest.g, root.waveCrest.b, 0.9)
                        strokeWidth: Math.max(2, root.size * 0.03)
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        PathPolyline {
                            path: root.waveLine(waveSheet.lines[1].x0, waveSheet.lines[1].x1,
                                                waveSheet.lines[1].bottom - waveSheet.lines[1].h * 0.46 * waveSheet.rise,
                                                waveSheet.lines[1].h * 0.14 * waveSheet.swell, root.size * 0.8, -root.fxPhase)
                        }
                    }
                }

                // the halftone: one lattice over the word's own rectangle, so the
                // dots line up from letter to letter, the shading is in the word's
                // lower right corner and one matte band crosses the whole word
                ShaderEffect {
                    id: wordDots

                    property color dotColor: Qt.rgba(root.dotInk.r, root.dotInk.g, root.dotInk.b, 1)
                    property size size: Qt.size(width, height)
                    property real spacing: Math.max(4, root.size * 0.062)
                    property real shade: root.fxDots
                    property real matte: root.matteU > 0 && root.matteU < 1 ? root.matteU : -1
                    property real drift: 0.6 * root.fxDots + root.idleAmp * root.idle / (2 * Math.PI)
                    property real amount: 0.85
                    property real falloff: 1.2

                    x: root.pad
                    y: root.pad
                    width: root.width
                    height: root.height
                    visible: root.fxDots > 0.001
                    fragmentShader: Directories.shader("welcome_dots.frag.qsb")
                }

                // the hard shine: two slanted bands with hard edges that cross the
                // whole word once, left to right
                Shape {
                    id: wordShine

                    readonly property real slant: root.height * 0.445
                    readonly property real c1: root.pad + root.width * (-0.3 + 1.6 * root.shineU)
                    readonly property real c2: wordShine.c1 - root.size * 0.30

                    anchors.fill: parent
                    visible: root.shineU > 0.001 && root.shineU < 0.999

                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: Qt.rgba(1, 1, 1, 0.62)

                        PathPolyline {
                            path: [
                                Qt.point(wordShine.c1 - root.size * 0.13 + wordShine.slant / 2, root.pad),
                                Qt.point(wordShine.c1 + root.size * 0.13 + wordShine.slant / 2, root.pad),
                                Qt.point(wordShine.c1 + root.size * 0.13 - wordShine.slant / 2, root.pad + root.height),
                                Qt.point(wordShine.c1 - root.size * 0.13 - wordShine.slant / 2, root.pad + root.height),
                                Qt.point(wordShine.c1 - root.size * 0.13 + wordShine.slant / 2, root.pad)
                            ]
                        }
                    }

                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: Qt.rgba(1, 1, 1, 0.5)

                        PathPolyline {
                            path: [
                                Qt.point(wordShine.c2 - root.size * 0.04 + wordShine.slant / 2, root.pad),
                                Qt.point(wordShine.c2 + root.size * 0.04 + wordShine.slant / 2, root.pad),
                                Qt.point(wordShine.c2 + root.size * 0.04 - wordShine.slant / 2, root.pad + root.height),
                                Qt.point(wordShine.c2 - root.size * 0.04 - wordShine.slant / 2, root.pad + root.height),
                                Qt.point(wordShine.c2 - root.size * 0.04 + wordShine.slant / 2, root.pad)
                            ]
                        }
                    }
                }
            }

            ShaderEffectSource {
                id: fxTex

                sourceItem: fxGroup
                hideSource: true
                visible: false
                width: comp.width
                height: comp.height
            }

            // ---- first line, "Sekai": the backs, then the faces, then the textures ----
            Item {
                width: comp.width
                height: comp.height
                z: 1

                Line {
                    id: line1Back

                    x: root.l1X
                    y: root.l1Y
                    chars: ["S", "e", "k", "a", "i"]
                    slotBase: 0
                    pixelSize: root.size
                    part: "back"
                }
            }

            Item {
                id: faces1

                width: comp.width
                height: comp.height
                z: 2

                Line {
                    x: root.l1X
                    y: root.l1Y
                    chars: ["S", "e", "k", "a", "i"]
                    slotBase: 0
                    pixelSize: root.size
                    part: "face"
                }
            }

            ShaderEffectSource {
                id: faces1Tex

                // only the matte: the faces themselves are drawn directly (they
                // cannot be hidden: effects nested in a hidden subtree do not draw)
                sourceItem: faces1
                hideSource: false
                visible: false
                width: comp.width
                height: comp.height
            }

            MultiEffect {
                source: fxTex
                width: comp.width
                height: comp.height
                z: 3
                maskEnabled: true
                maskSource: faces1Tex
                autoPaddingEnabled: false
                visible: root.fxDots > 0.001 || root.fxWave > 0.001 || root.shineU > 0.001
            }

            // ---- second line, "Pop", sits lower and to the right, in front of the first ----
            Item {
                width: comp.width
                height: comp.height
                z: 4

                Line {
                    id: line2Back

                    x: root.pad + root.width - line2Back.implicitWidth - 4 * root.unit
                    y: root.l2Y
                    chars: ["P", "o", "p"]
                    slotBase: 5
                    pixelSize: Math.round(root.size * 0.9)
                    part: "back"
                }
            }

            Item {
                id: faces2

                width: comp.width
                height: comp.height
                z: 5

                Line {
                    x: line2Back.x
                    y: root.l2Y
                    chars: ["P", "o", "p"]
                    slotBase: 5
                    pixelSize: Math.round(root.size * 0.9)
                    part: "face"
                }
            }

            ShaderEffectSource {
                id: faces2Tex

                // only the matte: the faces themselves are drawn directly (they
                // cannot be hidden: effects nested in a hidden subtree do not draw)
                sourceItem: faces2
                hideSource: false
                visible: false
                width: comp.width
                height: comp.height
            }

            MultiEffect {
                source: fxTex
                width: comp.width
                height: comp.height
                z: 6
                maskEnabled: true
                maskSource: faces2Tex
                autoPaddingEnabled: false
                visible: root.fxDots > 0.001 || root.fxWave > 0.001 || root.shineU > 0.001
            }

            // ---- the small kana above the first line: letters of their own ----
            Row {
                id: kanaRow

                x: root.pad + line1Back.implicitWidth * 0.5
                y: root.pad - root.size * 0.30
                z: 7
                spacing: -root.size * 0.012

                Repeater {
                    model: root.kana

                    Cell {
                        slotBase: 8
                        lineX: kanaRow.x
                        lineY: kanaRow.y
                        pixelSize: Math.round(root.size * 0.27)
                        dots: false
                        small: true
                    }
                }
            }

            // ---- the squiggle, lower left, drawn on ----
            WelcomeSquiggle {
                x: root.pad - root.size * 0.12
                y: root.pad + root.size * 1.34
                length: root.size * 0.62
                amplitude: root.size * 0.05
                stroke: Math.max(2, root.size * 0.03)
                fill: root.sparkFill
                ink: root.ink
                draw: root.leaving ? 1 - WM.leaveDecor(root.leave) : WM.squiggleRun(root.reveal)
            }

            // ---- sparkles: two at the top right, two at the lower left ----
            Decor {
                order: 0
                homeX: root.pad + root.width * 0.82
                homeY: root.pad - root.size * 0.18
                size: root.size * 0.36
            }

            Decor {
                order: 1
                homeX: root.pad + root.width * 0.70
                homeY: root.pad - root.size * 0.28
                size: root.size * 0.19
                twinkleAt: 1.6
            }

            Decor {
                order: 2
                homeX: root.pad - root.size * 0.2
                homeY: root.pad + root.size * 1.12
                size: root.size * 0.36
                twinkleAt: 3.1
            }

            Decor {
                order: 3
                homeX: root.pad + root.size * 0.1
                homeY: root.pad + root.size * 1.0
                size: root.size * 0.17
                twinkleAt: 4.4
            }
        }
    }

    // A picture of everything above, live only while it is needed.
    ShaderEffectSource {
        id: bodyTex

        sourceItem: body
        hideSource: false
        visible: false
        // Live only while something moves; a still logo costs nothing.
        live: root.reveal < 1 || root.leaving || root.idling
        // When it stops being live, take one last picture so the stroke matches
        // the final frame of the logo exactly.
        onLiveChanged: if (!live) scheduleUpdate()
        x: comp.x
        y: comp.y
        width: comp.width
        height: comp.height
    }

    // ---- the wave pass ----
    // While it runs, the logo (stroke and letters together) is hidden and its
    // picture is shown instead, on a grid whose points a vertex shader moves.
    ShaderEffectSource {
        id: compTex

        sourceItem: comp
        hideSource: root.warping && warpFx.status !== ShaderEffect.Error
        visible: false
        live: root.warping
        onLiveChanged: if (live) scheduleUpdate()
        x: comp.x
        y: comp.y
        width: comp.width
        height: comp.height
    }

    ShaderEffect {
        id: warpFx

        property variant source: compTex
        property real amount: 11 * root.unit * WM.warpAmount(root.warpU)
        property real phase: WM.warpPhase(root.warpU)
        property real freq: 2 * Math.PI / (200 * root.unit)
        property real sweep: WM.sweepPos(root.sweepU)
        property real sweepWidth: 0.09
        property real sweepStrength: root.sweepU > 0 && root.sweepU < 1 ? 1 : 0
        property size size: Qt.size(width, height)

        x: comp.x
        y: comp.y
        width: comp.width
        height: comp.height
        visible: root.warping
        mesh: GridMesh { resolution: Qt.size(56, 8) }
        vertexShader: Directories.shader("welcome_warp.vert.qsb")
        fragmentShader: Directories.shader("welcome_warp.frag.qsb")
    }

    // ---- the ignition at the middle, and the small flash where the exit meets ----
    WelcomeIgnition {
        x: root.origin.x - root.pad
        y: root.origin.y - root.pad
        z: 5
        size: root.size * 1.15
        unit: root.unit
        run: root.leaving ? 0 : WM.ignitionRun(root.reveal)
        flash: WM.leaveFlash(root.leave)
        glowColor: root.haloColor
        ringColor: Qt.tint(root.haloColor, Qt.rgba(1, 1, 1, 0.6))
        starFill: root.sparkFill
        starInk: root.ink
    }
}
