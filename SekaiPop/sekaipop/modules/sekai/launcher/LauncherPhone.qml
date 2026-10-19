import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.services
import "../../common/functions/PhoneMath.js" as PM
import "../../common/functions/FlipMath.js" as FM
import qs.modules.sekai.phone
import qs.modules.sekai.wallpaperSelector

// The launcher phone: the shell's home screen and wallpaper switcher,
// as ONE phone that lives in the bottom-left corner of the screen and behaves
// exactly like the Quick Panel's phone (QuickPanel.qml), just from the other
// side:
//
//   - it is the same 2.5D body (PhoneBody.qml), the same size, the same pose
//   - a hot corner (a thin strip at the bottom-left of each screen) pulls it up
//     after a short dwell, with the same bounce and the same pocket tilt that
//     rings out as it lands
//   - it stays up with its lower part below the screen edge (`peek`, the same
//     "How much of the phone shows" setting as the Quick Panel)
//   - moving the mouse away does NOT close it; click outside it, press the
//     keybind again, or pick an app. It then drops back out of sight the way
//     the Quick Panel does (a little pull up first)
//
// Its screens:
//   Home / Apps  LauncherFace.qml: search, the built-ins (Wallpapers,
//                Settings), your pinned apps, and every installed app A to Z.
//   Wallpapers   WallpaperFace.qml: the wheel / grid gallery. The same phone rolls a
//                quarter turn (FlipMath.js, WallpaperStage.qml) into the flat
//                landscape one, still in the corner.
// Wallpapers need the whole screen of the phone, so for them it
// rises the rest of the way (`riseK`) and sits fully on screen in the corner;
// going back to Home lowers it to its peeking spot again.
//
// Nothing here opens in the middle of the monitor any more.
//
// The phone now has ONE front door, the Quick Panel's (QuickPanel.qml, `ipc call
// phone`): the Home / Apps screen moved into it, and the bottom-left hot corner and
// the `launcherphone` IPC are gone from this file. What is left here is the
// Wallpapers screen, until it moves into the one phone too. Its Home
// screen (LauncherFace) is no longer reachable. (The Overview phone that used to
// live here is gone.)
//
// Ways to open it:
//   - from the Apps screen of the one phone (the Wallpapers tile); Back
//     there returns to Apps (`returnToApps`)
//   - straight into the Wallpapers: qs -c sekaipop ipc call wallpaperphone toggle
//   - the bar's wallpaper key and the Quick Panel's wallpaper actions
//     (`openWallpapersOn` / `toggleWallpapersOn`, see shell.qml's `wallpaperEntry`)
//
// It opens on the monitor you pointed at (the focused one for a keybind).
// Like QuickPanel.qml, this is one of the files that talks to the system.
Scope {
    id: root

    // AppSource: the app index (`allApps`, `rank()`, `launch()`).
    required property var source

    // What the built-ins open.
    property var quickPanel: null        // QuickPanel (openSettings)
    property var overviewBoard: null     // Overview (kept for shell.qml; not used here any more)

    property bool open: false
    // The window is mapped: from the moment it is asked for until the drop-out
    // has finished.
    property bool shown: false
    property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    // ===== things you're likely to change (same names and values as QuickPanel.qml) =====
    // How much of the phone shows when it's up, as a fraction of its height (it
    // shares the Quick Panel's setting).
    property real peek: SettingsService.get("panel.peek") / 100

    property real barHeight: 63
    property real edgeMargin: 10
    property real maxScale: 1
    // Empty room above the phone for the pull-out's overshoot.
    property real headroom: 44
    // How far (design px, scaled like everything else) the phone's left edge is
    // from the screen's left edge.
    property real cornerGap: 24

    // The pull-out: how far (px) it rises past its resting spot before dropping
    // back, and the degrees it is turned while it is still "in the pocket".
    property real bounce: 34
    property real tiltRoll: 12
    property real tiltPitch: 10
    property real tiltYaw: -6

    // The Wallpapers were opened from the Apps screen of the one phone
    // (QuickPanel.qml): Back goes there again instead of just closing. Asked for
    // before the phone opens (`wantReturnApps`), taken when it does, and cleared
    // once it has gone.
    property bool returnToApps: false
    property bool wantReturnApps: false

    // How far (px) the phone sits below its resting spot: 0 at rest, huge while
    // it has never been shown; negative during the overshoot. 1 = turned the way
    // it is in the pocket, 0 = upright.
    property real lift: 100000
    property real tilt: 1
    // Where the pull-up before leaving peaks, and how long it takes.
    property real exitPeak: 0
    property real exitPeakMs: 130
    property real exitDrop: 0

    // How far up the phone has come from its peeking spot to its fully-on-screen
    // spot, 0..1. It is 1 while it is the Wallpapers phone.
    readonly property real riseTarget: root.wallpapersOpen ? 1 : 0
    property real riseK: riseTarget
    Behavior on riseK {
        enabled: win.visible
        NumberAnimation {
            id: riseAnim
            duration: 320
            easing.type: Easing.OutCubic
        }
    }

    readonly property bool animating: enterAnim.running || exitAnim.running || exitDelay.running
                                      || riseAnim.running

    // ===== the turn into the Wallpapers phone =====
    // `flip` is FlipMath.js's p: 0 = this phone, 1 = the Wallpapers phone.
    property bool wallpapersOpen: false
    property real flip: 0
    // The roll the turn rings out with when it lands, in degrees.
    property real wob: 0
    property int ringSign: -1
    // The turn: 200 ms on a soft bezier (the Quick Panel's, see QuickPanel.flipCurve). It was
    // 260 ms of OutCubic, over in a few frames, with the screens swapping in the middle of that.
    property int flipMs: 200
    readonly property var flipCurve: [0.30, 0.0, 0.20, 1.0, 1.0, 1.0]
    property real flipDip: 0.12
    property real flipWobble: 2.5
    property int flipRingMs: 380
    readonly property bool flipping: flipPrep.running || flipAnim.running
    // Opened straight into the Wallpapers (the IPC `wallpaperphone`, the bar's
    // wallpaper key), not from Home: X / Escape then closes the phone.
    property bool wallpaperDirect: false
    property bool wantWallpapers: false
    // "desktop" or "lock": which side's picture the gallery is choosing for.
    property string wallpaperTarget: "desktop"

    function focusedScreen() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        for (const s of Quickshell.screens) {
            if (s.name === name)
                return s
        }
        return Quickshell.screens[0]
    }

    function openOn(screen) {
        // Edit Desktop keeps the monitor on one empty workspace.
        if (EditMode.active)
            return
        if (screen)
            targetScreen = screen
        open = true
    }

    function close() {
        open = false
    }

    function toggleOn(screen) {
        if (open && (!screen || screen === targetScreen))
            close()
        else
            openOn(screen)
    }

    // The Quick Panel is the other phone at the bottom of the screen: only one
    // of them is up at a time.
    Connections {
        target: EditMode
        function onActiveChanged() {
            if (EditMode.active)
                root.close()
        }
    }

    // How far (px) the phone has to drop to be completely out of sight from where
    // it stands now.
    function dropDistance() {
        const portrait = win.shownHeight + win.riseNeeded * root.riseK
        const land = root.flip > 0.02 ? win.landFull : 0
        return Math.ceil(Math.max(portrait, land)) + 2
    }

    onOpenChanged: {
        if (open) {
            if (root.quickPanel && (root.quickPanel.open || root.quickPanel.settingsOpen))
                root.quickPanel.close()
            exitDelay.stop()
            exitAnim.stop()
            root.resetTurn()
            // Asked for through `wallpaperphone`: it comes up already turned
            // into the Wallpapers.
            root.wallpaperDirect = root.wantWallpapers
            if (root.wantWallpapers) {
                root.wallpapersOpen = true
                root.flip = 1
            }
            root.wantWallpapers = false
            root.returnToApps = root.wantReturnApps
            root.wantReturnApps = false
            face.reset()
            root.shown = true
            // Coming up from nothing starts fully out of sight; coming back
            // mid-way through leaving carries on from where it is.
            const hidden = root.dropDistance()
            if (root.lift > hidden)
                root.lift = hidden
            enterAnim.restart()
            focusTimer.restart()
        } else {
            enterAnim.stop()
            // A small pull up first, unless it's still on its way up.
            const rising = root.lift > 20
            root.exitPeak = rising ? root.lift : -root.bounce * 0.7
            root.exitPeakMs = rising ? 1 : 130
            root.exitDrop = root.dropDistance()
            // Sitting still, the phone is drawn at full quality, which is too
            // heavy to animate on. Switching down to the light settings redraws
            // it once, so that is done a couple of frames *before* it starts to
            // move (the same trick QuickPanel.qml's exit uses).
            if (phone.crisp)
                exitDelay.restart()
            else
                exitAnim.restart()
        }
    }

    // ===== the pull-out =====
    ParallelAnimation {
        id: enterAnim

        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "lift"
                to: -root.bounce
                duration: 340
                easing.type: Easing.OutCubic
            }
            // The settle never goes below the resting spot (it would drag the
            // phone's lower part under the screen edge for a moment), so the
            // bounce stays upward only.
            NumberAnimation {
                target: root
                property: "lift"
                to: 0
                duration: 170
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: root
                property: "lift"
                to: -root.bounce * 0.14
                duration: 110
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "lift"
                to: 0
                duration: 110
                easing.type: Easing.InQuad
            }
        }

        NumberAnimation {
            target: root
            property: "tilt"
            to: 0
            duration: 820
            easing.type: Easing.OutElastic
            easing.amplitude: 1
            easing.period: 0.4
        }
    }

    // A short beat between "close requested" and the drop actually starting.
    Timer {
        id: exitDelay
        interval: 40
        onTriggered: {
            if (!root.open)
                exitAnim.restart()
        }
    }

    // Going back: a little pull up (like lifting it clear of the pocket), then it
    // drops away, speeding up, tilting back as it goes.
    ParallelAnimation {
        id: exitAnim

        onFinished: {
            root.shown = false
            root.lift = 100000
            root.tilt = 1
            root.resetTurn()
            root.returnToApps = false
        }

        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "lift"
                to: root.exitPeak
                duration: root.exitPeakMs
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "lift"
                to: root.exitDrop
                duration: 340
                easing.type: Easing.InCubic
            }
        }

        NumberAnimation {
            target: root
            property: "tilt"
            to: 1
            duration: 440
            easing.type: Easing.InQuad
        }
    }

    // ===== turning into the Wallpapers and back =====
    // Back to this phone, standing straight (nothing turning, nothing ringing).
    function resetTurn() {
        flipPrep.stop()
        flipAnim.stop()
        ring.stop()
        root.wob = 0
        root.flip = 0
        root.wallpapersOpen = false
        root.wallpaperDirect = false
    }

    function turnTo(p) {
        ring.stop()
        root.wob = 0
        flipAnim.stop()
        flipAnim.to = p
        flipPrep.restart()
    }

    function openWallpapers() {
        if (!root.open || root.wallpapersOpen)
            return
        root.wallpapersOpen = true
        root.turnTo(1)
    }

    // The Wallpapers' X, or Escape on their gallery.
    function leaveWallpapers() {
        if (!root.wallpapersOpen)
            return
        root.wallpapersOpen = false
        root.turnTo(0)
    }

    // The Wallpapers, from outside (the bar's wallpaper key, the Quick Panel's
    // wallpaper actions, the IPC): the phone comes up already turned into them,
    // or turns into them if it is up already. `which` is "lock" for the
    // lockscreen side.
    function openWallpapersOn(screen, which) {
        if (EditMode.active)
            return
        root.wallpaperTarget = which === "lock" ? "lock" : "desktop"
        wallStage.setTarget(root.wallpaperTarget)
        if (root.open) {
            if (screen && screen !== root.targetScreen) {
                // Another monitor: the phone moves there, already turned.
                root.wantWallpapers = true
                root.targetScreen = screen
                root.open = false
                root.open = true
                if (!root.open)
                    root.wantWallpapers = false
                return
            }
            if (!root.wallpapersOpen) {
                root.wallpaperDirect = true
                root.openWallpapers()
            }
            return
        }
        root.wantWallpapers = true
        root.openOn(screen)
        // Edit Desktop (or anything else that refuses to open it).
        if (!root.open)
            root.wantWallpapers = false
    }

    // The Apps screen's Wallpapers tile: the phone comes up on it and Back
    // returns to the Apps screen.
    function openWallpapersFromApps(screen) {
        root.wantReturnApps = true
        root.openWallpapersOn(screen)
        if (!root.open)
            root.wantReturnApps = false
    }

    // Back / Home / X on the Wallpapers: to the Apps screen of
    // the one phone when that is where it came from, otherwise just away.
    function leaveToApps() {
        const screen = root.targetScreen
        const back = root.returnToApps
        root.close()
        if (back && root.quickPanel)
            root.quickPanel.openAppsOn(screen)
    }

    function toggleWallpapersOn(screen, which) {
        const same = !screen || screen === root.targetScreen
        const side = which === "lock" ? "lock" : "desktop"
        if (root.open && root.wallpapersOpen && same && (which === undefined || side === root.wallpaperTarget))
            root.close()
        else
            root.openWallpapersOn(screen, which)
    }

    // The turn starts a beat later: it redraws the phones on the light
    // settings, which is done a couple of frames before it moves (the same
    // thing QuickPanel.qml does).
    Timer {
        id: flipPrep
        interval: 40
        onTriggered: {
            root.ringSign = flipAnim.to > 0.5 ? -1 : 1
            flipAnim.restart()
            ring.restart()
        }
    }

    NumberAnimation {
        id: flipAnim
        target: root
        property: "flip"
        to: 1
        duration: root.flipMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.flipCurve
        onFinished: turnFocus.restart()
    }

    // The keyboard goes to whichever phone is up now, a beat after the turn
    // has landed (the one that was turned away only takes input again then).
    Timer {
        id: turnFocus
        interval: 70
        onTriggered: root.giveKeys()
    }

    // The ring-out: the turn carries a little past where it lands and swings
    // back, like the Quick Panel's. A roll added to both bodies at once.
    SequentialAnimation {
        id: ring

        PauseAnimation {
            duration: Math.round(root.flipMs * 0.62)
        }

        NumberAnimation {
            target: root
            property: "wob"
            to: root.ringSign * root.flipWobble
            duration: root.flipRingMs * 0.42
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            target: root
            property: "wob"
            to: -root.ringSign * root.flipWobble * 0.1
            duration: root.flipRingMs * 0.38
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            target: root
            property: "wob"
            to: 0
            duration: root.flipRingMs * 0.2
            easing.type: Easing.InOutSine
        }
    }

    // The search box takes the keyboard once the window is up and the grab has
    // taken hold.
    Timer {
        id: focusTimer
        interval: 140
        onTriggered: root.giveKeys()
    }

    // The keyboard goes to whichever screen is up.
    function giveKeys() {
        if (!root.open)
            return
        if (root.wallpapersOpen)
            wallStage.focusKeys()
        else
            face.focusSearch()
    }

    // A built-in was picked: Wallpapers is a screen of this phone, Settings is
    // the Quick Panel's phone turning into them.
    function runBuiltin(id) {
        const screen = root.targetScreen
        if (id === "wallpapers") {
            root.openWallpapers()
            return
        }
        root.close()
        if (id === "settings" && root.quickPanel)
            root.quickPanel.openSettings(screen)
    }

    IpcHandler {
        target: "wallpaperphone"

        // The Wallpapers moved onto the Quick Panel's phone (the Settings' phone);
        // these names still work and go there.
        function toggle(): void {
            if (root.quickPanel)
                root.quickPanel.toggleWallpapersOn(root.focusedScreen())
            else
                root.toggleWallpapersOn(root.focusedScreen())
        }

        function show(): void {
            if (root.quickPanel)
                root.quickPanel.openWallpapers(root.focusedScreen())
            else
                root.openWallpapersOn(root.focusedScreen())
        }

        function hide(): void {
            if (root.quickPanel && root.quickPanel.wallpapersOpen)
                root.quickPanel.close()
            else if (root.wallpapersOpen)
                root.close()
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: win.visible
    }

    // The wallpaper folder chooser (WallpaperService.pickFolder) is a window of its
    // own: the Wallpapers step aside while it is open, so it is not under the
    // phone and gets the keyboard. WallpaperService opens them again afterwards.
    Connections {
        target: WallpaperService

        function onFolderPickingChanged() {
            if (WallpaperService.folderPicking && root.wallpapersOpen)
                root.close()
        }
    }

    // ===== click away =====
    HyprlandFocusGrab {
        id: grab
        windows: [win]
        onCleared: root.close()
    }

    // The grab starts a beat after the window shows, like the Quick Panel's:
    // taking it the same frame can count the opening click as a click away.
    readonly property bool grabWanted: open && win.visible

    onGrabWantedChanged: {
        if (grabWanted) {
            grabDelay.restart()
        } else {
            grabDelay.stop()
            grab.active = false
        }
    }

    Timer {
        id: grabDelay
        interval: 80
        onTriggered: grab.active = root.grabWanted
    }

    // ===== the window =====
    // Sits on the bottom-left corner of the screen and is only as big as the
    // phone needs for everything it does in the corner (the peek, the full rise,
    // the turn into the landscape Wallpapers, the pull-out's overshoot). Its size
    // is worked out once, up front, because a window that is resized while it
    // animates stutters. Only the phone itself takes the mouse (`mask`).
    PanelWindow {
        id: win

        screen: root.targetScreen
        visible: root.shown
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sekaipop-launcherphone"
        // Exclusive, not OnDemand: OnDemand only hands the keyboard over once the
        // compositor decides this window is focused (pointer over it / clicked),
        // so with the mouse elsewhere the search box got no keys. While the
        // launcher is open it owns the keyboard, like the Overview and cheat sheet.
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors {
            left: true
            bottom: true
        }

        // The window reaches `bleed` px past the bottom of the screen, so the
        // compositor's own open animation lifting the surface a few px can never
        // show a gap under the phone (see QuickPanel.qml for the long story).
        readonly property real bleed: Math.max(24, Math.ceil(shownHeight * 0.04))
        margins.bottom: -Math.ceil(bleed)

        mask: Region {
            item: hitRect
        }

        // This monitor's scale (scale.json / services/ShellScale.qml).
        readonly property real uiScale: ShellScale.forScreen(root.targetScreen)
        readonly property real pixelRatio: root.targetScreen ? root.targetScreen.devicePixelRatio : 1
        readonly property real monitorW: root.targetScreen ? root.targetScreen.width : 1920
        readonly property real monitorH: root.targetScreen ? root.targetScreen.height : 1080

        readonly property real gapPx: Math.round(root.cornerGap * uiScale)
        readonly property real edgeMarginPx: root.edgeMargin * uiScale

        // As big as the Quick Panel's phone: shrunk to fit the screen's height
        // (never past maxScale), times the monitor's scale, but never so big that
        // the whole phone would not fit under the top of the screen.
        readonly property real fit: {
            const room = monitorH - root.barHeight - 4 - root.edgeMargin - root.headroom
            const natural = Math.max(0.3, Math.min(root.maxScale, room / phone.implicitHeight))
            const tall = phone.swing.top + phone.implicitHeight
            const cap = (monitorH - (root.barHeight + root.headroom) * uiScale) / Math.max(1, tall)
            return Math.max(0.3, Math.min(natural * uiScale, Math.max(natural, cap)))
        }

        // The Wallpapers phone's size: the same as the phone's own (so a pill is
        // the same size on screen everywhere), never wider than the monitor.
        readonly property real lfit: {
            const lw = Math.max(1, wallStage.phone.implicitWidth)
            return Math.max(0.3, Math.min(fit, (monitorW - 2 * gapPx - 8) / lw))
        }

        // This phone's size on the way into the Wallpapers (FlipMath.js).
        readonly property real pscale: FM.quickScale(root.flip, fit, lfit, root.flipDip)

        // ----- the portrait phone -----
        // The part that shows at rest, and the whole phone with a little room
        // under it (the Wallpapers standing fully on screen).
        readonly property real shownHeight: phone.implicitHeight * fit * Math.min(1, Math.max(0.2, root.peek))
        readonly property real fullBody: phone.implicitHeight * fit + edgeMarginPx
        readonly property real riseNeeded: Math.max(0, fullBody - shownHeight)
        // Where its screen's middle is: x from the window's left edge, u up from
        // the monitor's bottom edge.
        readonly property real px0: gapPx + (phone.swing.left + phone.screenCenterX) * fit
        readonly property real pu0: shownHeight - phone.screenCenterY * fit

        // ----- the landscape Wallpapers phone -----
        readonly property real landFull: wallStage.phone.implicitHeight * lfit + edgeMarginPx
        readonly property real px1: gapPx + (wallStage.phone.swing.left + wallStage.phone.screenCenterX) * lfit
        readonly property real pu1: landFull - wallStage.phone.screenCenterY * lfit

        // ----- how big the window has to be -----
        // Found by walking the whole turn (a little before its start and past its
        // end, for the wind-up and the overshoot) and asking PhoneMath where both
        // bodies' outlines land at each step, so the window is as big as the move
        // needs and no bigger (the same walk QuickPanel.qml's flipRoom does).
        readonly property var turnRoom: {
            const sp = wallStage.phone
            const qcx = phone.screenCenterX, qcy = phone.screenCenterY
            const scx = sp.screenCenterX, scy = sp.screenCenterY
            const uStart = pu0 + riseNeeded
            let needU = 0, needX = 0
            for (let i = -4; i <= 24; i++) {
                const p = i / 20
                const A = FM.quickScale(p, fit, lfit, root.flipDip)
                const As = A / FM.SIZE_RATIO
                const x = px0 + (px1 - px0) * p
                const u = uStart + (pu1 - uStart) * p
                const yw = phone.yaw + (wallStage.yaw - phone.yaw) * p
                const pt = phone.pitch + (wallStage.pitch - phone.pitch) * p
                const bq = PM.boundsFor(phone.faceWidth, phone.faceHeight, phone.thickness, phone.cornerRadius,
                                        yw, pt, phone.roll + FM.quickRoll(p), phone.perspective, phone.pose)
                const bs = PM.boundsFor(sp.faceWidth, sp.faceHeight, sp.thickness, sp.cornerRadius,
                                        yw, pt, sp.roll + FM.settingsRoll(p), sp.perspective, sp.pose)
                needU = Math.max(needU, u + (qcy - bq.minY) * A, u + (scy - bs.minY) * As)
                needX = Math.max(needX, x + (bq.maxX - qcx) * A, x + (bs.maxX - scx) * As)
            }
            return { u: needU, x: needX }
        }

        // Height above the monitor's bottom edge, with room above for the bounce.
        readonly property real topU: Math.min(monitorH, Math.ceil(Math.max(
            fullBody + phone.swing.top * fit,
            landFull + wallStage.phone.swing.top * lfit,
            turnRoom.u) + root.headroom * uiScale))
        readonly property real winW: Math.min(monitorW, Math.ceil(Math.max(
            px0 + (phone.implicitWidth + phone.swing.right - phone.screenCenterX) * fit,
            px1 + (wallStage.phone.implicitWidth + wallStage.phone.swing.right
                   - wallStage.phone.screenCenterX) * lfit,
            turnRoom.x) + 4))

        implicitWidth: winW
        implicitHeight: topU + Math.ceil(bleed)

        // ----- where the pivot (the middle of the phone's screen) is -----
        // The Wallpapers turn carries it from the portrait phone's spot to the
        // landscape one's (FlipMath.js's p), like the Quick Panel's turn does.
        readonly property real riseUp: riseNeeded * root.riseK
        readonly property real portraitU: pu0 + riseUp
        readonly property real pivotU: portraitU + (pu1 - portraitU) * root.flip
        readonly property real pivotXRaw: px0 + (px1 - px0) * root.flip
        readonly property real pivotYRaw: topU - pivotU + root.lift

        // The bottom of the face that is above the monitor's edge, in the face's
        // own 654x1214 coordinates (QuickPanel.qml's faceCutoffAt, at rest): the
        // Home screen lays its bottom button out above it. The cutoff is level on
        // the monitor but slanted on the face, so the higher end is what counts.
        function faceCutoffAt(x) {
            const m = PM.baseFor(phone.faceWidth, phone.faceHeight, phone.thickness,
                                 phone.yaw, phone.pitch, phone.roll,
                                 phone.perspective, phone.pose)
            const Y = shownHeight / fit
            const den = Y * m[13] - m[5]
            if (Math.abs(den) < 1e-9)
                return phone.faceHeight
            return Math.min(phone.faceHeight, (m[4] * x + m[7] - Y * (m[12] * x + m[15])) / den)
        }
        readonly property real faceVisibleBottom: Math.min(faceCutoffAt(0), faceCutoffAt(phone.faceWidth))

        // ----- sharpness -----
        // Once it has settled, the picture is put on a whole device pixel (the
        // same thing SettingsStage.qml does).
        readonly property bool settled: root.open && root.lift === 0 && root.tilt === 0 && !root.animating
                                        && root.flip === 0 && !root.flipping && !root.wallpapersOpen
        readonly property real gridPx: Math.max(1, pixelRatio)
        readonly property real sceneX: pivotXRaw - phone.screenCenterX * fit - (phone.layerSwing.left + 8) * fit
        readonly property real sceneY: pivotYRaw - phone.screenCenterY * fit - (phone.layerSwing.top + 8) * fit

        readonly property real snapX: settled ? Math.round(sceneX * gridPx) / gridPx - sceneX : 0
        readonly property real snapY: settled ? Math.round(sceneY * gridPx) / gridPx - sceneY : 0

        // What takes the mouse: the phone's own rectangle, and only while it is
        // open. While it is the Wallpapers phone (or turning into it) that is the
        // landscape one's rectangle. The window ends at the screen's bottom edge,
        // so what hangs below is simply off the screen.
        Item {
            id: hitRect

            readonly property bool land: root.wallpapersOpen || root.flip > 0.02
            readonly property real w: land ? wallStage.phone.implicitWidth * win.lfit
                                           : phone.implicitWidth * win.fit
            readonly property real topY: land ? (win.topU - win.landFull)
                                             : win.topU - win.shownHeight - win.riseUp

            x: land ? (win.px1 - wallStage.phone.screenCenterX * win.lfit)
                    : win.px0 - phone.screenCenterX * win.fit
            y: topY
            width: root.open ? w : 0
            height: root.open ? Math.max(0, win.topU + Math.ceil(win.bleed) - topY) : 0
        }

        // The point it turns about: the middle of the screen.
        Item {
            id: pivot

            x: win.pivotXRaw + win.snapX
            y: win.pivotYRaw + win.snapY

            PhoneBody {
                id: phone

                // Its screen's middle stays on the pivot whatever size the turn
                // makes it (FlipMath.quickScale).
                x: -phone.screenCenterX * win.pscale
                y: -phone.screenCenterY * win.pscale
                transformOrigin: Item.TopLeft
                scale: win.pscale

                // Its screen dissolves into the Wallpapers' while it turns.
                opacity: FM.quickAlpha(root.flip)
                visible: opacity > 0.001
                enabled: root.flip === 0 && !root.flipping

                // Window not mapped: the layer buffers are given back after a while
                // (PhoneBody `warm`).
                windowShown: win.visible

                // Drawn on the light settings while it moves and while it is
                // away, the full-quality ones take over once it has landed.
                moving: root.animating || !win.visible || root.flipping
                turnRoll: root.flipping ? -90 : 0

                // Turned while it is coming out of / going into the pocket, and
                // rings out past upright on the overshoot (the Quick Panel's
                // numbers). On the turn into the Wallpapers it is rolled a
                // quarter turn and eased to the flat phone's pose (FlipMath.js).
                rollOffset: root.tilt * root.tiltRoll + FM.quickRoll(root.flip) + root.wob
                pitchOffset: root.tilt * root.tiltPitch + (wallStage.pitch - phone.pitch) * root.flip + root.wob * 0.5
                yawOffset: root.tilt * root.tiltYaw + (wallStage.yaw - phone.yaw) * root.flip
                swingRoll: root.tiltRoll
                swingPitch: root.tiltPitch
                swingYaw: root.tiltYaw

                // Draw the screen at the size it ends up on the monitor.
                renderScale: win.fit * win.pixelRatio

                LauncherFace {
                    id: face

                    source: root.source
                    renderScale: phone.renderScale
                    // Only this much of the phone shows at rest: the bottom
                    // button is laid out above the monitor's edge.
                    visibleBottom: win.faceVisibleBottom
                    clockText: Qt.formatDateTime(clock.date, SettingsService.flag("time.use24h") ? "HH:mm" : "hh:mmAP")
                    dateText: Qt.formatDate(clock.date, "ddd, d  MMM")

                    onAppActivated: app => {
                        root.close()
                        root.source.launch(app)
                    }
                    onCloseRequested: root.close()
                }
            }
        }

        // The Wallpapers phone: the other half of the turn (WallpaperStage.qml).
        // It comes and goes with the whole phone, the same way this one does.
        WallpaperStage {
            id: wallStage

            active: win.visible
            fit: win.lfit
            centerX: win.pivotXRaw
            centerY: win.pivotYRaw
            pixelRatio: win.pixelRatio

            flip: root.flip
            quickFit: win.fit
            dipDepth: root.flipDip
            wob: root.wob

            // The pull-out's own tilt (the Quick Panel's), not a pop-up.
            pop: 1
            alpha: 1
            tilt: root.tilt
            tiltYaw: root.tiltYaw
            tiltPitch: root.tiltPitch
            tiltRoll: root.tiltRoll

            moving: root.animating || root.flipping || !win.visible
            turning: root.flipping

            initialTarget: root.wallpaperTarget
            screenName: root.targetScreen ? root.targetScreen.name : ""
            clockText: Qt.formatDateTime(clock.date, SettingsService.flag("time.use24h") ? "HH:mm" : "hh:mmAP")
            dateText: Qt.formatDate(clock.date, "ddd, d  MMM")

            onCloseRequested: root.wallpaperDirect ? root.leaveToApps() : root.leaveWallpapers()
        }
    }
}
