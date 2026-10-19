import QtQuick

// "Tide": sekaipop's own audio visualizer (not from end4-pC). Three sheets of cut paper,
// stacked like a scrapbook page, rise out of the bottom of the screen with the music:
//
//   - the spectrum is folded round the middle (the bass in the centre, the highs out at
//     the edges), so it reads as one swell, like a stage
//   - every sheet is one smooth curve (a spline through the points), not a polygon, and swells roll along it slowly, a little faster with the
//     music, so it moves like water; a pale foam line runs along each crest
//   - the back sheet is slow and tall-ish, the middle one quicker, the front one follows the
//     bands as they come (fast attack from ShaderVisualizerEngine, slow fall)
//   - every sheet is flat colour with the shell's navy outline and a hard, flat shadow
//     on the sheet behind it (the same drop shadow the pills have)
//   - nine paper pins ride the front crest: a diamond on a short stem that holds each
//     lane's falling peak (the engine's peaks) a little above the water
//   - a beat (the engine's bass pulse) lifts the whole tide for a moment
//   - the swells under it all keep a quiet passage moving
//
// Drawing: one fragment shader (TideShaderLayer.qml + shaders/visualizer/tide.frag,
// compiled to tide.frag.qsb with shaders/visualizer/build.sh; there is no QML fallback,
// so the .qsb has to exist). The motion (the smoothing, the swells, the pins' heights) is
// the JS in rebuild() below, which hands the shader the finished crest heights.
// Fed by the widget's
// ShaderVisualizerEngine (50 bands), so it follows the same cava tap, sensitivity,
// fade and demo song as the end4 styles. Colours: color1 = middle sheet, color2 = back,
// color3 = front (the widget's palette). `lite` (Visualizer performance: Lite) drops the
// shadows and halves the number of points.
Item {
    id: root

    required property ShaderVisualizerEngine engine
    property color color1: "#8EE3EF"
    property color color2: "#A5E6A5"
    property color color3: "#FF9ECB"
    property color ink: "#1c2a4a"
    property bool lite: false

    readonly property int cols: root.lite ? 44 : 80
    readonly property real pad: 28
    readonly property real lineW: Math.max(2.5, root.height / 90)
    readonly property real shadowOff: Math.max(4, root.height / 40)
    readonly property color shadowColor: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.28)

    // back, middle, front: where each sits when silent (fraction of the height), how tall
    // the bands push it, how many columns it is blurred over and how fast it follows.
    readonly property var spec: [
        { base: 0.24, amp: 0.55, rad: 9, pass: 4, rate: 2.5, speed: 0.55, len: 3.4 },
        { base: 0.16, amp: 0.78, rad: 6, pass: 3, rate: 5.0, speed: 0.85, len: 4.6 },
        { base: 0.08, amp: 1.0, rad: 4, pass: 3, rate: 11.0, speed: 1.2, len: 6.2 }
    ]
    readonly property var fills: [
        Qt.rgba(root.color2.r, root.color2.g, root.color2.b, 0.94),
        root.color1,
        Qt.lighter(root.color3, 1 + 0.25 * root.engine.bass)
    ]
    // Where the pins stand along the width (fractions), centre first.
    readonly property var laneX: [0.5, 0.4, 0.6, 0.29, 0.71, 0.17, 0.83, 0.05, 0.95]

    property var st: [[], [], []]
    property real lastT: 0
    property real bassSmooth: 0

    // One pass of a [1 4 6 4 1] / 16 kernel (the ends stay put): a few of these in a row
    // round every bump off the way a gaussian blur would.
    function blur(a) {
        const n = a.length
        const out = new Array(n)
        for (let i = 0; i < n; i++) {
            const m2 = a[Math.max(0, i - 2)], m1 = a[Math.max(0, i - 1)]
            const p1 = a[Math.min(n - 1, i + 1)], p2 = a[Math.min(n - 1, i + 2)]
            out[i] = (m2 + 4 * m1 + 6 * a[i] + 4 * p1 + p2) / 16
        }
        return out
    }

    visible: engine.fade > 0.003
    opacity: Math.min(1, engine.fade * 2)
    // rises into place as the music starts
    transform: Translate { y: (1 - Math.min(1, root.engine.fade)) * root.height * 0.18 }

    function resetState() {
        const n = root.cols + 1
        root.st = [new Array(n).fill(0), new Array(n).fill(0), new Array(n).fill(0)]
    }

    onColsChanged: root.resetState()
    Component.onCompleted: root.resetState()

    function rebuild() {
        const e = root.engine
        const W = root.width, H = root.height
        if (W <= 0 || H <= 0) return
        const n = root.cols
        if (root.st[0].length !== n + 1) root.resetState()
        const nb = e.bandCount > 1 ? e.bandCount : 50
        let dt = e.time - root.lastT
        root.lastT = e.time
        if (dt <= 0 || dt > 0.2) dt = 0.03
        const lv = e.levels, pk = e.peaks
        const span = W + 2 * root.pad
        // the beat's lift is eased too, so it swells instead of jumping
        root.bassSmooth += (e.bass - root.bassSmooth) * Math.min(1, dt * 8)
        const ampMul = 1 + 0.35 * root.bassSmooth

        // the spectrum folded round the middle, the highs lifted a little
        const raw = new Array(n + 1)
        let mean = 0
        for (let c = 0; c <= n; c++) {
            const d = Math.abs(c / n - 0.5) * 2
            const f = d * (nb - 1) * 0.8
            const i0 = Math.floor(f)
            const i1 = Math.min(nb - 1, i0 + 1)
            const t = f - i0
            raw[c] = Math.pow(Math.min(1, (lv[i0] * (1 - t) + lv[i1] * t) * (1 + d * 1.1)), 0.8)
            mean += raw[c] / (n + 1)
        }
        // how big the rolling swells are: a little always, more with the music
        const swellAmp = (0.02 + 0.05 * Math.min(1, mean * 2.5)) * H * e.fade

        const xs = new Array(n + 1)
        for (let c = 0; c <= n; c++) xs[c] = -root.pad + c / n * span

        let tops = null
        for (let k = 0; k < 3; k++) {
            const L = root.spec[k]
            const s = root.st[k]
            const a = Math.min(1, dt * L.rate)
            const ys = new Array(n + 1)
            for (let c = 0; c <= n; c++) {
                let sum = 0, cnt = 0
                for (let j = -L.rad; j <= L.rad; j++) {
                    const cc = c + j
                    if (cc < 0 || cc > n) continue
                    sum += raw[cc]
                    cnt++
                }
                s[c] += (sum / cnt - s[c]) * a
            }
            let v = s
            for (let q = 0; q < L.pass; q++) v = root.blur(v)
            for (let c = 0; c <= n; c++) {
                const u = xs[c] / W
                // two swells rolling along, the second one slower and shorter
                const swell = swellAmp * (Math.sin(u * L.len - e.time * L.speed + k * 2.1)
                    + 0.5 * Math.sin(u * L.len * 1.9 + e.time * L.speed * 0.6 + k))
                ys[c] = Math.max(6, H - (L.base * H + v[c] * L.amp * H * 0.68 * ampMul + swell))
            }
            shaderLayer.setSheet(k, ys)
            if (k === 2) tops = ys
        }

        // the pins: a diamond held a little above the front crest by the lane's falling peak
        const front = root.spec[2]
        const marks = []
        for (let m = 0; m < root.laneX.length; m++) {
            const xf = root.laneX[m]
            const d = Math.abs(xf - 0.5) * 2
            const f = d * (nb - 1) * 0.8
            const p = Math.min(1, Math.max(pk[Math.floor(f)], pk[Math.min(nb - 1, Math.ceil(f))]) * (1 + d * 1.1))
            const col = Math.max(0, Math.min(n, Math.round((xf * W + root.pad) / span * n)))
            const crest = tops[col]
            const lift = 16 + Math.min(34, p * H * 0.16)
            marks.push({ x: xf * W, y: Math.max(10, crest - lift), cy: crest, a: Math.min(1, p * 4) * e.fade, s: p })
        }

        shaderLayer.setPins(marks)
    }

    Connections {
        target: root.engine
        function onFrame() { root.rebuild() }
    }

    // The shader version (see the top of the file).
    TideShaderLayer {
        id: shaderLayer
        anchors.fill: parent
        ink: root.ink
        shadowColor: root.lite ? "transparent" : root.shadowColor
        fillBack: root.fills[0]
        fillMid: root.fills[1]
        fillFront: root.fills[2]
        columns: root.cols
        pad: root.pad
        lineW: root.lineW
        shadowDrop: root.shadowOff
    }
}
