pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common

// The audio tap for the end4-style visualizers: the bar's media pill (dots / wave,
// VisualizerService.pillStyle) and the desktop visualizer's end4 styles. Same as
// end4-pC's cava feed: cava with scripts/cava/cava-pc.conf (50 bands, 0..1000).
//
// ONE cava for both. The desktop widget used to start a second cava with the very same
// config next to this one whenever the pill and a desktop end4 style were on together
// (two processes, two 60 fps streams, same numbers). Now the widget asks for the tap with
// `demand(+1)` / `demand(-1)` (VisualizerWidget.qml, `tapDemand`) and reads `raw`; this
// service runs cava while the pill wants it OR any widget does.
//   points  the last frame scaled by the sensitivity (what the pill reads); only filled
//           while the pill itself wants the tap, so a widget-only tap repaints no bar
//   raw     the last frame as cava sent it (what the widget's engine reads, it applies the
//           sensitivity itself); a fresh array per line while a widget wants it, as the
//           widget's own cava gave it, and empty otherwise
Singleton {
    id: root

    property var points: []
    property var raw: []

    // How many desktop visualizers want the tap right now (each one counts itself once,
    // see `tapDemand` in VisualizerWidget.qml).
    property int widgetDemand: 0

    function demand(delta) {
        root.widgetDemand = Math.max(0, root.widgetDemand + delta)
    }

    readonly property bool anyPlaying: {
        const list = Mpris.players.values
        for (let i = 0; i < list.length; i++) {
            if (list[i].playbackState === MprisPlaybackState.Playing)
                return true
        }
        return false
    }

    // The pill's own reason to listen: its visualizer is on and something is playing.
    readonly property bool pillWanted: VisualizerService.loaded && VisualizerService.pillStyle !== "none" && root.anyPlaying

    onPillWantedChanged: {
        if (!root.pillWanted)
            root.points = []
    }

    onWidgetDemandChanged: {
        if (root.widgetDemand <= 0)
            root.raw = []
    }

    // (Not in Game Mode: the media pill is not on the bar then, so nothing reads it. Not while the
    // screen is locked either: nothing but the lockscreen is on screen then, see LockState.desktopAsleep;
    // cava is started again the moment the password is accepted.)
    readonly property bool wanted: (root.pillWanted || root.widgetDemand > 0)
        && !GameModeService.enabled && !LockState.desktopAsleep

    readonly property string conf: Directories.script("cava/cava-pc.conf")

    Process {
        id: cava
        running: root.wanted
        command: ["nice", "-n", "5", "cava", "-p", root.conf]

        stdout: SplitParser {
            onRead: data => {
                // One pass, one array per frame (cava sends up to 60 a second): the numbers as
                // cava sent them. Anything that is not a number (the empty piece after the
                // last ";") is dropped.
                const parts = data.split(";")
                const bands = []
                for (let i = 0; i < parts.length; i++) {
                    const v = parseFloat(parts[i])
                    if (!isNaN(v))
                        bands.push(v)
                }
                if (root.widgetDemand > 0)
                    root.raw = bands
                if (!root.pillWanted)
                    return
                // Visualizer sensitivity (0.5 .. 2.5) scales the bands; 1000 is cava's top.
                const s = VisualizerService.sensitivity
                const out = new Array(bands.length)
                for (let i = 0; i < bands.length; i++)
                    out[i] = Math.min(1000, bands[i] * s)
                // A frame equal to the last one changes nothing on screen, but assigning it
                // still tells every media pill (one per monitor) to repaint and re-blur its
                // wave and to commit a bar frame to the compositor. A player that is
                // "playing" silence sends such frames (all zeros) up to 60 times a second.
                const last = root.points
                let same = last.length === out.length
                for (let i = 0; same && i < out.length; i++) {
                    if (last[i] !== out[i])
                        same = false
                }
                if (!same)
                    root.points = out
            }
        }

        onRunningChanged: {
            if (!cava.running) {
                root.points = []
                root.raw = []
            }
        }
    }
}
