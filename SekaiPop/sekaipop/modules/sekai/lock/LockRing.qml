import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.services
import qs.modules.common

// The wallpaper transition for the lockscreen (whichever style is picked in
// Settings -> Desktop -> Wallpaper: sekaiRing, star, diagonalBlocks, sekaiIris,
// sekaiFlash or fade), played over your REAL desktop (bar,
// windows, workspaces) instead of a stand-in wallpaper.
//
// Why a separate window: once a session lock is engaged, the compositor
// draws nothing but the lock surface, so the lock surface can never show
// the desktop. This transparent full-screen overlay (Overlay layer, one
// per screen, made by Lockscreen.qml) plays the ring while the session is
// still unlocked, and the shader leaves the "desktop" part transparent so
// the live desktop shows straight through:
//
//   locking     desktop outside the ring, lockscreen growing inside it.
//               When the ring is done the overlay is 100% lockscreen,
//               the session lock engages, and its surface shows the same
//               picture (the overlay stays mapped underneath, unseen).
//   unlocking   the session lock releases at once and the overlay, which
//               is already up with the same picture, is what you see.
//               The ring then opens a hole in it, and the desktop grows
//               inside the hole until it is all desktop again.
//
// LockState.qml owns the phases; this file only draws them. Shader: the
// style's own `*_lock` pair in shaders/ (sekai_ring_lock, sekai_star_lock,
// sekai_blocks_lock, sekai_iris_lock, sekai_flash_lock,
// fade_lock: each is the wallpaper shader's maths with alpha), fed by the same
// WallpaperService.ring* / star* / blocks* settings as the wallpaper
// switcher, and run with the style's own duration and easing. If a style's
// lock shader failed to load (no .qsb built yet) the ring plays instead
// (LockState.styleFallback).
//
// One caveat of the design: for the length of the lock ring (about a
// second) the session isn't locked yet. It locks the moment the ring ends.
PanelWindow {
    id: win

    required property var modelData
    // The shared LockContext (only handed on to the picture below).
    required property var context

    screen: modelData

    // Mapped from the start of the lock ring until the end of the unlock
    // ring, and not at all the rest of the time.
    visible: LockState.phase !== "idle"

    // Transparent: everything the shader doesn't cover is the live desktop.
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sekaipop-lock-ring"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Only one overlay drives the phase changes, the others just follow
    // (same idea as WallpaperLayer.qml's isPrimary).
    readonly property bool isPrimary: win.modelData === Quickshell.screens[0]

    // 0..1, driven Linear (the shader does its own easing).
    property real progress: 0
    // false while the lock is arriving, true while it is leaving.
    property bool leaving: false
    // Waiting for the picture (its wallpaper) before the lock ring starts.
    property bool armed: false

    // The lockscreen itself, exactly what the session lock will show. It
    // is never drawn directly: it is rendered to a texture and only the
    // ShaderEffect below puts it on screen, through the ring.
    // Sized from the screen, not the window: the window has no size until
    // it is mapped, and the wallpaper should already be decoded at the
    // right size by then (the lock surface then finds it in the cache).
    LockHost {
        id: pic
        width: win.modelData.width
        height: win.modelData.height
        // Only exists from the start of a lock until the end of an unlock (the same time
        // the window is mapped). Idle, it is empty: no lockscreen tree, no wallpaper decode.
        live: LockState.phase !== "idle"
        context: win.context
        uiScale: ShellScale.forScreen(win.modelData)
        screenName: win.modelData ? win.modelData.name : ""
        visible: false
        layer.enabled: true
    }

    ShaderEffect {
        id: ring
        anchors.fill: parent

        // Which style is playing (a name, like WallpaperService.transitionStyle).
        readonly property string styleName: LockState.transitionStyle
        readonly property bool isStar: styleName === "star"

        // Property -> uniform matching is by name (shaders/README.md). Like
        // WallpaperLayer.qml's blend, this declares the union of what every
        // style needs; a property with no matching uniform in the bound
        // shader is harmlessly ignored.
        property var source1: pic
        property real progress: win.progress
        property real aspect: height > 0 ? width / height : 1.0
        property int unlocking: win.leaving ? 1 : 0
        // The theme's colours for the lockscreen (with matugen and a separate
        // lockscreen wallpaper: that wallpaper's), the same as WallpaperLayer.qml.
        readonly property var tc: Theme.transitionColors(ThemeService.lockPalette)
        property color colorWhite: tc.white
        property color colorPink: tc.pink
        property color colorGreen: tc.green
        property color colorCyan: tc.cyan
        Behavior on colorWhite { ColorAnimation { duration: 450 } }
        Behavior on colorPink { ColorAnimation { duration: 450 } }
        Behavior on colorGreen { ColorAnimation { duration: 450 } }
        Behavior on colorCyan { ColorAnimation { duration: 450 } }
        property color accentColor: Theme.accentCyan

        // sekaiRing. `transitionStyle` is the ring's variant number (0 ring,
        // 1 petal, 2 echo, 3 swirl), as in WallpaperLayer.qml.
        property int transitionStyle: WallpaperService.ringVariant
        property real distortion: WallpaperService.ringDistortion
        property real speed: WallpaperService.ringSpeed
        property real ringWidth: WallpaperService.ringWidth

        // Shared by sekaiRing and star (same uniform names in both).
        property real colorIntensity: isStar ? WallpaperService.starColorIntensity
                                             : WallpaperService.ringColorIntensity
        property vector2d center: isStar ? WallpaperService.starCenter
                                         : WallpaperService.ringCenter

        // star
        property real thickness: WallpaperService.starThickness
        property real pointLength: WallpaperService.starPointLength
        property real curvature: WallpaperService.starCurvature
        property real elastic: WallpaperService.starElastic
        property real spin: WallpaperService.starSpin

        // diagonalBlocks
        property vector2d direction: WallpaperService.blocksDirection
        property real bandThickness: WallpaperService.blocksBandThickness
        property real blockSize: WallpaperService.blocksBlockSize
        property real stagger: WallpaperService.blocksStagger

        fragmentShader: Directories.shader(WallpaperService.lockShaderStemFor(styleName) + ".frag.qsb")
        vertexShader: Directories.shader(WallpaperService.lockShaderStemFor(styleName) + ".vert.qsb")

        // A style whose lock shader was never compiled (shaders/compile-shaders.sh
        // after adding the *_lock sources) can't draw: play the ring, which
        // has one, rather than a lock with no transition.
        onStatusChanged: {
            if (status === ShaderEffect.Error && styleName !== "sekaiRing") {
                console.warn("LockRing: the lock shader for \"" + styleName
                    + "\" did not load (run shaders/compile-shaders.sh); playing the ring instead");
                LockState.styleFallback = true;
            }
        }
    }

    NumberAnimation {
        id: anim
        target: win
        property: "progress"
        from: 0.0
        to: 1.0
        duration: LockState.ringMs
        // The ring, star, blocks and iris shaders ease inside themselves
        // and want Linear progress; fade / flash take the
        // wallpaper's own easing (same rule as WallpaperLayer.qml).
        easing.type: WallpaperService.transitionLinearFor(LockState.transitionStyle)
            ? Easing.Linear : WallpaperService.transitionEasing
        onFinished: {
            if (!win.isPrimary)
                return
            if (win.leaving)
                LockState.finishUnlock()
            else
                LockState.engage()
        }
    }

    // Starts the lock ring once the picture is ready, so the ring never
    // runs over a half-loaded wallpaper. The timer is the fallback (e.g.
    // no wallpaper set yet).
    function startLockRing() {
        if (!win.armed)
            return
        win.armed = false
        armTimeout.stop()
        anim.restart()
    }

    Timer {
        id: armTimeout
        // (Was 400. The lockscreen copy is built when the lock starts now, so the first lock
        // after a start may have to decode the wallpaper; this is only the fallback, the
        // ring starts as soon as the picture reports ready.)
        interval: 900
        onTriggered: win.startLockRing()
    }

    Connections {
        target: pic
        function onWallpaperReadyChanged() {
            if (pic.wallpaperReady)
                win.startLockRing()
        }
    }

    function syncPhase() {
        const ph = LockState.phase
        anim.stop()
        armTimeout.stop()
        win.armed = false

        if (ph === "locking" && win.isPrimary)
            console.log("LockRing: playing \"" + LockState.transitionStyle + "\" ("
                + WallpaperService.lockShaderStemFor(LockState.transitionStyle) + ", "
                + LockState.ringMs + " ms)");

        if (ph === "locking") {
            // Order matters: progress first, so no frame ever shows
            // "unlocking" at the end of its range.
            win.progress = 0
            win.leaving = false
            win.armed = true
            armTimeout.start()
            if (pic.wallpaperReady)
                win.startLockRing()
        } else if (ph === "locked") {
            // Rest state: 100% lockscreen. (Looks identical to the start
            // of the unlock ring, so switching needs no frame.)
            win.leaving = false
            win.progress = 1
        } else if (ph === "unlocking") {
            win.progress = 0
            win.leaving = true
            anim.start()
        } else {
            win.leaving = false
            win.progress = 0
        }
    }

    Connections {
        target: LockState
        function onPhaseChanged() {
            win.syncPhase()
        }
    }
}
