import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.modules.common
import qs.modules.common.widgets

// One chunky sticker glyph: the building block of the SekaiPop logo and of the
// big icon on the welcome screen's second slide. It is the look of the logo in
// the reference video, layer by layer, and every layer can be driven on its own:
//
//   extrusion      the hard shadow, down and to the right (`extrudeBuild`; above
//                  1 it reaches out past its length for a moment)
//   gradient rim   the dimensional outline: lighter at the top, deep at the
//                  bottom (`outlineBuild` grows it)
//   fill           the pastel with a soft gloss, lighter on top, deeper below
//   wave texture   two soft bands that rise from the bottom and flow along the
//                  letter (`waveRun` raises them, `wavePhase` moves them)
//   halftone       dots (shaders/welcome_dots.frag): a shading that stays in the
//                  lower right corner (`dotsRun`), a matte band that crosses the
//                  letter and swells the dots under it (`matteRun`, -1 = off),
//                  and a drift that slides the lattice (`dotDrift`)
//   hard shine     a crisp slanted glint that sweeps across (`shineRun`)
//
// Text has no stroke of its own, so the rim and the extrusion are cut from one
// picture of the string drawn round a small circle (eighteen copies: the edge is
// smooth). The picture is drawn once into a texture; the extrusion is that
// texture shown several times along a line (cheap, and solid, with no steps),
// and the gradient rim is a gradient cut out of the same picture. The fill is a
// flat colour block with the gloss, the waves and the dots on it, cut to the
// letter's shape by a mask (MultiEffect), so all of it follows the letter's
// curves.
//
//   WelcomeLetter { text: "S"; pixelSize: 120; fill: "#a0e78f" }
//
// `build` (0..1) is how much of the outline and the extrusion is drawn: 0 is the
// bare, glossy letter ("Base" in the video), 1 the finished sticker.
Item {
    id: root

    property string text: ""
    property string family: Theme.fontFamily
    property int pixelSize: 100
    property int weight: Font.Black
    // Font variation axes (Qt 6.7+), e.g. { "ROND": 100, "wdth": 118 }.
    property var axes: ({})

    property color fill: "#a0e78f"
    property color outlineColor: "#1c2a20"
    property color glossColor: "#ffffff"
    property color dotColor: Qt.darker(root.fill, 1.4)
    // the rim's gradient: this at the top of the letter, outlineColor at the bottom
    property color rimLight: Qt.tint(root.outlineColor, Qt.rgba(1, 1, 1, 0.34))
    property int ringSteps: 18
    // Which parts of the letter are built:
    //   "all"   everything, with the letter's own halftone, waves and shine (the
    //           big icon on the second slide is one letter on its own)
    //   "back"  only the rim and the extrusion
    //   "face"  only the flat face: the fill and the gloss, no textures
    // The logo builds every letter twice, a back and a face, so that all the
    // outlines of a line sit behind all its faces, and puts one halftone, one wave
    // and one shine over the faces of the whole word (WelcomeLogo.qml), cut to
    // the letters like a track matte, instead of one set of textures per letter.
    // (A part that is off is emptied, not unhooked: a ShaderEffectSource with no
    // source un-hides the item it was hiding, and the raw item would be drawn.)
    property string part: "all"

    // Thickness of the dark rim, and how far the extrusion reaches (right / down).
    property real outline: Math.max(2, root.pixelSize * 0.07)
    property real extrudeX: root.pixelSize * 0.05
    property real extrudeY: root.pixelSize * 0.075
    property real build: 1
    property real outlineBuild: root.build
    property real extrudeBuild: root.build
    property real dotsRun: 1
    property real waveRun: 1
    property real wavePhase: 0
    property real shineRun: 1
    // the halftone's matte band (0..1 across the letter, -1 = not running) and the
    // lattice's drift (0..1 = one period, seamless)
    property real matteRun: -1
    property real dotDrift: 0
    property bool halftone: true
    property bool wave: true
    property real dotSpacing: Math.max(4, root.pixelSize * 0.062)

    // Blur of the whole sticker (0..1), for letters that arrive out of focus.
    // The sticker is drawn into a layer only while this is above 0.
    property real blur: 0

    // The polygon of one wave band: a ripple along its top edge (`cycles` of it
    // across the width, slid by `phase`), closed along the bottom.
    function wavePoints(bw, bh, edge, amp, cycles, phase) {
        const a = [];
        const n = 24;
        a.push(Qt.point(0, bh + 2));
        for (let i = 0; i <= n; i++)
            a.push(Qt.point(bw * i / n, edge + amp * Math.sin(2 * Math.PI * (i / n * cycles + phase))));
        a.push(Qt.point(bw, bh + 2));
        return a;
    }

    // Where the letter's ink is inside its box (the box is the line, taller than
    // a small letter like "a"): the gloss, the dots, the wave and the shine are
    // laid out on this, so they fall on the letter and not in the empty space
    // above or below it. Falls back to the whole box if the font gives nothing.
    FontMetrics {
        id: fm
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        font.variableAxes: root.axes
    }
    // (tightBoundingRect() does not announce a change of font or size, so this
    // reads the metrics' ascent and descent first: they do, and the measurement is
    // taken again whenever the font really changes. Taken once, it went stale when
    // the size or the font arrived after the letter was made, and the rim's
    // gradient then covered a strip of the letter instead of all of it.)
    readonly property rect tight: (fm.ascent + fm.descent > 0) ? fm.tightBoundingRect(root.text) : Qt.rect(0, 0, 0, 0)
    readonly property bool hasInk: root.tight.width > 2 && root.tight.height > 2
    readonly property real inkX: root.hasInk ? Math.max(0, root.tight.x) : 0
    readonly property real inkY: root.hasInk ? Math.max(0, fm.ascent + root.tight.y) : 0
    readonly property real inkW: root.hasInk ? Math.min(root.tight.width, root.implicitWidth - root.inkX) : root.implicitWidth
    readonly property real inkH: root.hasInk ? Math.min(root.tight.height, root.implicitHeight - root.inkY) : root.implicitHeight

    readonly property bool showBack: root.part !== "face"
    readonly property bool showFace: root.part !== "back"
    readonly property bool localFx: root.part === "all"

    // How far past the letter's own box the rim and the extrusion reach.
    readonly property real reach: root.outline + Math.max(root.extrudeX, root.extrudeY) * 1.35

    implicitWidth: Math.ceil(probe.implicitWidth)
    implicitHeight: Math.ceil(probe.implicitHeight)

    // Only used to measure the string.
    Text {
        id: probe
        visible: false
        text: root.text
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        font.variableAxes: root.axes
    }

    // The same string drawn `steps` times round a circle of `radius`.
    component Ring: Item {
        id: ring

        property color ink: "#000000"
        property real radius: 4
        property real dx: 0
        property real dy: 0
        property int steps: 18

        visible: ring.radius > 0.05

        Repeater {
            model: ring.steps

            Text {
                required property int index

                x: ring.dx + Math.cos(index * 2 * Math.PI / ring.steps) * ring.radius
                y: ring.dy + Math.sin(index * 2 * Math.PI / ring.steps) * ring.radius
                width: ring.width
                height: ring.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.text
                color: ring.ink
                font.family: root.family
                font.pixelSize: root.pixelSize
                font.weight: root.weight
                font.variableAxes: root.axes
            }
        }
    }

    // `box` is bigger than the letter on every side (the rim and the shadow reach
    // past the letter's own box), so that when it is drawn into a layer to blur
    // it nothing is cut off. `stack` is the letter's own box inside it.
    Item {
        id: box
        x: -root.reach
        y: -root.reach
        width: root.implicitWidth + 2 * root.reach
        height: root.implicitHeight + 2 * root.reach

        layer.enabled: root.blur > 0.001
        layer.smooth: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 26
            blur: root.blur
        }

    Item {
        id: stack
        x: root.reach
        y: root.reach
        width: root.implicitWidth
        height: root.implicitHeight

        // the rim and the extrusion are cut from this: the string drawn round a
        // circle, once, into a texture (a layer clips to its own box, so the box
        // is the one that already has room for the rim and the extrusion)
        Item {
            id: rimSrc

            x: -root.reach
            y: -root.reach
            width: root.implicitWidth + 2 * root.reach
            height: root.implicitHeight + 2 * root.reach

            Ring {
                x: root.reach
                y: root.reach
                width: root.implicitWidth
                height: root.implicitHeight
                ink: root.outlineColor
                radius: root.outline * root.outlineBuild
                steps: root.showBack ? root.ringSteps : 0
            }
        }

        // (A ShaderEffectSource with hideSource, not a hidden layer: a layer on
        // an invisible item is not redrawn when what is in it changes, and the
        // rim grows while the letter pops.)
        ShaderEffectSource {
            id: rimTex

            sourceItem: rimSrc
            hideSource: true
            visible: false
            x: rimSrc.x
            y: rimSrc.y
            width: rimSrc.width
            height: rimSrc.height
        }

        // hard shadow: that texture again, a few times along the way down and to
        // the right, so the copies join into one solid extrusion
        Repeater {
            model: root.showBack ? 7 : 0

            ShaderEffect {
                required property int index

                readonly property real t: (index + 1) / 7

                property variant source: rimTex

                x: rimTex.x + root.extrudeX * root.extrudeBuild * t
                y: rimTex.y + root.extrudeY * root.extrudeBuild * t
                width: rimTex.width
                height: rimTex.height
                visible: root.extrudeBuild > 0.001
            }
        }

        // the gradient for the rim: light on top, deep below, on the letter's ink
        Item {
            id: rimGrad

            x: rimSrc.x
            y: rimSrc.y
            width: rimSrc.width
            height: rimSrc.height

            Rectangle {
                y: root.reach + root.inkY - root.outline
                width: parent.width
                height: root.inkH + 2 * root.outline
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.rimLight }
                    GradientStop { position: 1.0; color: root.outlineColor }
                }
            }
        }

        ShaderEffectSource {
            id: rimGradTex

            sourceItem: rimGrad
            hideSource: true
            visible: false
            x: rimGrad.x
            y: rimGrad.y
            width: rimGrad.width
            height: rimGrad.height
        }

        // the rim: the gradient, cut to the ring
        MultiEffect {
            x: rimSrc.x
            y: rimSrc.y
            width: rimSrc.width
            height: rimSrc.height
            source: rimGradTex
            maskEnabled: true
            maskSource: rimTex
            autoPaddingEnabled: false
            visible: root.showBack && root.outlineBuild > 0.001
        }

        // the fill: colour block cut to the letter by the mask text
        Text {
            id: maskText
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.text
            color: "#ffffff"
            font.family: root.family
            font.pixelSize: root.pixelSize
            font.weight: root.weight
            font.variableAxes: root.axes
        }

        ShaderEffectSource {
            id: maskTex

            sourceItem: maskText
            hideSource: true
            visible: false
            anchors.fill: parent
        }

        Item {
            id: colorBlock
            anchors.fill: parent

            // the pastel everywhere, so nothing of the letter is ever bare
            Rectangle {
                anchors.fill: parent
                color: root.fill
            }

            // Everything below is laid out on the letter's ink, not on its line box.
            Item {
                id: ink

                x: root.inkX
                y: root.inkY
                width: root.inkW
                height: root.inkH

                // light at the top, the pastel in the middle, a deeper shade at the
                // bottom: the video's letters are round and glossy, not flat
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(root.fill, 1.22) }
                        GradientStop { position: 0.5; color: root.fill }
                        GradientStop { position: 1.0; color: Qt.darker(root.fill, 1.1) }
                    }
                }

                // the wave texture: two soft bands along the bottom of the letter, a
                // deeper one and a pale crest above it, their tops ripples that flow
                // along at different speeds (the video's "Animated Wave Texture").
                // They rise from the bottom as the letter lands and keep flowing.
                Shape {
                    id: waveBand

                    readonly property real bw: ink.width
                    readonly property real bh: ink.height
                    readonly property real edge: bh * (1 - 0.40 * root.waveRun)
                    readonly property var deep: root.wavePoints(bw, bh, edge, bh * 0.05, 1.5, root.wavePhase)
                    readonly property var crest: root.wavePoints(bw, bh, edge - bh * 0.075, bh * 0.045, 2.2, 0.35 - root.wavePhase * 2)

                    anchors.fill: parent
                    visible: root.localFx && root.wave && root.waveRun > 0.001
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: "transparent"
                        strokeWidth: 0
                        fillColor: Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, 0.42)

                        PathPolyline { path: waveBand.deep }
                    }

                    ShapePath {
                        strokeColor: "transparent"
                        strokeWidth: 0
                        fillColor: Qt.rgba(root.glossColor.r, root.glossColor.g, root.glossColor.b, 0.2 * root.waveRun)

                        PathPolyline { path: waveBand.crest }
                    }
                }

                // The halftone (shaders/welcome_dots.frag): a shading in the lower
                // right corner that stays, a matte band that crosses the letter and
                // swells the dots under it, and a lattice that drifts.
                ShaderEffect {
                    id: dots

                    property color dotColor: Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, 1)
                    property size size: Qt.size(width, height)
                    property real spacing: root.dotSpacing
                    property real shade: root.dotsRun
                    property real matte: root.matteRun
                    property real drift: root.dotDrift
                    property real amount: 0.92
                    property real falloff: 0.78

                    anchors.fill: parent
                    visible: root.localFx && root.halftone && (root.dotsRun > 0.001 || root.matteRun >= 0)
                    fragmentShader: Directories.shader("welcome_dots.frag.qsb")
                }

                // The same shading as plain dots, only if the shader was never
                // built (run shaders/compile-shaders.sh).
                DotField {
                    anchors.fill: parent
                    visible: root.localFx && root.halftone && root.dotsRun > 0.001 && dots.status === ShaderEffect.Error
                    opacity: Math.min(1, root.dotsRun * 2)
                    scale: root.dotsRun
                    transformOrigin: Item.BottomRight
                    corner: "br"
                    reach: 0.7
                    spacing: root.dotSpacing
                    maxRadius: root.dotSpacing * 0.4
                    dotColor: Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, 0.9)
                }

                // the soft gloss along the top of the letter, and a small round
                // highlight at its left end
                Rectangle {
                    x: parent.width * 0.1
                    y: parent.height * 0.1
                    width: parent.width * 0.5
                    height: Math.max(3, parent.height * 0.1)
                    radius: height / 2
                    color: Qt.rgba(root.glossColor.r, root.glossColor.g, root.glossColor.b, 0.55)
                }

                Rectangle {
                    x: parent.width * 0.05
                    y: parent.height * 0.1
                    width: Math.max(3, parent.height * 0.08)
                    height: width
                    radius: width / 2
                    color: Qt.rgba(root.glossColor.r, root.glossColor.g, root.glossColor.b, 0.55)
                }

                // the hard shine: two slanted bands with hard edges that sweep
                // across the letter once (left to right) and are gone
                Item {
                    anchors.fill: parent
                    visible: root.localFx && root.shineRun > 0.001 && root.shineRun < 0.999

                    Rectangle {
                        x: parent.width * (-0.45 + 1.8 * root.shineRun)
                        y: -parent.height * 0.4
                        width: parent.width * 0.17
                        height: parent.height * 1.8
                        rotation: 24
                        color: Qt.rgba(root.glossColor.r, root.glossColor.g, root.glossColor.b, 0.62)
                    }

                    Rectangle {
                        x: parent.width * (-0.45 + 1.8 * root.shineRun) - parent.width * 0.15
                        y: -parent.height * 0.4
                        width: parent.width * 0.05
                        height: parent.height * 1.8
                        rotation: 24
                        color: Qt.rgba(root.glossColor.r, root.glossColor.g, root.glossColor.b, 0.5)
                    }
                }
            }
        }

        ShaderEffectSource {
            id: colorTex

            sourceItem: colorBlock
            hideSource: true
            visible: false
            anchors.fill: parent
        }

        MultiEffect {
            anchors.fill: parent
            source: colorTex
            maskEnabled: true
            maskSource: maskTex
            autoPaddingEnabled: false
            visible: root.showFace
        }
    }
    }
}
