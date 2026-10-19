pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// The desktop audio visualizer's state: where the card sits, whether it is
// shown, which look and size it has, and how sensitive it is. A singleton like
// ClockService.qml, so anything can flip it without touching the widget:
//
//   import qs.services
//   ...
//   VisualizerService.cycleSize()
//
// VisualizerWidget.qml is the only thing that draws it. Persistence is the same
// convention as ClockService: a tiny shell script (visualizer-state.sh) run as
// a Process. Position is saved straight away, the rest is debounced.
Singleton {
    id: root

    // False until the saved state has been read. Nothing is written before
    // then, or a fresh start would overwrite what's on disk with defaults.
    property bool loaded: false

    // The card itself only shows while audio is playing, so "shown" can stay on
    // without it ever being in the way.
    property bool shown: false       // off until you add it: ipc visualizer toggle / Edit Desktop (a first run shows only the clock)

    // Which look: "sekai" (the keycap card, SekaiVisualizer.qml) or one of end4-pC's
    // visualizers: "bars", "aurora", "dots", "mirror" (a band across the bottom of the
    // screen), "tide" (sekaipop's own: layered paper waves, TideVisualizer.qml), "ribbons" (sekaipop's own: neon ribbon waves, shaders/visualizer/ribbons.frag), "scope" (sekaipop's own: oscilloscope trace with afterglow, shaders/visualizer/scope.frag), "pulse" (sekaipop's own: halftone dot matrix, shaders/visualizer/pulse.frag) and "ring" (a round one, movable like the card). See VisualizerWidget.qml.
    property string style: "sekai"
    readonly property var styles: ["sekai", "bars", "aurora", "ring", "dots", "mirror", "tide", "ribbons", "scope", "pulse"]
    readonly property bool isSekai: root.style === "sekai"
    readonly property bool isRing: root.style === "ring"
    readonly property bool isBand: root.style === "bars" || root.style === "aurora"
        || root.style === "dots" || root.style === "mirror" || root.style === "tide" || root.style === "ribbons" || root.style === "scope" || root.style === "pulse"
    // The band styles stay on the bottom edge; this is the y it was dragged to in
    // Edit Desktop (design pixels), -1 = the bottom.
    property real bandY: -1
    // Bands only: On turns the band on its side, up the screen's right edge (or the left, when it is
    // dragged there in Edit Desktop). bandX is the x it was dragged to, -1 = the right edge.
    property bool vertical: false
    property real bandX: -1
    // The little visualizer inside the media pill in the bar: "none", "dots" (end4's
    // bar visualizer) or "wave" (end4's WaveVisualizer). Fed by PcCavaService.qml.
    property string pillStyle: "none"

    // Colours of the keycaps (and, for the end4 styles, of the shapes): 0 the album cover's own colours (the Sekai pattern
    // while a track has no art), 1 the five card attributes (Cool, Cute, Happy,
    // Mysterious, Pure), 2 the theme's own two accents.
    property int colorMode: 0
    readonly property int colorModeCount: 3
    // 0 S, 1 M, 2 L, 3 XL. See VisualizerWidget.qml.
    property int sizeIndex: 1
    // On: the card stays while a player is paused (so it can be played again from
    // there) and goes when the player is gone. Off: it goes with the music.
    property bool stayWhenPaused: true
    readonly property int sizeCount: 4
    // 0.5 .. 2.5: how hard the lanes are driven (and how easily notes spawn).
    property real sensitivity: 1.0
    // Off: cava (the audio tap) only runs while a media player (MPRIS) is
    // playing. On: it always runs while the card is shown, so games and other
    // apps that don't speak MPRIS drive it too (costs a little CPU).
    property bool alwaysListen: false
    // On: the note analyzer (scripts/cava/sekai_analyzer.py, needs python3 + numpy)
    // is the audio tap and tells kick / snare / hat / bass / a held lead tone
    // apart. Off: plain cava bands, with the older band-based note guessing.
    // The widget also drops back to cava by itself if the analyzer won't start.
    property bool analyzer: true
    // Within the analyzer: use python-aubio (pitch + beat tracker) when it is
    // installed. Off: the built-in numpy pitch tracker and beat guess.
    property bool useAubio: true

    // 0 Full, 1 Balanced, 2 Lite. Lite draws fewer, flat keys at 20 fps and drops the
    // smooth seek-bar glide: far less for a weak GPU to draw and the compositor to blend.
    property int perf: 0
    readonly property int perfCount: 3
    readonly property real frameGap: root.perf >= 2 ? 0.05 : (root.perf === 1 ? 0.036 : 0.028)

    property real posX: -1           // -1 = never placed; widget picks a default
    property real posY: -1
    // The shell scale posX / posY were saved at (see ClockService.qml).
    property real posScale: 0
    property string screenName: ""

    function setPosition(x, y, screen, scale) {
        if (!root.loaded)
            return
        // A band keeps to the bottom edge: only its height is remembered, so the
        // card's own spot (and the ring's) is still there when you switch back.
        if (root.isBand) {
            if (root.vertical)
                root.bandX = x
            else
                root.bandY = y
        } else {
            root.posX = x
            root.posY = y
        }
        if (typeof scale === "number" && scale > 0)
            root.posScale = scale
        if (typeof screen === "string" && screen !== "")
            root.screenName = screen
        saveTimer.stop()
        saver.save(root.snapshot())
    }

    function setShown(value) {
        root.shown = value
        root.persist()
    }

    function setStyle(value) {
        const v = String(value).toLowerCase()
        if (root.styles.indexOf(v) < 0)
            return
        root.style = v
        root.persist()
    }

    function cycleStyle() {
        root.setStyle(root.styles[(root.styles.indexOf(root.style) + 1) % root.styles.length])
    }

    function setPillStyle(value) {
        const v = String(value).toLowerCase()
        if (v !== "none" && v !== "dots" && v !== "wave")
            return
        root.pillStyle = v
        root.persist()
    }

    function setColorMode(value) {
        const n = Math.round(Number(value))
        if (!isFinite(n))
            return
        root.colorMode = Math.max(0, Math.min(root.colorModeCount - 1, n))
        root.persist()
    }

    function setVertical(value) {
        root.vertical = value === true
        root.persist()
    }

    function toggleVertical() {
        root.setVertical(!root.vertical)
    }

    function setSize(value) {
        const n = Math.round(Number(value))
        if (!isFinite(n))
            return
        root.sizeIndex = Math.max(0, Math.min(root.sizeCount - 1, n))
        root.persist()
    }

    function cycleSize() {
        root.setSize((root.sizeIndex + 1) % root.sizeCount)
    }

    function setSensitivity(value) {
        const v = Number(value)
        if (!isFinite(v))
            return
        root.sensitivity = Math.max(0.5, Math.min(2.5, v))
        root.persist()
    }

    function setStayWhenPaused(value) {
        root.stayWhenPaused = value === true
        root.persist()
    }

    function setAlwaysListen(value) {
        root.alwaysListen = value === true
        root.persist()
    }

    function setUseAubio(value) {
        root.useAubio = value === true
        root.persist()
    }

    function setPerf(value) {
        const n = Math.round(Number(value))
        if (!isFinite(n))
            return
        root.perf = Math.max(0, Math.min(root.perfCount - 1, n))
        root.persist()
    }

    function setAnalyzer(value) {
        root.analyzer = value === true
        root.persist()
    }

    // ===== persistence =====
    readonly property string script: Directories.script("state/visualizer-state.sh")

    function snapshot() {
        return JSON.stringify({
            x: root.posX,
            y: root.posY,
            scale: root.posScale,
            screen: root.screenName,
            shown: root.shown,
            style: root.style,
            bandY: root.bandY,
            bandX: root.bandX,
            vertical: root.vertical,
            pillStyle: root.pillStyle,
            colors: root.colorMode,
            size: root.sizeIndex,
            sensitivity: root.sensitivity,
            stayWhenPaused: root.stayWhenPaused,
            alwaysListen: root.alwaysListen,
            analyzer: root.analyzer,
            useAubio: root.useAubio,
            perf: root.perf
        })
    }

    function restore(text) {
        try {
            const s = JSON.parse(text)
            if (typeof s.x === "number")
                root.posX = s.x
            if (typeof s.y === "number")
                root.posY = s.y
            if (typeof s.scale === "number" && s.scale > 0)
                root.posScale = s.scale
            if (typeof s.screen === "string")
                root.screenName = s.screen
            root.shown = s.shown !== false
            if (s.style === "confetti")
                root.style = "ribbons"
            else if (typeof s.style === "string" && root.styles.indexOf(s.style) >= 0)
                root.style = s.style
            if (typeof s.bandY === "number")
                root.bandY = s.bandY
            if (typeof s.bandX === "number")
                root.bandX = s.bandX
            root.vertical = s.vertical === true
            if (s.pillStyle === "none" || s.pillStyle === "dots" || s.pillStyle === "wave")
                root.pillStyle = s.pillStyle
            if (typeof s.colors === "number")
                root.colorMode = Math.max(0, Math.min(root.colorModeCount - 1, Math.round(s.colors)))
            if (typeof s.size === "number")
                root.sizeIndex = Math.max(0, Math.min(root.sizeCount - 1, Math.round(s.size)))
            if (typeof s.sensitivity === "number")
                root.sensitivity = Math.max(0.5, Math.min(2.5, s.sensitivity))
            root.stayWhenPaused = s.stayWhenPaused !== false
            root.alwaysListen = s.alwaysListen === true
            root.analyzer = s.analyzer !== false
            root.useAubio = s.useAubio !== false
            if (typeof s.perf === "number")
                root.perf = Math.max(0, Math.min(root.perfCount - 1, Math.round(s.perf)))
        } catch (e) {
            // No file yet (first run) or an unreadable one: keep the defaults.
        }
        console.log("VisualizerService: restored shown=" + root.shown + " colors=" + root.colorMode
            + " size=" + root.sizeIndex)
        root.loaded = true
    }

    // Runs once, at startup.
    Process {
        running: true
        command: ["sh", root.script, "load"]
        stdout: StdioCollector {
            onStreamFinished: root.restore(text)
        }
    }

    function persist() {
        if (root.loaded)
            saveTimer.restart()
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: saver.save(root.snapshot())
    }

    // Fire-and-forget save that queues at most one pending snapshot behind an
    // in-flight save, so the last state is what ends up on disk.
    Process {
        id: saver

        property var pending: null

        function save(json) {
            if (saver.running) {
                saver.pending = json
                return
            }
            saver.pending = null
            saver.exec(["sh", root.script, "save", json])
        }

        onExited: {
            if (saver.pending !== null) {
                const json = saver.pending
                saver.pending = null
                saver.exec(["sh", root.script, "save", json])
            }
        }
    }
}
