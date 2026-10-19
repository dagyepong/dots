import QtQuick

// Port of end4-pC's VisualizerEngine.qml (modules/ii/background/widgets/visualizer).
// Turns the raw cava levels into what the shader styles draw: smoothed levels
// (fast attack, slow release), falling peaks, a beat pulse and a playback fade.
// Ticks only while there is something to animate, and emits frame() after each step.
//
// Two differences from end4's, both because sekaipop has no GlobalStates:
//   - the bands come in through `raw` (VisualizerWidget.qml sets it from its cava
//     process, scripts/cava/cava-pc.conf) instead of GlobalStates.visualizerPoints;
//   - `demo` plays a made-up spectrum so Edit Desktop (and the shelf's picture of
//     the widget) show something without any audio.
// `frameGap` is the same perf knob the Sekai card has (0 = every frame).
Item {
    id: root
    visible: false

    property bool active: true
    property bool demo: false
    property real sensitivity: 1
    property real maxValue: 1000
    property real frameGap: 0
    // The bands from cava (50 numbers, 0..maxValue). Set by the widget.
    property var raw: []

    readonly property int maxBands: 52
    property int bandCount: 0
    property real time: 0
    property real bass: 0
    property real fade: 0
    // Mutated in place every frame, read them from frame()
    readonly property var levels: new Array(maxBands).fill(0)
    readonly property var peaks: new Array(maxBands).fill(0)

    signal frame()

    property real lastSignal: 0
    property real bassAverage: 0
    readonly property var peakHold: new Array(maxBands).fill(0)

    onRawChanged: {
        if (!root.active || root.demo) return;
        if (root.raw.length > 0) root.bandCount = Math.min(root.raw.length, root.maxBands);
        for (let i = 0; i < root.raw.length; i++) {
            if (root.raw[i] > 0) {
                root.lastSignal = Date.now();
                ticker.running = true;
                return;
            }
        }
    }

    onDemoChanged: {
        if (root.demo) {
            root.bandCount = 50;
            ticker.running = true;
        }
    }

    // A made-up song: a kick on the beat, a snare, hats, and a melody that wanders.
    function synth(t) {
        const out = new Array(50).fill(0);
        const kick = Math.exp(-9 * (t % 0.5));
        for (let i = 0; i < 12; i++) out[i] += 800 * kick * (1 - i / 16);
        const snare = Math.exp(-10 * ((t + 0.5) % 1.0));
        for (let i = 14; i < 28; i++) out[i] += 600 * snare;
        const hat = Math.exp(-14 * ((t + 0.125) % 0.25));
        for (let i = 33; i < 50; i++) out[i] += 380 * hat * (0.6 + 0.4 * Math.sin(t * 3 + i));
        const mc = 18 + 12 * Math.sin(t * 0.9) + 4 * Math.sin(t * 2.3);
        for (let i = 0; i < 50; i++) {
            const d = (i - mc) / 4.4;
            out[i] = Math.min(1000, out[i] + 520 * Math.exp(-d * d) * (0.7 + 0.3 * Math.sin(t * 5)));
        }
        return out;
    }

    function step(dt) {
        const playing = root.demo || Date.now() - root.lastSignal < 1000;
        const src = root.demo ? root.synth(root.time + dt) : root.raw;
        root.time += dt;
        root.fade += ((playing ? 1 : 0) - root.fade) * Math.min(1, dt * (playing ? 4 : 1.5));

        let bassNow = 0;
        for (let i = 0; i < root.maxBands; i++) {
            const target = playing && i < src.length ? Math.min(1, src[i] / root.maxValue * root.sensitivity) : 0;
            const level = root.levels[i];
            root.levels[i] = level + (target - level) * Math.min(1, dt * (target > level ? 18 : 5));
            if (root.levels[i] >= root.peaks[i]) {
                root.peaks[i] = root.levels[i];
                root.peakHold[i] = 0.35;
            } else if (root.peakHold[i] > 0) {
                root.peakHold[i] -= dt;
            } else {
                root.peaks[i] = Math.max(root.levels[i], root.peaks[i] - dt * 0.45);
            }
            if (i < 4) bassNow += target / 4;
        }

        // A beat is bass energy rising well above its recent average
        root.bassAverage += (bassNow - root.bassAverage) * Math.min(1, dt * 1.5);
        if (bassNow > root.bassAverage * 1.3 + 0.04 && bassNow > 0.25)
            root.bass = Math.min(1, root.bass + (bassNow - root.bassAverage) * 2.5);
        root.bass *= Math.exp(-dt * 5);

        root.frame();
        if (!playing && root.fade < 0.002) {
            root.fade = 0;
            ticker.running = false;
        }
    }

    FrameAnimation {
        id: ticker

        property real acc: 0

        running: false
        onTriggered: {
            acc += frameTime
            if (acc < root.frameGap)
                return
            root.step(Math.min(acc, 0.1))
            acc = 0
        }
    }
}
