pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// When the welcome screen (modules/sekai/welcome/) is on screen.
//
// The first time the shell starts it comes up by itself, a moment after the
// wallpaper and settings have loaded so the colours are the right ones. After
// that it only comes back when asked:
//
//   qs -c sekaipop ipc call welcome show      play it again
//   qs -c sekaipop ipc call welcome hide      close it
//   qs -c sekaipop ipc call welcome toggle
//   qs -c sekaipop ipc call welcome reset     forget that it was seen: it shows
//                                            itself again at the next start
//   qs -c sekaipop ipc call welcome dismiss   never show it by itself
//
// "Seen" is one small file, written by scripts/state/welcome-state.sh (see
// there for why it counts tries). It is written when the screen ends, by
// finishing it or by pressing Esc, and only for the automatic showing: playing
// it with `show` never touches it.
//
// The life of one showing, which the windows (WelcomeScreen.qml) follow:
//
//   open()         active = true: the windows are created
//   beginClose()   closing = true: the page plays its leaving animation
//   finish()       active = false: the windows are destroyed
//
// Nothing of the screen exists outside that: no windows, no animations, no
// textures. WelcomeScreen only loads its content while `active` is true.
//
// Game Mode (GameModeService.qml) is respected, the way it is for Edit Desktop:
// a full-screen window that takes the keyboard exclusively has no business on
// top of a game, and Game Mode turns blur and animations off to save the very
// things this screen spends. So:
//   - the automatic showing waits until Game Mode's state has been read, and if
//     Game Mode is on it does nothing at all (not even a try is counted: it
//     comes at the next start with Game Mode off);
//   - `show` does nothing while Game Mode is on;
//   - if Game Mode comes on while the screen is open, it closes itself.
Singleton {
    id: root

    // The windows exist.
    property bool active: false
    // The page is on its way out (it tells us when it is done: finish()).
    property bool closing: false
    // This showing is the automatic one, so ending it writes the "seen" flag.
    property bool automatic: false

    readonly property string script: Directories.script("state/welcome-state.sh")
    // The wallpaper and the settings have loaded, so the theme is the real one,
    // and Game Mode's state has been read (so "is it on?" has a real answer).
    readonly property bool settled: WallpaperService.ready && GameModeService.loaded

    property bool checked: false

    function open() {
        if (root.active || GameModeService.enabled)
            return;
        root.closing = false;
        root.active = true;
    }

    // Start the leaving animation. The page calls finish() when it is done;
    // the timer is only a safety net so a page that never reports can't
    // leave a full-screen window behind.
    function beginClose() {
        if (!root.active || root.closing)
            return;
        root.closing = true;
        giveUp.restart();
    }

    function finish() {
        giveUp.stop();
        if (!root.active)
            return;
        root.active = false;
        root.closing = false;
        if (root.automatic) {
            root.automatic = false;
            root.markSeen();
        }
    }

    function markSeen() {
        marker.running = true;
    }

    function maybeCheck() {
        if (root.checked || !root.settled)
            return;
        root.checked = true;
        startDelay.start();
    }

    onSettledChanged: root.maybeCheck()
    Component.onCompleted: root.maybeCheck()

    // Give the desktop a moment to draw first, so the screen opens over a
    // finished desktop and not over a half-built one. (The delay is the
    // `startDelay` timer below, next to the check it starts.)

    // Asked only when nothing speaks against showing it right now: the script
    // counts every "check" as a try, so a start that could not show the screen
    // (Game Mode on) must not spend one.
    Timer {
        id: startDelay

        interval: 1500
        onTriggered: {
            if (GameModeService.enabled || Quickshell.screens.length === 0)
                return;
            checker.running = true;
        }
    }

    Process {
        id: checker

        command: ["sh", root.script, "check"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Game Mode may have come on during the delay or the check
                if (text.trim() !== "SHOW" || GameModeService.enabled)
                    return;
                root.automatic = true;
                root.open();
            }
        }
    }

    Connections {
        target: GameModeService

        function onEnabledChanged() {
            if (GameModeService.enabled)
                root.beginClose();
        }
    }

    Process {
        id: marker

        command: ["sh", root.script, "done"]
    }

    Process {
        id: resetter

        command: ["sh", root.script, "reset"]
    }

    Timer {
        id: giveUp

        interval: 3000
        onTriggered: root.finish()
    }

    IpcHandler {
        target: "welcome"

        // Does nothing while Game Mode is on (see the top of this file).
        function show(): void {
            root.open();
        }

        function hide(): void {
            root.beginClose();
        }

        function toggle(): void {
            if (root.active)
                root.beginClose();
            else
                root.open();
        }

        function reset(): void {
            resetter.running = true;
        }

        function dismiss(): void {
            root.markSeen();
        }

        function status(): string {
            return root.active ? (root.closing ? "closing" : "showing") : "idle";
        }
    }
}
