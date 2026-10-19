pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The other Overview: the Hyprland plugin "ScrollOverview"
// (https://github.com/yayuuu/hyprland-scroll-overview), a niri-style overview
// the compositor draws itself (windows stay live, scrolled and zoomed out in
// place). It is not part of this shell: it is a plugin you install with
// hyprpm, and this service only *drives* it and tells the Settings Panel
// whether it is there.
//
// Which overview opens is the option `overview.style` (SettingsService):
//   board    this shell's film strip (Overview.qml), the default
//   scroll   the plugin
// Overview.qml reads it, so a key bound to `qs -c sekaipop ipc call overview
// toggle` opens whichever you picked, and so does the dock's Search key
// fallback. Nothing in hyprland.lua has to change.
//
// The shell loads the plugin for you: when `scroll` is picked and the plugin is
// not loaded (at start-up, right after picking it, or when the overview key is
// pressed), it runs `hyprpm reload -n` once, so nothing has to be added to
// hyprland.lua. This needs the plugin to be installed and enabled with hyprpm
// once (hyprpm add / update / enable scrolloverview; the Settings card shows
// the line). If it still is not loaded after that (not installed, or built for
// another Hyprland version), the film strip opens instead, so the key never
// does nothing.
//
// Plugin options (layout, scale, gap) set from the Settings Panel are kept in
// this shell's own settings (overview.layout / .scale / .gap; "not set" leaves
// the plugin's own config alone) and applied LIVE with `hyprctl eval` once the
// plugin is loaded, and again after every Hyprland config reload (which resets
// them). They are deliberately not written to the Hyprland override file: that
// file runs before hyprpm has loaded the plugin, and Hyprland reports
// "unknown config key plugin.scrolloverview.*" for a key it does not know yet.
//
// From a script:
//   qs -c sekaipop ipc call scrolloverview toggle    (also show / hide / status)
// (drives the plugin directly, whatever `overview.style` says)
Singleton {
    id: root

    // The plugin is listed by `hyprctl plugin list`. Checked at start-up, when
    // the option changes, when the Settings page looks, and (only while this is
    // false) right before an open, so a plugin loaded late is still picked up.
    property bool available: false

    // True once one check has finished.
    property bool checked: false

    // Loading it: `hyprpm reload -n` is tried once per start-up / pick / Check
    // again, and what it said (if anything) is kept for the Settings card.
    property bool loadTried: false
    property bool loading: loader.running
    property string loadLog: ""

    readonly property bool wanted: SettingsService.get("overview.style") === "scroll"

    // Same Lua / hyprlang fork Overview.qml and Bar.qml use for dispatches.
    readonly property bool usingLua: Hyprland.usingLua !== false

    // `toggle`, `on` or `off`.
    function dispatch(action) {
        if (action !== "toggle" && action !== "on" && action !== "off")
            return
        Hyprland.dispatch(root.usingLua
            ? "hl.plugin.scrolloverview.overview(\"" + action + "\")"
            : "scrolloverview:overview " + action)
    }

    // Do `action` on the plugin. When it is not known to be loaded, look first;
    // if it is not there, call `fallback()` (may be null) instead.
    property string pendingAction: ""
    property var pendingFallback: null

    function run(action, fallback) {
        if (root.available) {
            root.dispatch(action)
            return
        }
        root.pendingAction = action
        root.pendingFallback = fallback || null
        root.refresh()
    }

    function refresh() {
        if (!checker.running && !loader.running)
            checker.running = true
    }

    // "Check again": look, and (if it is still not there) try hyprpm again.
    function recheck() {
        root.loadTried = false
        root.failNotified = false
        root.loadLog = ""
        root.refresh()
    }

    // When hyprpm could not load it, say so with a notification (once per try),
    // not only on the Settings card: `openedBoard` says the overview key had
    // been pressed and the film strip opened instead.
    property bool failNotified: false

    function notifyFailed(openedBoard) {
        if (root.failNotified)
            return
        root.failNotified = true
        let body = "The ScrollOverview plugin is not loaded"
            + (openedBoard ? ", so the film strip opened instead." : ".")
        if (root.loadLog !== "")
            body += "\nhyprpm said: " + root.loadLog.split("\n").slice(0, 3).join(" ").slice(0, 220)
        else
            body += "\nIs it installed? Settings > Hyprland > Overview shows the install commands."
        Quickshell.execDetached([ "notify-send", "-a", "Shell", "-u", "normal", "-i", "material:view_carousel",
            "Scroll overview did not start", body ])
    }

    function load() {
        if (loader.running)
            return
        root.loadTried = true
        root.loadLog = ""
        loader.exec([ "hyprpm", "reload", "-n" ])
    }

    // ===== the plugin's options =====
    // `layout`, `scale` or `gap` as the panel sets them, else the plugin's live
    // value (read by HyprlandSettings), else its default.
    function optionValue(name) {
        if (name === "layout") {
            const v = SettingsService.get("overview.layout")
            return v !== "" ? v : HyprlandSettings.str("plugin.scrolloverview.layout", "vertical")
        }
        if (name === "scale") {
            const v = SettingsService.get("overview.scale")
            return v > 0 ? v : HyprlandSettings.num("plugin.scrolloverview.scale", 0.5)
        }
        const v = SettingsService.get("overview.gap")
        return v >= 0 ? v : HyprlandSettings.num("plugin.scrolloverview.workspace_gap", 0)
    }

    function setOption(name, value) {
        if (name === "layout") {
            if (value !== "vertical" && value !== "horizontal")
                return
            SettingsService.set("overview.layout", value)
        } else if (name === "scale") {
            SettingsService.set("overview.scale", Math.max(0.1, Math.min(0.9, Math.round(Number(value) * 100) / 100)))
        } else if (name === "gap") {
            SettingsService.set("overview.gap", Math.max(0, Math.min(300, Math.round(Number(value)))))
        } else {
            return
        }
        applyDelay.restart()
    }

    // Puts the panel's options on the loaded plugin. Nothing is sent for an
    // option that was never set from the panel.
    function applyConfig() {
        if (!root.available)
            return
        if (applier.running) {
            applyDelay.restart()
            return
        }
        const layout = SettingsService.get("overview.layout")
        const scale = SettingsService.get("overview.scale")
        const gap = SettingsService.get("overview.gap")
        const o = []
        if (layout === "vertical" || layout === "horizontal")
            o.push(["layout", layout])
        if (scale > 0)
            o.push(["scale", Number(scale).toFixed(2)])
        if (gap >= 0)
            o.push(["workspace_gap", String(Math.round(gap))])
        if (o.length === 0)
            return
        if (root.usingLua) {
            applier.exec([ "hyprctl", "eval", "hl.config({ plugin = { scrolloverview = { "
                + o.map(kv => kv[0] + " = " + (kv[0] === "layout" ? "\"" + kv[1] + "\"" : kv[1])).join(", ")
                + " } } })" ])
        } else {
            applier.exec([ "sh", "-c", o.map(kv => "hyprctl keyword plugin:scrolloverview:" + kv[0] + " " + kv[1]).join("; ") ])
        }
    }

    Timer {
        id: applyDelay
        interval: 150
        onTriggered: root.applyConfig()
    }

    Process {
        id: applier
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                if (t.length > 0 && !t.startsWith("ok"))
                    console.log("[ScrollOverviewService]", t)
            }
        }
    }

    // A config reload puts the plugin's options back to the config file's.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                applyDelay.restart()
        }
    }

    Component.onCompleted: root.refresh()

    onWantedChanged: {
        if (root.wanted) {
            root.loadTried = false
            root.failNotified = false
            root.refresh()
        }
    }

    Process {
        id: loader
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                if (t.length > 0)
                    root.loadLog = t
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                if (t.length > 0)
                    root.loadLog = t
            }
        }
        // hyprpm may have loaded it: look again (this also answers a waiting key).
        onExited: root.refresh()
    }

    Process {
        id: checker
        command: [ "hyprctl", "plugin", "list" ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = /scroll[\s_-]*overview/i.test(text)
                root.checked = true
                if (root.available)
                    root.applyConfig()

                // Wanted but not there: let hyprpm load it, once, then look again
                // (a waiting key press stays waiting until then).
                if (!root.available && root.wanted && !root.loadTried) {
                    root.load()
                    return
                }

                // hyprpm had its go and it is still not there: say so.
                if (!root.available && root.wanted && root.loadTried)
                    root.notifyFailed(root.pendingAction !== "" && root.pendingFallback !== null)

                const action = root.pendingAction
                const fallback = root.pendingFallback
                root.pendingAction = ""
                root.pendingFallback = null
                if (action === "")
                    return
                if (root.available)
                    root.dispatch(action)
                else if (fallback)
                    fallback()
            }
        }
    }

    IpcHandler {
        target: "scrolloverview"

        function toggle(): void {
            root.dispatch("toggle")
        }

        function show(): void {
            root.dispatch("on")
        }

        function hide(): void {
            root.dispatch("off")
        }

        function status(): string {
            return root.available ? "loaded" : "not loaded"
        }
    }
}
