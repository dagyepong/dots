pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Who is listening to the microphone and who is looking at the screen.
// Read straight from PipeWire (no polling, no subprocess): every node that is
// an application's *stream* is looked at, and
//
//   mic      a stream whose media.class is Stream/Input/Audio, i.e. an app
//            that records. It only counts while the default microphone is not
//            muted (a muted mic can't hear anyone), and level meters such as
//            pavucontrol's (stream.monitor / node.passive) are left out.
//   screen   screen sharing goes through the desktop portal: the portal
//            publishes a video source (its name has xdph / xdpw / portal /
//            screencast in it) and the app that watches it holds a
//            Stream/Input/Video. The app's name is read from that stream.
//
// What it exposes:
//   micApps / screenApps    ["Firefox", "OBS Studio"] (names, no repeats)
//   micLive / screenLive    booleans
//   active                  micLive || screenLive
//   summary                 "Firefox", "Firefox +1", "" ...
//
// This reads PipeWire's property names, which differ a little between apps and
// portals, so if an indicator never lights (or lights for the wrong thing) run
//     qs -c sekaipop ipc call privacy dump
// and look at the lines it prints in the shell's log: media.class, node.name,
// media.name and the application name of every stream. The matching is in
// `isScreenProducer` / `isMicStream` below.
Singleton {
    id: root

    // Every node, bound so that its properties can be read.
    PwObjectTracker {
        objects: Pipewire.nodes.values
    }
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSource].filter(n => n)
    }

    // Bumped whenever PipeWire adds or removes a node, so the bindings below
    // look again (the node list itself is the dependency, this is for safety
    // with properties that arrive a moment after the node).
    readonly property var nodes: Pipewire.nodes.values

    function prop(node, key) {
        try {
            const p = node.properties
            if (p && p[key] !== undefined && p[key] !== null)
                return String(p[key])
        } catch (e) {}
        return ""
    }

    function mediaClass(node) {
        return root.prop(node, "media.class")
    }

    function appName(node) {
        const n = root.prop(node, "application.name")
            || root.prop(node, "application.process.binary")
            || root.prop(node, "node.description")
            || root.prop(node, "node.nick")
            || ""
        // "chromium" -> "Chromium"; keep names that already have capitals.
        return n.length > 0 && n === n.toLowerCase() ? n.charAt(0).toUpperCase() + n.slice(1) : n
    }

    // Level meters and the like (pavucontrol, helvum...) listen to the mic
    // without being "an app using the microphone".
    function isMeter(node) {
        return root.prop(node, "stream.monitor") === "true"
            || root.prop(node, "node.passive") === "true"
            || /pavucontrol|peak detect|level|volume control|wireplumber|plasma-pa/i.test(
                root.appName(node) + " " + root.prop(node, "media.name"))
    }

    function isMicStream(node) {
        return root.mediaClass(node) === "Stream/Input/Audio" && !root.isMeter(node)
    }

    function isScreenProducer(node) {
        const mc = root.mediaClass(node)
        if (mc.indexOf("Video") < 0)
            return false
        const text = root.prop(node, "node.name") + " " + root.prop(node, "media.name") + " "
            + root.appName(node)
        return /xdph|xdpw|xdg-desktop-portal|screencast|screen-cast|screen cast|wlroots|monitor/i.test(text)
    }

    function isVideoConsumer(node) {
        return root.mediaClass(node) === "Stream/Input/Video"
    }

    function unique(list) {
        const out = []
        for (const x of list)
            if (x && out.indexOf(x) < 0)
                out.push(x)
        return out
    }

    readonly property bool micMuted: Pipewire.defaultAudioSource?.audio?.muted ?? false

    readonly property var micApps: {
        void root.nodes
        const names = []
        for (const n of root.nodes)
            if (root.isMicStream(n))
                names.push(root.appName(n) || "An app")
        return root.micMuted ? [] : root.unique(names)
    }

    // Screen sharing is "on" while the portal's source exists and something
    // watches a video stream. The watcher is the one named; with no readable
    // name it is just "An app".
    readonly property var screenApps: {
        void root.nodes
        let portal = false
        const names = []
        for (const n of root.nodes) {
            if (root.isScreenProducer(n))
                portal = true
            else if (root.isVideoConsumer(n))
                names.push(root.appName(n) || "An app")
        }
        return portal ? (names.length > 0 ? root.unique(names) : [ "An app" ]) : []
    }

    readonly property bool micLive: micApps.length > 0
    readonly property bool screenLive: screenApps.length > 0
    readonly property bool active: micLive || screenLive

    function nameOf(list) {
        if (list.length === 0)
            return ""
        return list.length === 1 ? list[0] : list[0] + " +" + (list.length - 1)
    }

    readonly property string screenName: root.nameOf(screenApps)
    // One line for the pill: the screen first (it is the rarer one).
    readonly property string summary: {
        const all = root.unique(screenApps.concat(micApps))
        return root.nameOf(all)
    }

    IpcHandler {
        target: "privacy"

        function dump(): string {
            const lines = []
            for (const n of Pipewire.nodes.values) {
                const mc = root.mediaClass(n)
                if (mc.indexOf("Stream/") !== 0 && mc.indexOf("Video") < 0)
                    continue
                const l = "[privacy] " + mc + " | node.name=" + root.prop(n, "node.name")
                    + " | media.name=" + root.prop(n, "media.name")
                    + " | app=" + root.appName(n)
                    + (root.isMicStream(n) ? " | MIC" : "")
                    + (root.isScreenProducer(n) ? " | SCREEN-SOURCE" : "")
                    + (root.isVideoConsumer(n) ? " | VIDEO-CONSUMER" : "")
                lines.push(l)
                console.log(l)
            }
            lines.push("mic: " + JSON.stringify(root.micApps) + "  screen: " + JSON.stringify(root.screenApps))
            return lines.join("\n")
        }

        function get(): string {
            return "mic=" + JSON.stringify(root.micApps) + " screen=" + JSON.stringify(root.screenApps)
        }
    }
}
