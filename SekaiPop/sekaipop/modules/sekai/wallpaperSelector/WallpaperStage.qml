import QtQuick
import qs.services
import "../../common/functions/FlipMath.js" as FM
import qs.modules.sekai.phone

// The Wallpapers phone: a landscape PhoneBody with WallpaperFace.qml on its
// screen, and FLAT: the 2D counterpart of the Settings phone (SettingsStage.qml).
// It is the launcher phone's body turned a quarter turn, and it lives in the
// launcher phone's window (LauncherPhone.qml), where it is one half of the turn
// that changes the one phone into the other. Same turn as the Quick Panel into
// the Settings (FlipMath.js), so read that for what `flip` means:
//
//   flip = 0   it is the launcher phone: rolled a quarter turn so it stands up
//              straight, tipped the way the launcher phone is, fully see-through
//   flip = 1   it is the Wallpapers phone: lying down, facing straight on, solid
//
// This file only knows how to draw itself at any point of that turn;
// LauncherPhone.qml owns the timing, the window and everything that talks to the
// system. Pure UI.
Item {
    id: root

    // ===== what it shows =====
    property string screenName: ""
    property string clockText: "00:00AM"
    property string dateText: "Sun, 20  Sep"
    // The screen is only built while the phone is up (it reads the wallpaper
    // folder), and goes away with it.
    property bool active: false
    // Which side the gallery starts on: "desktop" or "lock" (the Quick Panel's
    // lockscreen wallpaper action opens it on the lockscreen side).
    property string initialTarget: "desktop"

    // ===== the phone itself =====
    property real faceWidth: 1440
    property real faceHeight: 760
    property real cornerRadius: 92
    property real thickness: 135

    // Flat: 2D. (The launcher phone's own pose is what the turn starts from.)
    readonly property real yaw: 0
    readonly property real pitch: 0
    readonly property real roll: 0
    property real perspective: 6000

    // How it arrives / leaves with the whole phone (same numbers as the launcher
    // phone's entrance).
    property real popFrom: 0.55
    property real tiltYaw: -22
    property real tiltPitch: 14
    property real tiltRoll: 7

    // ===== where it is and how big =====
    property real fit: 1
    property real centerX: 0
    property real centerY: 0
    property real pixelRatio: 1

    // The turn. `quickFit`, `quickYaw` and `quickPitch` are the launcher
    // phone's own scale and pose, which the turn starts from.
    property real flip: 1
    property real quickFit: 1
    property real quickYaw: 33
    property real quickPitch: 18
    property real dipDepth: 0.12

    // The entrance with the whole phone: pop 0..1(+overshoot), alpha 0..1, tilt 1..0.
    property real pop: 1
    property real alpha: 1
    property real tilt: 0
    // The roll the turn rings out with when it lands, in degrees.
    property real wob: 0

    property bool moving: false
    property bool turning: false

    // ===== what the others read =====
    readonly property alias phone: phone
    readonly property var face: faceLoader.item

    readonly property real shownOpacity: alpha * FM.settingsAlpha(flip)
    readonly property real turnSize: FM.quickScale(flip, quickFit, fit, dipDepth)
                                     / (FM.SIZE_RATIO * Math.max(0.0001, fit))

    signal closeRequested()

    // Gives the screen the keyboard (Escape, arrows, Enter).
    function focusKeys() {
        if (root.face)
            root.face.forceActiveFocus()
    }

    // Switches the gallery to the Desktop / Lockscreen side (once it is built;
    // before that `initialTarget` is what it starts on).
    function setTarget(which) {
        if (root.face)
            root.face.target = which === "lock" ? "lock" : "desktop"
    }

    // ===== sharpness =====
    readonly property bool settled: flip >= 1 && pop >= 1 && tilt === 0 && wob === 0 && !turning
    readonly property real gridPx: Math.max(1, pixelRatio)
    readonly property real sceneX: centerX - phone.screenCenterX * fit - (phone.layerSwing.left + 8) * fit
    readonly property real sceneY: centerY - phone.screenCenterY * fit - (phone.layerSwing.top + 8) * fit

    // Landed and still: the screen goes straight to the window as a whole number
    // of texels per device pixel (PhoneBody `faceDirect`), and it is the SCREEN's
    // top-left, not the big picture's, that is put on a whole device pixel. Same
    // thing as the Overview phone (LauncherPhone.qml `flatNow`). `pop === 1`
    // keeps it off while the entrance is still overshooting past full size.
    readonly property bool direct: settled && !moving && pop === 1
    readonly property real faceLeftDev: centerX * pixelRatio - phone.directW / 2
    readonly property real faceTopDev: centerY * pixelRatio - phone.directH / 2

    readonly property real snapX: direct ? (Math.round(faceLeftDev) - faceLeftDev) / pixelRatio
                                         : (settled ? Math.round(sceneX * gridPx) / gridPx - sceneX : 0)
    readonly property real snapY: direct ? (Math.round(faceTopDev) - faceTopDev) / pixelRatio
                                         : (settled ? Math.round(sceneY * gridPx) / gridPx - sceneY : 0)

    // The point everything grows from and turns about: the middle of the screen.
    Item {
        id: pivot

        x: root.centerX + root.snapX
        y: root.centerY + root.snapY
        scale: (root.popFrom + (1 - root.popFrom) * root.pop) * root.turnSize
        opacity: root.shownOpacity
        visible: opacity > 0.001

        PhoneBody {
            id: phone

            landscape: true
            faceWidth: root.faceWidth
            faceHeight: root.faceHeight
            cornerRadius: root.cornerRadius
            thickness: root.thickness
            perspective: root.perspective
            yaw: root.yaw
            pitch: root.pitch
            roll: root.roll

            // Not up: its layer buffers are given back after a while (PhoneBody `warm`).
            windowShown: root.active

            x: -phone.screenCenterX * root.fit
            y: -phone.screenCenterY * root.fit
            transformOrigin: Item.TopLeft
            scale: root.fit

            moving: root.moving
            turnRoll: root.turning ? 90 : 0
            // Once it has landed it faces straight on and stays there: no side wall.
            flat: root.settled
            faceDirect: root.direct

            // The turn out of the launcher phone: rolled a quarter turn the
            // other way and tipped like the launcher phone while flip is 0,
            // easing into its own (flat) pose as it comes round.
            rollOffset: root.tilt * root.tiltRoll + FM.settingsRoll(root.flip) + root.wob
            pitchOffset: root.tilt * root.tiltPitch + (root.quickPitch - root.pitch) * (1 - root.flip) + root.wob * 0.5
            yawOffset: root.tilt * root.tiltYaw + (root.quickYaw - root.yaw) * (1 - root.flip)

            swingRoll: root.tiltRoll
            swingPitch: root.tiltPitch
            swingYaw: root.tiltYaw

            renderScale: root.fit * root.pixelRatio

            // Built a beat after the phone comes up, a little at a time, so it
            // is there by the time Wallpapers is tapped.
            Loader {
                id: faceLoader

                width: root.faceWidth
                height: root.faceHeight
                active: root.active
                asynchronous: true

                onLoaded: root.setTarget(root.initialTarget)

                sourceComponent: Component {
                    WallpaperFace {
                        screenName: root.screenName
                        clockText: root.clockText
                        dateText: root.dateText
                        screenInset: phone.screenInset
                        cornerRadius: root.cornerRadius
                        renderScale: phone.renderScale

                        onCloseRequested: root.closeRequested()
                    }
                }
            }
        }
    }
}
