pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Game Mode: the one place that says whether it is on, and the one place that
// switches it. Everything else just reads `enabled`.
//
// What it does (the Hyprland half is scripts/hyprland/gamemode-state.sh, the
// shell half is wired where each thing lives):
//   Hyprland     animations / blur / shadows / gaps / rounding off, tearing on
//   Bar          shrinks to a fixed bar: date, clock and weather only, flat and
//                click-through, still updating (Bar.qml, Status_Bar.qml)
//   Dock         gone: the dock windows are not built (shell.qml `docks`)
//   Widgets      all five desktop widgets are unloaded, not just hidden
//                (shell.qml, the LazyLoaders); Edit Desktop will not open
//   Audio tap    the bar's cava feed stops (PcCavaService.qml)
// Switching it off puts all of it back. The widgets keep their own "shown"
// switches the whole time, so they come back exactly as they were.
//
// The state survives a shell restart: gamemode-state.sh leaves a marker file in
// $XDG_RUNTIME_DIR while Game Mode is on (it is cleared at logout / reboot), and
// this reads it once at start.
//
//   qs -c sekaipop ipc call gamemode toggle | enable | disable | status
//
// The Quick Panel's Game Mode tile and the two Settings switches call
// QuickSource.toggleGameMode(), which calls toggle() here.
Singleton {
    id: root

    // True while Game Mode is on.
    property bool enabled: false

    // False until the marker has been read (a few ms after start). The things that
    // are built or not built because of Game Mode wait for it, so a start with Game
    // Mode already on does not build the dock and the widgets for a moment first.
    property bool loaded: false

    // The Hyprland change is being applied; a second request waits for it.
    readonly property bool busy: action.running

    readonly property string script: Directories.script("hyprland/gamemode-state.sh")

    function toggle() {
        root.set(!root.enabled)
    }

    function set(want) {
        if (!root.loaded || action.running || want === root.enabled)
            return
        action.want = want
        action.running = true
        // Leaving Game Mode does not wait for Hyprland: the dock and the widgets
        // come back at once, and the config reload runs behind them.
        if (!want)
            root.enabled = false
    }

    function notifyFailed(text) {
        Quickshell.execDetached(["notify-send", "-a", "Shell", "-i", "material:error", "Game Mode", text])
    }

    // Applies the Hyprland half. ON only counts once Hyprland took it; OFF always
    // counts (a refused reload must never leave you without your dock), and the
    // marker is removed either way so the next start does not bring it back.
    Process {
        id: action
        property bool want: false
        command: ["sh", "-c",
            "sh \"$1\" \"$2\"; rc=$?; "
            + "[ \"$2\" = off ] && rm -f \"${XDG_RUNTIME_DIR:-/tmp}/sekaipop-gamemode\"; "
            + "exit $rc",
            "sh", root.script, action.want ? "on" : "off"]
        onExited: (exitCode, exitStatus) => {
            if (action.want) {
                if (exitCode === 0)
                    root.enabled = true
                else
                    root.notifyFailed("Hyprland did not accept the change.")
            } else if (exitCode !== 0) {
                root.notifyFailed("Game Mode is off, but Hyprland did not reload its settings.")
            }
        }
    }

    // Restoring after a shell restart.
    Process {
        id: restore
        running: true
        command: ["sh", "-c", "[ -f \"${XDG_RUNTIME_DIR:-/tmp}/sekaipop-gamemode\" ] && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                // A toggle that got in first (it cannot, set() waits for `loaded`) wins.
                if (!root.loaded && text.trim() === "1")
                    root.enabled = true
                root.loaded = true
            }
        }
    }

    // If the read never answers, start anyway with Game Mode off.
    Timer {
        interval: 2000
        running: !root.loaded
        onTriggered: root.loaded = true
    }

    IpcHandler {
        target: "gamemode"

        function toggle(): void { root.toggle() }
        function enable(): void { root.set(true) }
        function disable(): void { root.set(false) }
        function status(): string { return root.enabled ? "on" : "off" }
    }
}
