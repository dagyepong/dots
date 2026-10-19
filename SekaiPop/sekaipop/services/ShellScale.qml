pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.common

// One size knob per monitor for the whole shell.
//
// The numbers live in ~/.config/sekaipop/scale.json (or under $XDG_CONFIG_HOME)
// and are re-read the moment you save the file, so you can edit it and watch
// the bar, dock, panels and popups resize live. A scale.json that an older
// version kept next to shell.qml is copied there the first time (see
// scripts/state/scale-state.sh). Format:
//
//   {
//     "default": 1.0,
//     "monitors": {
//       "DP-1": 1.25,            // by output name   (hyprctl monitors)
//       "DELL U2723QE": 1.0,     // by monitor model
//       "2560x1440": 1.15        // by resolution, for every screen that size
//     }
//   }
//
// A screen looks itself up in that order (name, then model, then
// resolution) and falls back to "default". 1.0 = the design size,
// 1.25 = 25% bigger, 0.8 = 20% smaller. The resolution key is the size
// the compositor reports to the shell, i.e. AFTER Hyprland's own monitor
// scale (a 4K monitor at scale 1.5 is "2560x1440").
//
// Everything asks ShellScale.forScreen(screen) from inside a binding, so a
// change here re-lays-out live with nothing to wire up.
//
// From a keybind (writes scale.json for you); <monitor> is an output name,
// "focused", or "default":
//   qs -c sekaipop ipc call scale set focused 1.2
//   qs -c sekaipop ipc call scale bump focused 0.1
//   qs -c sekaipop ipc call scale bump focused -0.1
//   qs -c sekaipop ipc call scale reset focused        (or: reset all)
//   qs -c sekaipop ipc call scale get focused
Singleton {
    id: root

    readonly property real minScale: 0.5
    readonly property real maxScale: 3.0

    property real defaultScale: 1.0
    // { "DP-1": 1.25, "2560x1440": 1.1, ... }
    property var monitors: ({})

    function clampScale(v) {
        const n = Number(v)
        if (!isFinite(n) || n <= 0)
            return 1
        return Math.max(root.minScale, Math.min(root.maxScale, n))
    }

    // The scale for one screen (a ShellScreen; null means "default").
    // Reads its inputs inside the function, so calling it from a binding
    // keeps that binding live.
    function forScreen(screen) {
        let s = root.defaultScale
        if (screen) {
            const m = root.monitors
            const keys = [screen.name, screen.model, screen.width + "x" + screen.height]
            for (const k of keys) {
                if (k && m[k] !== undefined) {
                    s = m[k]
                    break
                }
            }
        }
        return root.clampScale(s)
    }

    // ===== reading =====
    function parse(text) {
        try {
            const j = JSON.parse(text)
            const next = {}
            const src = j.monitors || {}
            for (const k in src) {
                const n = Number(src[k])
                if (isFinite(n) && n > 0)
                    next[k] = n
            }
            root.monitors = next
            const d = Number(j["default"])
            root.defaultScale = (isFinite(d) && d > 0) ? d : 1.0
        } catch (e) {
            console.warn("ShellScale: couldn't parse scale.json (" + e + ") — keeping the last good values")
        }
    }

    // When we last wrote scale.json ourselves. The file watcher reports
    // our own writes back a moment later; with several clicks in quick
    // succession an early echo can carry an older value and would flick
    // the shell back to it, so loads that close behind a save of ours are
    // ignored (the in-memory values are already the newest).
    property double lastSaveMs: 0

    // ~/.config/sekaipop/scale.json. The path is only given to the FileView once
    // scale-state.sh has made the folder and moved the old file in, so there is
    // always a file to watch.
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/sekaipop"
    property string filePath: ""

    Process {
        running: true
        command: ["sh", Directories.script("state/scale-state.sh"), "init", Quickshell.shellDir + "/scale.json"]
        onExited: root.filePath = root.configDir + "/scale.json"
    }

    FileView {
        id: file
        path: root.filePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            if (Date.now() - root.lastSaveMs < 1000)
                return
            root.parse(text())
        }
        onLoadFailed: error => {
            if (root.filePath !== "")
                console.warn("ShellScale: no readable scale.json, using 1.0 everywhere (" + error + ")")
        }
    }

    // ===== writing =====
    function screenByName(name) {
        for (const s of Quickshell.screens) {
            if (s.name === name)
                return s
        }
        return null
    }

    // "focused" -> the focused output's name; anything else passes through.
    function resolveName(monitor) {
        if (monitor === "focused")
            return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        return monitor
    }

    function effectiveFor(name) {
        if (name === "default")
            return root.clampScale(root.defaultScale)
        return root.forScreen(root.screenByName(name))
    }

    function save() {
        const out = { "default": root.defaultScale, "monitors": root.monitors }
        root.lastSaveMs = Date.now()
        file.setText(JSON.stringify(out, null, 2) + "\n")
    }

    function setScale(monitor, value) {
        const name = root.resolveName(monitor)
        if (name === "")
            return
        const v = Math.round(root.clampScale(value) * 100) / 100
        if (name === "default") {
            root.defaultScale = v
        } else {
            const next = Object.assign({}, root.monitors)
            next[name] = v
            root.monitors = next
        }
        root.save()
    }

    function resetScale(monitor) {
        if (monitor === "all") {
            root.defaultScale = 1.0
            root.monitors = ({})
            root.save()
            return
        }
        const name = root.resolveName(monitor)
        if (name === "")
            return
        if (name === "default") {
            root.defaultScale = 1.0
        } else {
            const next = Object.assign({}, root.monitors)
            delete next[name]
            root.monitors = next
        }
        root.save()
    }

    IpcHandler {
        target: "scale"

        function set(monitor: string, value: real): void {
            root.setScale(monitor, value)
        }

        function bump(monitor: string, delta: real): void {
            const name = root.resolveName(monitor)
            if (name !== "")
                root.setScale(name, root.effectiveFor(name) + delta)
        }

        function reset(monitor: string): void {
            root.resetScale(monitor)
        }

        function get(monitor: string): string {
            const name = root.resolveName(monitor)
            return name + " " + root.effectiveFor(name).toFixed(2)
        }
    }
}
