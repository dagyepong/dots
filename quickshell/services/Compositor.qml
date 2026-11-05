pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Everything that depends on the compositor lives here: the rest of the shell asks Compositor
// and works the same on Hyprland and niri. The compositor is recognized from the
// environment variables (NIRI_SOCKET / HYPRLAND_INSTANCE_SIGNATURE).
Singleton {
    id: root

    readonly property string kind: Quickshell.env("NIRI_SOCKET") ? "niri"
        : (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? "hyprland" : "other")
    readonly property bool isNiri: kind === "niri"
    readonly property bool isHyprland: kind === "hyprland"

    // ---- Common state ----
    // Focused monitor ("" if unknown)
    readonly property string focusedMonitor: {
        if (isNiri) return niriFocused ? niriFocused.output : ""
        if (isHyprland) return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        return ""
    }

    // Number of the active workspace on the focused monitor (on niri: position on the monitor)
    property int focusedWorkspaceId: 1

    // Keyboard layout switch (niri only: for Hyprland KbLayout handles it with its events)
    signal kbChanged()

    // ---- niri: state read with "niri msg --json" ----
    property var niriWorkspaces: []
    readonly property var niriFocused: {
        for (let i = 0; i < niriWorkspaces.length; i++)
            if (niriWorkspaces[i].is_focused) return niriWorkspaces[i]
        return null
    }

    // ---- Functions ----

    // Numbers of the workspaces that exist on a monitor
    function workspaceIdsFor(screenName) {
        const out = []
        if (isNiri) {
            for (let i = 0; i < niriWorkspaces.length; i++) {
                const w = niriWorkspaces[i]
                if (screenName !== "" && w.output !== screenName) continue
                out.push(w.idx)
            }
        } else if (isHyprland) {
            const v = Hyprland.workspaces.values
            for (let i = 0; i < v.length; i++) {
                const w = v[i]
                if (w.id <= 0) continue                       // scratchpad and similar
                if (w.monitor && screenName !== "" && w.monitor.name !== screenName) continue
                out.push(w.id)
            }
        }
        out.sort((a, b) => a - b)
        return out
    }

    // Workspace dots for the classic bar: [{id, occupied}]
    function dotsFor(screenName) {
        const out = []
        if (isNiri) {
            for (let i = 0; i < niriWorkspaces.length; i++) {
                const w = niriWorkspaces[i]
                if (screenName !== "" && w.output !== screenName) continue
                out.push({ id: w.idx, occupied: !(w.active_window_id === null || w.active_window_id === undefined) })
            }
        } else if (isHyprland) {
            const v = Hyprland.workspaces.values
            const occ = {}
            let max = 5
            for (let i = 0; i < v.length; i++) {
                const w = v[i]
                if (w.id <= 0) continue
                if (w.id > max) max = w.id
                if (w.toplevels.values.length > 0) occ[w.id] = true
            }
            for (let n = 1; n <= max; n++) out.push({ id: n, occupied: !!occ[n] })
        }
        out.sort((a, b) => a.id - b.id)
        return out
    }

    // Active workspace on a monitor (0 if unknown)
    function activeIdFor(screenName) {
        if (isNiri) {
            for (let i = 0; i < niriWorkspaces.length; i++) {
                const w = niriWorkspaces[i]
                if (w.output === screenName && w.is_active) return w.idx
            }
        } else if (isHyprland) {
            const m = Hyprland.monitors.values
            for (let i = 0; i < m.length; i++)
                if (m[i].name === screenName && m[i].activeWorkspace) return m[i].activeWorkspace.id
        }
        return 0
    }

    // True if the monitor's active workspace has no windows (you can type to open the launcher)
    function emptyDesktop(screenName) {
        if (isNiri) {
            const w = niriFocused
            return !!w && w.output === screenName
                   && (w.active_window_id === null || w.active_window_id === undefined)
        }
        if (isHyprland) {
            const mon = Hyprland.focusedMonitor
            const ws = Hyprland.focusedWorkspace
            return !!mon && !!ws && mon.name === screenName && ws.toplevels.values.length === 0
        }
        return false
    }

    function focusWorkspace(n) {
        if (isNiri)
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(n)])
        else if (isHyprland)
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + n + " })"])
    }

    // dir < 0: previous workspace, dir > 0: next
    function focusWorkspaceRelative(dir) {
        if (isNiri)
            Quickshell.execDetached(["niri", "msg", "action", dir < 0 ? "focus-workspace-up" : "focus-workspace-down"])
        else if (isHyprland)
            Quickshell.execDetached(["hyprctl", "dispatch",
                "hl.dsp.focus({ workspace = \"" + (dir < 0 ? "e-1" : "e+1") + "\" })"])
    }

    function logout() {
        if (isNiri)
            Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"])
        else if (isHyprland)
            Quickshell.execDetached(["sh", "-c",
                "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"])
        else
            Quickshell.execDetached(["sh", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\""])
    }

    // ---- Effects (Game Mode, Eco Mode) ----
    // Hyprland: Lua code via "hyprctl eval", undone with "hyprctl reload".
    // niri: there is no runtime command; I write a file included by config.kdl
    //       (~/.config/niri/quickshell-tweaks.kdl) and niri reloads the configuration by itself.
    readonly property string niriTweaksPath:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/niri/quickshell-tweaks.kdl"

    function tweak(lua, kdl) {
        if (isHyprland) {
            Quickshell.execDetached(["hyprctl", "eval", lua])
        } else if (isNiri) {
            Quickshell.execDetached(["sh", "-c",
                "[ -e \"$2\" ] && printf '%s\\n' \"$1\" > \"$2\"", "sh", kdl, niriTweaksPath])
        }
    }

    function tweakReset() {
        if (isHyprland) {
            Quickshell.execDetached(["hyprctl", "reload"])
        } else if (isNiri) {
            Quickshell.execDetached(["sh", "-c",
                "[ -e \"$2\" ] && printf '%s\\n' \"$1\" > \"$2\"", "sh",
                "// managed by Quickshell (Game Mode / Eco Mode)", niriTweaksPath])
        }
    }

    // ---- Hyprland: active workspace ----
    Connections {
        target: root.isHyprland ? Hyprland : null

        function onFocusedWorkspaceChanged() {
            const w = Hyprland.focusedWorkspace
            if (w && w.id > 0) root.focusedWorkspaceId = w.id
        }
    }

    // ---- niri: workspaces and events ----
    function onNiriWorkspaces(text) {
        try {
            const list = JSON.parse(text)
            if (!Array.isArray(list)) return
            root.niriWorkspaces = list
            for (let i = 0; i < list.length; i++)
                if (list[i].is_focused) { root.focusedWorkspaceId = list[i].idx; break }
        } catch (e) {
            console.log("Compositor: invalid workspaces:", e)
        }
    }

    property bool niriAgain: false

    function refreshNiri() {
        if (!isNiri) return
        if (wsProc.running) niriAgain = true
        else wsProc.running = true
    }

    Process {
        id: wsProc
        command: ["niri", "msg", "--json", "workspaces"]

        stdout: StdioCollector {
            onStreamFinished: root.onNiriWorkspaces(text)
        }

        onExited: {
            if (root.niriAgain) {
                root.niriAgain = false
                running = true
            }
        }
    }

    // niri events, one JSON line each: {"NomeEvento":{...}}
    readonly property var niriWsEvents: ({
        WorkspacesChanged: true,
        WorkspaceActivated: true,
        WorkspaceActiveWindowChanged: true,
        WindowClosed: true
    })

    function onNiriEvent(line) {
        const m = /^\{"(\w+)"/.exec(line)
        if (!m) return
        if (niriWsEvents[m[1]]) refreshTimer.restart()
        else if (m[1].indexOf("KeyboardLayout") === 0) kbChanged()
    }

    Process {
        id: eventProc
        command: ["niri", "msg", "--json", "event-stream"]
        running: root.isNiri

        stdout: SplitParser {
            onRead: line => root.onNiriEvent(line)
        }

        onExited: if (root.isNiri) restartTimer.restart()
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: eventProc.running = true
    }

    Timer {
        id: refreshTimer
        interval: 50
        onTriggered: root.refreshNiri()
    }

    // Safety net
    Timer {
        interval: 5000
        running: root.isNiri
        repeat: true
        onTriggered: root.refreshNiri()
    }

    Component.onCompleted: {
        if (isNiri) {
            refreshNiri()
        } else if (isHyprland) {
            const w = Hyprland.focusedWorkspace
            if (w && w.id > 0) focusedWorkspaceId = w.id
        }
    }
}
