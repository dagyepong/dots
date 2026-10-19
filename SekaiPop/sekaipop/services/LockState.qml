pragma Singleton
import QtQuick
import Quickshell

// Whether the screen is locked — state only, same role as
// WallpaperService.qml: no window, no PAM, no UI. Lockscreen.qml turns
// this into an actual session lock, and LockRing.qml plays the wallpaper
// transition (the style picked in Settings -> Desktop -> Wallpaper) over the
// real desktop on the way in and out.
//
// Anything that wants to lock the screen (the Quick Panel's Power menu,
// an IPC call, an idle timer) does:
//
//   import qs.services
//   ...
//   LockState.lock()
//
// There is deliberately no public "unlock" — only Lockscreen.qml calls
// beginUnlock(), and only after PAM has accepted the password.
//
// The phases, in order:
//
//   idle       nothing on screen
//   locking    the transition plays over the live desktop (the session is NOT
//              locked yet, so bar and windows are still really there)
//   locked     transition finished -> the compositor's session lock is engaged
//              and shows the lockscreen
//   unlocking  password accepted -> the session lock is released at once,
//              and the transition plays the other way over the live desktop
//   idle       transition finished, overlay gone
Singleton {
    id: root

    // The compositor's session lock (WlSessionLock.locked). Only true in
    // the "locked" phase.
    property bool locked: false

    property string phase: "idle"

    // When the current lock began (the lockscreen shows "Locked since ...").
    property date lockedAt: new Date()

    // True for exactly as long as the compositor's session lock is engaged (phase "locked"):
    // from then on nothing but the lock surface is drawn, so whatever the rest of the shell
    // is doing is invisible and can be stopped. It turns true when the lock ring has finished
    // and false the moment the password is accepted (phase "unlocking"), so everything that
    // listens to it is already coming back while the unlock ring opens up the desktop.
    // Never true during "locking" (the desktop is still on screen under the ring) or
    // "unlocking". Settings -> General -> Launcher & lock -> "Sleep the desktop while locked"
    // (`lock.sleepDesktop`) turns it off: this then stays false and nothing is stopped.
    readonly property bool desktopAsleep: root.phase === "locked" && SettingsService.flag("lock.sleepDesktop")

    // Which transition locking and unlocking play: the wallpaper switcher's
    // style (Settings -> Desktop -> Wallpaper), so the lock feels like a
    // wallpaper change. To pin one, replace the binding of `wantedStyle`
    // with a style name ("sekaiRing", "star", "diagonalBlocks", "sekaiIris",
    // "sekaiFlash" or "fade"). If that style's lock shader could not be loaded
    // (its .qsb was never built), LockRing.qml sets styleFallback and the
    // lock plays the ring instead, which always has a shader.
    readonly property string wantedStyle: WallpaperService.transitionStyle
    readonly property string transitionStyle: root.styleFallback ? "sekaiRing" : root.wantedStyle
    property bool styleFallback: false
    // Picking another style in Settings gets a fresh try.
    onWantedStyleChanged: root.styleFallback = false

    // How long it takes, both ways. Follows the style's own timing (the
    // same as a wallpaper change in that style); put a number here instead
    // (e.g. 900) to make locking / unlocking quicker.
    readonly property int ringMs: WallpaperService.transitionMsFor(root.transitionStyle)

    // Someone asked to lock while the unlock ring was still playing.
    property bool relockPending: false

    function lock() {
        if (root.phase === "unlocking") {
            root.relockPending = true
            return
        }
        if (root.phase !== "idle")
            return
        root.lockedAt = new Date()
        // With the "Random" transition: pick this lock's style now.
        WallpaperService.rollLockStyle()
        root.phase = "locking"
    }

    // Lockscreen.qml only: the lock ring has finished (or timed out).
    function engage() {
        if (root.phase !== "locking")
            return
        root.locked = true
        root.phase = "locked"
    }

    // Lockscreen.qml only, right after a successful PAM check. The session
    // lock is released immediately; LockRing.qml's overlay is already up
    // and hides the desktop until the ring opens it.
    function beginUnlock() {
        if (root.phase !== "locked")
            return
        root.locked = false
        WallpaperService.rollLockStyle()
        root.phase = "unlocking"
    }

    // Lockscreen.qml only: the unlock ring has finished (or timed out).
    function finishUnlock() {
        if (root.phase !== "unlocking")
            return
        root.phase = "idle"
        if (root.relockPending) {
            root.relockPending = false
            root.lock()
        }
    }
}
