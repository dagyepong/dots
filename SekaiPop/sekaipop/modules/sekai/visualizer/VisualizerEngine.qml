import QtQuick
import "ChartMath.js" as Chart

// Turns the analyzer's (or cava's) bands into what SekaiVisualizer.qml draws. The deciding
// (when a note is hit, which lane, when the slide runs, what the beat is) lives
// in ChartMath.js so it can be tested without Quickshell; this file folds the
// bands into 12 lanes, feeds that, and turns what comes back into the
// signals: lane levels every frame, and a note / ribbon sample per hit.
//
//   lane levels   24 cava bands folded into 12 lanes, fast attack / slow release
//   notes         one per hit: tap (cyan), flick (red, high lanes), critical
//                 (gold, a beat-aligned bass hit or a very strong one). A note is
//                 spawned at the line the moment its sound happens, then recedes
//   slide         a green ribbon that follows the melody lanes while there is
//                 sustained tonal energy; a head note marks where it starts / ends
//   beat          the tempo and phase are tracked, so off-beat jitter is dropped
//                 and the bass pulse follows the beat
//
// Notes and ribbon samples are sent ONCE, time-stamped, through signals
// (noteSpawned / ribbonWritten). SekaiVisualizer.qml turns a note into a sticker
// over its lane and the ribbon into the slide keycap. `time` wraps at `period`.
//
// Two sources. With the analyzer (`analyzer: true`, scripts/cava/sekai_analyzer.py)
// the widget calls feed() once per analyzer frame: the bands drive the lane
// meters and the analyzer's hits (kick, snare, hat, bass note) and lead tone
// become the notes and the slide (ChartMath.stepLive). Without it, `raw` holds
// cava's bands and the notes are guessed from them (ChartMath.step).
//
// `demo` feeds it a synthetic song instead of cava: Edit Desktop uses it so the
// widget (and its picture on the shelf) show something without any audio.
//
// Ticks only while there is something to animate.
Item {
    id: root
    visible: false

    property bool active: true
    property bool demo: false
    property real sensitivity: 1
    property real maxValue: 1000
    // The raw bands from cava (24 numbers, 0..maxValue). Set by the widget.
    property var raw: []
    // True while the analyzer is the audio tap (see the header).
    property bool analyzer: false
    property real frameGap: 0.028

    readonly property int lanes: 12
    readonly property int slots: 24
    readonly property real period: 1024

    property real time: 0
    property real bass: 0
    property real fade: 0
    // Mutated in place every frame, read them from frame()
    readonly property var levels: new Array(12).fill(0)

    signal frame()
    signal noteSpawned(int slot, real lane, real width, real t0, real code)
    signal ribbonWritten(int slot, real x, real w, real pulse, real t0)
    signal cleared()
    // Every hit the analyzer (or the demo) names, as it is heard, before the
    // chart-writer above has thinned it for a rhythm game: kind "k" kick, "s"
    // snare, "h" hat, "b" bass note; strength 0..1; lane 0..12 (same lanes as
    // noteSpawned). The key-bed presses on these so it answers every hit.
    signal heard(string kind, real strength, real lane)

    property real lastSignal: 0
    property int noteHead: 0
    property int ribbonHead: 0
    property int idleSamples: 99
    property var chart: Chart.create()

    // What the analyzer said since the last step(): hits are queued so none is
    // lost when two analyzer frames land between two rendered frames.
    property var pendingEvents: []
    property real pendingOnset: 0
    property var leadTone: null
    property var pendingBeat: null
    property int snareSide: 0
    property double lastKickAt: 0

    // One analyzer frame: { b: [24 bands], o, e: [hits], v: [pos, clarity], t: [bpm, conf, ago] }.
    function feed(f) {
        if (!root.active || root.demo) return;
        if (f.e && f.e.length > 0) {
            if (root.pendingEvents.length > 64) root.pendingEvents = [];
            root.pendingEvents = root.pendingEvents.concat(f.e);
        }
        root.pendingOnset += f.o || 0;
        if (f.t) root.pendingBeat = f.t;
        root.leadTone = f.v || null;
        root.raw = f.b || [];
    }

    // Tell the listeners (see `heard`) about the hits in one analysis. Lanes are
    // the chart-writer's: KICK_LANE 1.6, SNARE_LANE 6.0 +- 0.6, HAT_LANE 10.4 and
    // BASS_LANES 0.7 .. 3.3 (ChartMath.js) - keep them in step.
    function announce(events) {
        if (!events) return;
        const floor = 0.14 / Math.max(0.5, root.sensitivity);
        const now = Date.now();
        for (let i = 0; i < events.length; i++) {
            const e = events[i];
            const kind = e[0];
            const st = e[1];
            if (st < floor) continue;
            if (kind === "k") {
                root.lastKickAt = now;
                root.heard("k", st, 1.6);
            } else if (kind === "s") {
                root.snareSide = 1 - root.snareSide;
                root.heard("s", st, 6.0 + (root.snareSide ? 0.6 : -0.6));
            } else if (kind === "h") {
                root.heard("h", st, 10.4);
            } else if (kind === "b") {
                // a kick has just pressed the middle: the bass note under it is the same thump
                if (now - root.lastKickAt < 250) continue;
                root.heard("b", st, Chart.laneOf(e.length > 2 ? e[2] : 0.5, [0.7, 3.3]));
            }
        }
    }

    function takeAnalysis() {
        const an = { o: root.pendingOnset, e: root.pendingEvents, v: root.leadTone, t: root.pendingBeat };
        root.pendingBeat = null;
        root.pendingEvents = [];
        root.pendingOnset = 0;
        return an;
    }

    // The made-up song's hits and singer, for the demo (same timing as synth()):
    // what the analyzer would have said between t0 and t1.
    function demoAnalysis(t0, t1) {
        const ev = [];
        function crossed(period, offset) {
            return Math.floor((t1 + offset) / period) > Math.floor((t0 + offset) / period);
        }
        if (t1 > t0) {
            if (crossed(0.5, 0)) ev.push(["k", 0.8]);
            if (crossed(1.0, 0.5)) ev.push(["s", 0.7]);
            if (crossed(0.25, 0.125)) ev.push(["h", 0.5]);
        }
        const ph = t1 % 8;
        const singing = (ph > 0.5 && ph < 2.7) || (ph > 3.6 && ph < 5.0) || (ph > 6.0 && ph < 7.4);
        const pos = 0.5 + 0.3 * Math.sin(t1 * 0.8) + 0.1 * Math.sin(t1 * 2.1);
        return { o: ev.length > 0 ? 1 : 0, e: ev, v: singing ? [pos, 0.95] : null };
    }

    onRawChanged: {
        if (!root.active || root.demo) return;
        for (let i = 0; i < root.raw.length; i++) {
            if (root.raw[i] > 0) {
                root.lastSignal = Date.now();
                ticker.running = true;
                return;
            }
        }
    }

    onDemoChanged: {
        if (root.demo) ticker.running = true;
    }

    // A made-up song: kick on the beat, hats, a snare, and a melody that wanders.
    function synth(t) {
        const out = new Array(24).fill(0);
        const kick = Math.exp(-9 * (t % 0.5));
        for (let i = 0; i < 6; i++) out[i] += 800 * kick * (1 - i / 8);
        const hat = Math.exp(-14 * ((t + 0.125) % 0.25));
        for (let i = 16; i < 24; i++) out[i] += 380 * hat * (0.6 + 0.4 * Math.sin(t * 3 + i));
        const snare = Math.exp(-10 * ((t + 0.5) % 1.0));
        for (let i = 7; i < 14; i++) out[i] += 600 * snare;
        const mc = 9 + 6 * Math.sin(t * 0.9) + 2 * Math.sin(t * 2.3);
        for (let i = 0; i < 24; i++) {
            const d = (i - mc) / 2.2;
            out[i] = Math.min(1000, out[i] + 520 * Math.exp(-d * d) * (0.7 + 0.3 * Math.sin(t * 5)));
        }
        return out;
    }

    function spawn(lane, width, type, strength) {
        const slot = root.noteHead;
        root.noteHead = (slot + 1) % root.slots;
        root.noteSpawned(slot, lane, width, root.time, type + Math.min(0.99, strength));
    }

    function writeRibbon(x, w, pulse) {
        const slot = root.ribbonHead;
        root.ribbonHead = (slot + 1) % root.slots;
        root.ribbonWritten(slot, x, w, pulse, root.time);
    }

    function wipe() {
        for (let i = 0; i < root.slots; i++) {
            root.noteSpawned(i, 0, 0, 0, 0);
            root.ribbonWritten(i, 0, 0, 0, 0);
        }
    }

    function reset() {
        root.noteHead = 0;
        root.ribbonHead = 0;
        root.idleSamples = 99;
        root.chart = Chart.create();
        root.pendingEvents = [];
        root.pendingOnset = 0;
        root.pendingBeat = null;
        root.leadTone = null;
        for (let i = 0; i < root.lanes; i++)
            root.levels[i] = 0;
        root.bass = 0;
        root.cleared();
    }

    function step(dt) {
        const playing = root.demo || Date.now() - root.lastSignal < 1000;
        const src = root.demo ? root.synth(root.time) : root.raw;
        const before = root.time;
        root.time = (root.time + dt) % root.period;
        // `time` just wrapped: anything still sitting in a slot would read as
        // brand new again, so empty every slot (once every ~17 minutes).
        if (root.time < before) root.wipe();
        root.fade += ((playing ? 1 : 0) - root.fade) * Math.min(1, dt * (playing ? 4 : 1.5));

        // fold the bands into lanes
        const n = src.length;
        const target = new Array(12).fill(0);
        if (playing && n > 0) {
            for (let i = 0; i < root.lanes; i++) {
                const from = Math.floor(i * n / root.lanes);
                const to = Math.max(from + 1, Math.floor((i + 1) * n / root.lanes));
                let sum = 0;
                for (let k = from; k < to; k++) sum += src[k];
                target[i] = Math.min(1, root.sensitivity * sum / (to - from) / root.maxValue);
            }
        }
        // Demo and analyzer: the hits arrive named. Otherwise they are guessed.
        let out;
        if (root.demo || root.analyzer) {
            const an = root.demo ? root.demoAnalysis(before, root.time) : root.takeAnalysis();
            if (playing)
                root.announce(an.e);
            out = Chart.stepLive(root.chart, dt, target, an, playing, root.sensitivity);
        } else {
            out = Chart.step(root.chart, dt, target, playing);
        }
        for (let i = 0; i < root.lanes; i++)
            root.levels[i] = root.chart.levels[i];
        root.bass = out.bass;

        for (const note of out.notes)
            root.spawn(note.lane, note.width, note.type, note.strength);
        for (const x of out.heads)
            root.spawn(x, 1.6, 3, 0.5);

        if (out.ribbon) {
            if (out.ribbon.on) {
                root.writeRibbon(out.ribbon.x, out.ribbon.w, root.bass);
                root.idleSamples = 0;
            } else if (root.idleSamples < root.slots + 1) {
                // an empty sample closes the ribbon; a full ring of them clears it
                root.writeRibbon(0, 0, 0);
                root.idleSamples++;
            }
        }

        root.frame();
        if (!playing && root.fade < 0.002) {
            root.fade = 0;
            ticker.running = false;
            root.reset();
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
