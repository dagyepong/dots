pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// The Hyprland page's options: reads them from Hyprland, writes them to the
// override file and applies them live (scripts/hyprland/hyprland-settings.sh does the
// work; see its header for how). One value per dotted Lua option path, e.g.
//
//     HyprlandSettings.num("general.gaps_in")
//     HyprlandSettings.set("decoration.blur.enabled", "bool", true)
//
// `set` updates the value at once (so a slider follows the pointer) and
// writes in the background, one write at a time, the newest value per option
// winning: dragging a slider doesn't spawn a process per pixel.
//
// Values are read back from Hyprland whenever the panel opens, so a reload
// that dropped an override, or a change made by hand, shows up as it is.
Singleton {
    id: root

    // Every option the panel shows. `read` only asks for these.
    readonly property var paths: [
        "general.gaps_in", "general.gaps_out", "general.border_size", "general.layout",
        "general.resize_on_border", "general.allow_tearing", "animation.workspaces",
        "decoration.rounding", "decoration.active_opacity", "decoration.inactive_opacity",
        "decoration.blur.enabled", "decoration.blur.size", "decoration.blur.passes",
        "decoration.shadow.enabled", "decoration.dim_inactive",
        "animations.enabled",
        "dwindle.preserve_split", "dwindle.force_split", "master.new_status",
        "scrolling.column_width", "scrolling.focus_fit_method", "scrolling.follow_focus",
        "scrolling.fullscreen_on_one_column", "scrolling.direction",
        "plugin.scrolloverview.layout", "plugin.scrolloverview.scale", "plugin.scrolloverview.workspace_gap",
        "binds.workspace_back_and_forth", "binds.allow_workspace_cycles", "misc.close_special_on_empty",
        "misc.focus_on_activate", "misc.enable_swallow", "misc.animate_manual_resizes",
        "misc.vrr", "misc.disable_hyprland_logo", "misc.mouse_move_enables_dpms", "misc.key_press_enables_dpms",
        "input.follow_mouse", "input.sensitivity", "input.repeat_rate", "input.repeat_delay",
        "input.kb_layout", "input.kb_variant", "input.kb_options",
        "input.numlock_by_default", "input.touchpad.natural_scroll", "input.touchpad.tap-to-click",
        "input.touchpad.disable_while_typing"
    ]

    // Sent when a write has finished and Hyprland has been told (the bar uses it to
    // re-read the keyboard layouts once the list has changed).
    signal applied(string path)

    // path -> the value as text, as Hyprland reported it (or as last set).
    property var values: ({})
    property bool loaded: false
    // True when hyprland.lua exists, and when it loads our override file.
    property bool isLua: false
    property bool linked: true

    readonly property string script: Directories.script("hyprland/hyprland-settings.sh")

    // Read once at start-up too (it used to wait for the Settings or Quick
    // Panel to open): the transparent bar needs `general.gaps_out` straight
    // away to size the space it reserves (Bar.qml).
    Component.onCompleted: root.refresh()

    function raw(path) {
        return root.values[path]
    }

    function num(path, fallback) {
        const n = Number(root.values[path])
        return isFinite(n) && root.values[path] !== undefined ? n : (fallback === undefined ? 0 : fallback)
    }

    function bool(path) {
        const v = root.values[path]
        return v === "1" || v === "true"
    }

    function str(path, fallback) {
        const v = root.values[path]
        return v === undefined ? (fallback || "") : v
    }

    // ===== reading =====
    function refresh() {
        if (!reader.running) {
            reader.command = ["sh", root.script, "read"].concat(root.paths)
            reader.running = true
        }
        if (!checker.running)
            checker.running = true
    }

    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                const next = Object.assign({}, root.values)
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i > 0)
                        next[line.slice(0, i)] = line.slice(i + 1).trim()
                }
                // Anything still waiting to be written is newer than this read.
                for (const job of writer.queue)
                    next[job.path] = job.value
                root.values = next
                root.loaded = true
            }
        }
    }

    Process {
        id: checker
        command: ["sh", root.script, "check"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.isLua = text.indexOf("lua=yes") >= 0
                root.linked = text.indexOf("linked=no") < 0
            }
        }
    }

    // ===== writing =====
    function set(path, type, value) {
        const text = type === "bool" ? (value ? "true" : "false") : String(value)
        const next = Object.assign({}, root.values)
        next[path] = type === "bool" ? (value ? "1" : "0") : text
        root.values = next
        writer.enqueue(path, type, text, next[path])
    }

    function reset(path) {
        writer.enqueueReset(path)
    }

    function resetAll() {
        writer.queue = []
        writer.exec(["sh", root.script, "reset-all"])
        root.values = ({})
        resetRead.restart()
    }

    Timer {
        id: resetRead
        interval: 900
        onTriggered: root.refresh()
    }

    Process {
        id: writer

        // [{ path, type, text, value } | { path, reset: true }]
        property var queue: []
        property string lastPath: ""

        function enqueue(path, type, text, value) {
            const q = writer.queue.filter(j => j.path !== path)
            q.push({ path: path, type: type, text: text, value: value })
            writer.queue = q
            writer.next()
        }

        function enqueueReset(path) {
            const q = writer.queue.filter(j => j.path !== path)
            q.push({ path: path, reset: true })
            writer.queue = q
            writer.next()
        }

        function next() {
            if (writer.running || writer.queue.length === 0)
                return
            const q = writer.queue.slice()
            const job = q.shift()
            writer.queue = q
            writer.lastPath = job.path
            if (job.reset) {
                writer.exec(["sh", root.script, "reset", job.path])
                resetRead.restart()
            } else {
                writer.exec(["sh", root.script, "set", job.path, job.type, job.text])
            }
        }

        onExited: {
            root.applied(writer.lastPath)
            writer.next()
        }
    }
}
