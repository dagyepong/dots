// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L O C K   S E R V I C E                                                │
// │   session lock state · background capture and authentication             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// Locks the session through ext-session-lock instead of an external locker,
// so the desktop can stay on screen behind the lock, blurred.
//
// The screenshot is a grim process rather than a ScreencopyView because it
// has to finish before the lock surface is mapped. It goes to the runtime
// directory (tmpfs, user-only) and is deleted on unlock.
//
// The password is handed straight to PAM's `respond` and never stored.
Singleton {
    id: root

    property bool locked: false

    // `locked` is the request; this is the compositor confirming the screen
    // is covered.
    property bool secure: false

    property bool authenticating: false
    property string message: ""
    property bool failed: false

    readonly property string shotDirectory:
        `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/quickshell`
    readonly property string shotPath: `${root.shotDirectory}/lock.png`

    // Bumped per capture so the Image source changes and Qt does not serve
    // the previous lock's cached frame.
    property int shotSerial: 0
    property bool shotReady: false

    readonly property string shotSource:
        root.shotReady ? `file://${root.shotPath}?v=${root.shotSerial}` : ""

    signal unlocked()

    // ── LOCKING ─────────────────────────────────────────────────────────────

    // False while a panel is still on screen and would end up in the
    // screenshot. Bound in `shell.qml`, which can see the bar.
    property bool shellQuiet: true

    property bool pendingCapture: false

    function lock(): void {
        if (root.locked)
            return
        root.message = ""
        root.failed = false
        root.shotReady = false
        // Capture first, surface second — and only once the island has
        // closed, or the screenshot shows the panel the lock came from.
        root.pendingCapture = true
        root.attemptCapture()
    }

    function attemptCapture(): void {
        if (!root.pendingCapture)
            return
        if (!root.shellQuiet) {
            root.settleFrame.stop()
            root.quietGiveUp.restart()
            return
        }
        root.settleFrame.restart()
    }

    onShellQuietChanged: root.attemptCapture()

    // grim reads the compositor, not this scene graph, and there is no signal
    // for "the frame is on screen": two frames at 60 Hz.
    readonly property Timer settleFrame: Timer {
        interval: 32
        onTriggered: root.beginCapture()
    }

    // Lock anyway if the shell never settles: an untidy screenshot is better
    // than an unlocked machine.
    readonly property Timer quietGiveUp: Timer {
        interval: 900
        onTriggered: {
            console.warn("The shell did not settle; locking with whatever is on screen.")
            root.beginCapture()
        }
    }

    function beginCapture(): void {
        if (!root.pendingCapture)
            return
        root.pendingCapture = false
        root.settleFrame.stop()
        root.quietGiveUp.stop()
        root.capture.running = true
    }

    // grim hangs instead of failing when the output is already powered off,
    // and the lock only goes up in `onExited`, hence the timeout.
    readonly property Process capture: Process {
        command: ["sh", "-c",
            `mkdir -p '${root.shotDirectory}' && timeout 2 grim '${root.shotPath}'`]

        // Lock whether or not the screenshot worked.
        onExited: (code, status) => {
            root.shotSerial += 1
            root.shotReady = code === 0
            root.locked = true
            root.begin()
        }
    }

    function forget(): void {
        root.shotReady = false
        root.eraser.running = true
    }

    readonly property Process eraser: Process {
        command: ["rm", "-f", root.shotPath]
    }

    // ── AUTHENTICATING ──────────────────────────────────────────────────────

    // A PAM conversation ends after a refusal, so every attempt starts a new
    // one.
    function begin(): void {
        if (pam.active)
            pam.abort()
        root.authenticating = false
        pam.start()
    }

    function submit(password: string): void {
        if (root.authenticating || password === "")
            return
        root.failed = false
        root.message = ""

        // PAM has normally asked by now. If not, restart it and let the user
        // retry rather than keep the password around until it does.
        if (!pam.responseRequired) {
            root.begin()
            root.message = "Not ready — press Enter again"
            return
        }

        root.authenticating = true
        pam.respond(password)
    }

    readonly property PamContext pam: PamContext {
        // The same stack hyprlock's PAM file includes.
        config: "login"

        onCompleted: result => {
            root.authenticating = false
            if (result === PamResult.Success) {
                root.locked = false
                root.message = ""
                root.failed = false
                root.forget()
                root.unlocked()
                return
            }
            root.failed = true
            root.message = result === PamResult.MaxTries
                ? "Too many attempts"
                : "Wrong password"
            root.begin()
        }

        onError: error => {
            root.authenticating = false
            root.failed = true
            root.message = "Authentication is unavailable"
            console.warn("PAM error while unlocking:", error)
        }
    }
}
