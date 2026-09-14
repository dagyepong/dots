// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W A L L P A P E R   S E R V I C E                                      │
// │   wallpaper listing and application                                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Lists the bundled wallpapers and applies them. Emits `applied` instead of
// calling ThemeService, so the dependency only runs one way.
QtObject {
    id: root

    signal applied(string path)

    readonly property string script: Quickshell.shellPath("scripts/theme_manager.py")

    property var wallpapers: []
    property string currentWallpaper: ""
    property bool scanning: false

    readonly property Process scanProcess: Process {
        command: [root.script, "list-wallpapers"]
        running: true
        onExited: root.scanning = false
        stdout: StdioCollector {
            onStreamFinished: {
                const list = root.parseJson(text)
                if (Array.isArray(list))
                    root.wallpapers = list
            }
        }
    }

    readonly property Process currentProcess: Process {
        command: [root.script, "get-current"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    root.currentWallpaper = text.trim()
            }
        }
    }

    readonly property Process applyProcess: Process {
        onExited: exitCode => {
            if (exitCode === 0)
                root.applied(root.currentWallpaper)
            else
                console.warn("Could not apply wallpaper:", root.currentWallpaper)
        }
    }

    // ── RESTORE AT LOGIN ────────────────────────────────────────────────────
    //
    // awww's own cache stores the resolved path and breaks if the file moves,
    // so restore from the shell's record, which points at the copy in the
    // data directory. The script only paints outputs that show nothing, so a
    // shell restart does not repaint; it exits 3 while the daemon is still
    // starting (quickshell is launched first), hence the retry.
    readonly property Process restoreProcess: Process {
        command: [root.script, "restore"]
        running: true
        onExited: exitCode => {
            if (exitCode === 3 && restoreRetry.tries < 8) {
                restoreRetry.tries += 1
                restoreRetry.restart()
            }
        }
    }

    readonly property Timer restoreRetry: Timer {
        property int tries: 0
        interval: 1500
        onTriggered: root.restoreProcess.running = true
    }

    // ── HOTPLUG ─────────────────────────────────────────────────────────────
    //
    // awww does not paint outputs added after the wallpaper was set. The
    // restore above only touches empty outputs, so rerun it.
    readonly property Connections hotplug: Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name === "monitoradded" || event.name === "monitoraddedv2")
                root.arriving.restart()
        }
    }

    // One hotplug emits several events, and awww needs a moment to see the
    // new output.
    readonly property Timer arriving: Timer {
        interval: 700
        onTriggered: {
            root.restoreRetry.tries = 0
            root.restoreProcess.running = true
        }
    }

    function parseJson(text: string): var {
        if (!text || text.trim() === "")
            return null
        try {
            return JSON.parse(text)
        } catch (error) {
            console.warn("Cannot parse the wallpaper list:", error)
            return null
        }
    }

    function scan(): void {
        root.scanning = true
        root.scanProcess.running = true
    }

    // ── TRANSITIONS ─────────────────────────────────────────────────────────
    //
    // awww transition types under the shell's labels. `random` picks from
    // these rows rather than using awww's own, which can pick `none`.
    readonly property var transitions: [
        { id: "fade",   label: "Fade",   type: "fade" },
        { id: "wipe",   label: "Wipe",   type: "wipe" },
        { id: "wave",   label: "Wave",   type: "wave" },
        { id: "circle", label: "Circle", type: "center" },
        { id: "outer",  label: "Outer",  type: "outer" },
        { id: "none",   label: "None",   type: "none" },
        { id: "random", label: "Random", type: "" }
    ]

    function transitionType(id: string): string {
        if (id === "random") {
            const pool = root.transitions.filter(entry => entry.type !== "" && entry.type !== "none")
            return pool[Math.floor(Math.random() * pool.length)].type
        }
        const entry = root.transitions.find(entry => entry.id === id)
        return entry && entry.type !== "" ? entry.type : "wipe"
    }

    function apply(path: string): void {
        if (!path)
            return
        root.currentWallpaper = path
        root.applyProcess.command = [root.script, "set-wallpaper", path,
                                     root.transitionType(SettingsService.wallpaperTransition)]
        root.applyProcess.running = true
    }
}
