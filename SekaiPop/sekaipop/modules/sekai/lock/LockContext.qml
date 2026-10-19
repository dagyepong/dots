import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.services

// The password side of the lockscreen: what's been typed, and asking
// PAM whether it's right. Shared by every monitor's LockSurface (the
// keyboard only reaches one of them, but the dots show on all), so it
// lives here rather than in the surface — the same split as
// QuickPanel.qml / QuickSource.qml.
//
// Pure logic, no pixels. Same PamContext idea as the Quickshell
// lockscreen example: PAM asks for the password, we answer with what's
// typed, and it reports back success or failure.
Scope {
    id: root

    // The PAM service to check the password against. "login" is
    // Quickshell's own default and what most setups want (it's the one
    // that also honours faillock). If a correct password is refused with
    // "PAM error", check /etc/pam.d/ for what your distro calls it —
    // e.g. "system-auth" — and change this one line.
    property string pamService: "login"

    property string currentText: ""
    property bool unlockInProgress: false

    // "" = nothing to say, otherwise the message under the field.
    property string failureText: ""
    // Bumped on every failed attempt, so the surface can shake even when
    // two failures in a row leave failureText unchanged.
    property int failureCount: 0

    signal unlocked()
    // Asks the surface(s) to grab keyboard focus again (see Lockscreen.qml).
    signal focusRequested()

    // Ctrl+A: the whole password is "selected" (the dots light up). The next
    // key typed replaces it, Backspace / Delete wipes it. Any change to the
    // text, or an empty field, drops the selection.
    property bool allSelected: false
    function selectAll() {
        if (unlockInProgress || currentText.length === 0)
            return
        allSelected = true
    }

    // ===== keys that act on the whole session (the Calendar lockscreen) =====
    // Shared by every monitor, like the typed text, so a key pressed on one screen
    // shows on all of them.

    // True while Ctrl is held. The Calendar lockscreen turns its Enter key into the
    // coffee key (sleep) for as long as it is; Ctrl+Enter, or a click on it, sleeps.
    property bool ctrlHeld: false

    // Restart and Shut down ask twice: the first press arms one of them ("reboot" or
    // "poweroff") for a few seconds, the second one, on the same key, does it. "" =
    // nothing armed. While one is armed the key looks for an install or a download
    // that would be cut off (PowerBusyService), and says so.
    property string armed: ""

    function powerPress(kind) {
        // Only a really locked session acts: LockRing's copy of the picture, which
        // exists while the lock is still arriving, must never.
        if (LockState.phase !== "locked" || (kind !== "reboot" && kind !== "poweroff"))
            return
        if (root.armed !== kind) {
            root.armed = kind
            armTimer.restart()
            return
        }
        armTimer.stop()
        root.armed = ""
        if (kind === "reboot")
            rebootAction.running = true
        else
            powerOffAction.running = true
    }

    // Suspend to RAM. The session is already locked, so it wakes up on this screen.
    function sleep() {
        if (LockState.phase !== "locked")
            return
        root.armed = ""
        root.clearText()
        sleepAction.running = true
    }

    Timer {
        id: armTimer
        interval: 4000
        onTriggered: root.armed = ""
    }

    Binding {
        target: PowerBusyService
        property: "watching"
        value: true
        when: root.armed !== ""
    }

    Process {
        id: rebootAction
        command: ["sh", "-c", "systemctl reboot || loginctl reboot"]
    }

    Process {
        id: powerOffAction
        command: ["sh", "-c", "systemctl poweroff || loginctl poweroff"]
    }

    Process {
        id: sleepAction
        command: ["sh", "-c", "systemctl suspend || loginctl suspend"]
    }

    function typeText(t) {
        if (unlockInProgress)
            return
        if (allSelected)
            currentText = t
        else
            currentText += t
    }

    function backspace() {
        if (unlockInProgress)
            return
        if (allSelected)
            currentText = ""
        else
            currentText = currentText.slice(0, -1)
    }

    function clearText() {
        currentText = ""
    }

    // Also called when the lock engages, so a half-typed password from
    // the last session (or a failure message) is never shown.
    function reset() {
        pam.abort()
        currentText = ""
        failureText = ""
        unlockInProgress = false
        ctrlHeld = false
        armed = ""
    }

    function tryUnlock() {
        // Only once the session lock is really engaged: the lockscreen
        // picture also exists earlier, inside LockRing.qml's overlay, but
        // nothing may unlock before the lock does.
        if (!LockState.locked || unlockInProgress || currentText.length === 0)
            return
        failureText = ""
        unlockInProgress = true
        pam.start()
    }

    onCurrentTextChanged: {
        allSelected = false
        if (currentText.length > 0)
            failureText = ""
        idleClear.restart()
    }

    // Walked away mid-password: don't leave it sitting on the screen.
    Timer {
        id: idleClear
        interval: 15000
        onTriggered: {
            if (!root.unlockInProgress)
                root.clearText()
        }
    }

    PamContext {
        id: pam
        config: root.pamService

        // The password prompt: answer it with what was typed.
        onPamMessage: {
            if (this.responseRequired)
                this.respond(root.currentText)
        }

        onCompleted: result => {
            root.unlockInProgress = false
            if (result === PamResult.Success) {
                root.currentText = ""
                root.failureText = ""
                root.unlocked()
                return
            }
            root.currentText = ""
            root.failureCount++
            if (result === PamResult.Error)
                root.failureText = "Couldn't check the password (PAM error)"
            else if (result === PamResult.MaxTries)
                root.failureText = "Too many tries — wait a moment"
            else
                root.failureText = "Wrong password"
        }
    }
}
