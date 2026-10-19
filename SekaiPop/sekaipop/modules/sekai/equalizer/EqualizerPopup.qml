import Quickshell
import QtQuick
import qs.services
import "PadMath.js" as PM
import qs.modules.common
import qs.modules.sekai.bar

// The equalizer: a handheld console. Opened from the turntable's EQ key
// (MediaPopup.qml) or with `qs -c sekaipop ipc call eq open`; the MEDIA key on the
// console's bottom edge goes back to the turntable. The frame, the pop-in, the
// focus grab and Escape come from SekaiPopup.qml; the state and every call to
// EasyEffects are in services/EqualizerService.qml. This file is the console.
//
//   The screen   a rhythm game's chart: ten lanes, one per band (32 Hz .. 16 kHz).
//                Drag a jewel up or down to cut or boost (-12 .. +12 dB). The line
//                through them is the curve. PadScreen.qml.
//   L / R        the shoulder keys: the previous / next preset.
//   The cartridge in the slot on top is the preset in use (its label shows the
//                curve); click it to eject the shelf of presets on the screen.
//   D-pad        left / right pick a band, up / down nudge it by 1 dB (hold to
//                repeat).
//   Dome keys    top AUTO (follow the song's genre), right SAVE, bottom UNDO, left
//                SAVE AS. SAVE and UNDO only work while there is something
//                heard but not saved (the pink LED is lit).
//   The wheel    on the right edge: the preamp. Drag it, or roll the mouse wheel.
//   The gear     on the screen's bar: which EasyEffects preset the equalizer lives
//                in, and the Last.fm key AUTO needs.
// Closing it (a click elsewhere, Escape) without SAVE puts the sound back to the
// saved preset.
//
// The body is flat 2D with the 2.5D look painted in: everything stands off the
// shell by its own height along ONE FIXED depth vector (kx, ky), and each part
// (shell, keys, wheel, cartridge, chart) is a few cached canvases. The vector used
// to follow the pointer, which re-laid-out and repainted most of the console on
// every move; now nothing in it moves unless you press or drag something.
SekaiPopup {
    id: root

    bare: true
    centered: true                          // opens in the middle of the monitor
    property var source: null               // MediaSource: whether a song is playing
    signal turntableRequested()
    property bool motion: true

    readonly property var eq: EqualizerService
    readonly property bool playing: root.source !== null && root.source.playing

    // ---- the design (920 x 400 body); `u` is how big one pixel is here ------------
    readonly property real u: 0.86
    function d(v) {
        return v * root.u
    }
    readonly property real bodyW: 920
    readonly property real bodyH: 400
    readonly property real marginT: 92       // the cartridge and the shoulder keys
    readonly property real marginR: 46       // the wall and the wheel
    readonly property real marginB: 40

    contentWidth: root.d(root.bodyW + root.marginR) - 2 * Theme.borderWidth
    contentHeight: root.d(root.marginT + root.bodyH + root.marginB) - 2 * Theme.borderWidth - Theme.shadowOffset

    // How many times denser than the screen every canvas is painted. They are
    // painted once (or rarely), then the scene graph shrinks them to size with
    // linear filtering, which smooths every edge (2 = a clean 2x2 average).
    // Lower it (1.5) if the chart's notes ever cost too much, 1 turns it off.
    readonly property real ssaa: 2

    // The tilt: the console turns a few degrees toward the pointer, like a card
    // pressed at the spot it is hovered. It is ONE transform on cached textures, so
    // it costs a matrix per frame while the pointer moves and nothing at rest (no
    // canvas is repainted by it). It follows the pointer only while you hover and
    // are not dragging a jewel (the controls must not move under your hand), and
    // it lies flat again when the pointer leaves or the card closes.
    property bool tiltEnabled: true
    property real tiltMax: 4                    // degrees, at the very edge
    property real aimX: 0                       // -1 .. 1, where the pointer is
    property real aimY: 0
    readonly property bool aiming: root.tiltEnabled && root.motion && root.open
    property real tiltX: root.aiming ? root.aimX * root.tiltMax : 0
    property real tiltY: root.aiming ? root.aimY * root.tiltMax : 0
    Behavior on tiltX {
        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
    }
    Behavior on tiltY {
        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
    }

    // The depth vector: where one pixel of height goes. Fixed.
    readonly property real kx: 0.30
    readonly property real ky: 0.34

    function stepPreset(delta) {
        const list = root.eq.presetNames.concat(root.eq.customNames)
        if (list.length === 0)
            return
        const at = list.indexOf(root.eq.presetName)
        const next = at < 0 ? (delta > 0 ? 0 : list.length - 1) : (at + delta + list.length) % list.length
        root.eq.applyAny(list[next])
    }

    function dpad(dir) {
        if (dir === 2)
            screen.sel = Math.min(9, screen.sel + 1)
        else if (dir === 4)
            screen.sel = Math.max(0, screen.sel - 1)
        else if (dir === 1)
            root.eq.setBand(screen.sel, (root.eq.bands[screen.sel] || 0) + 1)
        else if (dir === 3)
            root.eq.setBand(screen.sel, (root.eq.bands[screen.sel] || 0) - 1)
    }

    onKeyed: event => {
        if (event.key === Qt.Key_Left) { root.dpad(4); event.accepted = true }
        else if (event.key === Qt.Key_Right) { root.dpad(2); event.accepted = true }
        else if (event.key === Qt.Key_Up) { root.dpad(1); event.accepted = true }
        else if (event.key === Qt.Key_Down) { root.dpad(3); event.accepted = true }
    }

    onOpenChanged: {
        if (open) {
            screen.page = "chart"
            screen.dragIdx = -1
            screen.hoverIdx = -1
            root.eq.refresh()
        }
    }

    bareContent: Item {
        id: stage

        // Measured on the flat stage (not on the tilted card), so the tilt can not
        // feed back into where the pointer seems to be. Rounded to 5 %, so a tiny
        // move changes nothing.
        HoverHandler {
            id: hov
            enabled: root.aiming
            onPointChanged: {
                if (hov.hovered && stage.width > 0 && screen.dragIdx < 0) {
                    root.aimX = Math.round((point.position.x / stage.width * 2 - 1) * 20) / 20
                    root.aimY = Math.round((point.position.y / stage.height * 2 - 1) * 20) / 20
                }
            }
            onHoveredChanged: {
                if (!hov.hovered) {
                    root.aimX = 0
                    root.aimY = 0
                }
            }
        }

        Item {
            id: tilt
            anchors.fill: parent
            transform: Matrix4x4 {
                matrix: PM.tilt(tilt.width, tilt.height, root.tiltX, root.tiltY, 1500)
            }

        // The body's own origin: below the room kept for the cartridge.
        Item {
            id: pad
            x: 0
            y: root.d(root.marginT)

            readonly property real rs: Math.max(1, root.uiScale) * root.ssaa

            // ---- behind the shell: the cartridge and the shoulder keys ----------
            PadCartridge {
                x: root.d(380)
                y: root.d(-70)
                u: root.u
                kx: root.kx
                ky: root.ky
                renderScale: pad.rs
                name: root.eq.presetName
                gains: root.eq.bands
                ejected: screen.page === "presets"
                onClicked: screen.page = screen.page === "presets" ? "chart" : "presets"
            }
            PadShoulder {
                x: root.d(64)
                y: root.d(-26)
                u: root.u
                kx: root.kx
                ky: root.ky
                renderScale: pad.rs
                label: "\u25C0 PRESET"
                onClicked: root.stepPreset(-1)
            }
            PadShoulder {
                x: root.d(920 - 64 - 214)
                y: root.d(-26)
                u: root.u
                kx: root.kx
                ky: root.ky
                renderScale: pad.rs
                label: "PRESET \u25B6"
                onClicked: root.stepPreset(1)
            }

            // ---- the shell ------------------------------------------------------------
            PadBody {
                u: root.u
                kx: root.kx
                ky: root.ky
                renderScale: pad.rs
            }

            // the volume wheel, halfway down the wall
            PadWheel {
                x: root.d(916) + root.d(18 * root.kx)
                y: root.d(250) + root.d(18 * root.ky)
                u: root.u
                kx: root.kx
                ky: root.ky
                renderScale: pad.rs
                value: root.eq.preamp
                onMoved: v => root.eq.setPreamp(v)
            }

            // ---- the screen ----------------------------------------------------------
            // cavity
            Rectangle {
                x: root.d(202)
                y: root.d(30)
                width: root.d(516)
                height: root.d(316)
                radius: root.d(32)
                antialiasing: true
                border.width: Math.max(1, root.u)
                border.color: PadPalette.cavityEdge
                gradient: Gradient {
                    GradientStop { position: 0.0; color: PadPalette.cavityTop }
                    GradientStop { position: 1.0; color: PadPalette.cavityBottom }
                }
            }
            // the bezel stands a little proud: its shadow, then its face
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    x: root.d(208 + 3 + index * 2) - root.d(7 * root.kx)
                    y: root.d(36 + 8 + index * 3) - root.d(7 * root.ky)
                    width: root.d(504 + index * 2)
                    height: root.d(304 + index * 2)
                    radius: root.d(28 + index)
                    antialiasing: true
                    color: PadPalette.alpha(PadPalette.wallNear, 0.10)
                }
            }
            Rectangle {
                id: bezel
                x: root.d(208) - root.d(7 * root.kx)
                y: root.d(36) - root.d(7 * root.ky)
                width: root.d(504)
                height: root.d(304)
                radius: root.d(28)
                antialiasing: true
                border.width: Math.max(1, root.u)
                border.color: Qt.rgba(1, 1, 1, 0.3)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: PadPalette.bezelTop }
                    GradientStop { position: 1.0; color: PadPalette.bezelBottom }
                }
            }
            Rectangle {
                x: bezel.x + root.d(14)
                y: bezel.y + root.d(14)
                width: root.d(476)
                height: root.d(276)
                radius: root.d(14)
                antialiasing: true
                color: "#000000"
            }
            PadScreen {
                id: screen
                x: bezel.x + root.d(22)
                y: bezel.y + root.d(18)
                u: root.u
                renderScale: pad.rs
                animate: root.open && root.playing && root.motion
                onPrevPreset: root.stepPreset(-1)
                onNextPreset: root.stepPreset(1)
            }
            // the glass
            Rectangle {
                x: screen.x
                y: screen.y
                width: screen.width
                height: screen.height
                radius: root.d(12)
                antialiasing: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#2effffff" }
                    GradientStop { position: 0.38; color: "#0affffff" }
                    GradientStop { position: 0.6; color: "#00ffffff" }
                }
                // a click goes through to the screen
                enabled: false
            }

            // ---- the MEDIA key: back to the turntable ----------------------------------
            Item {
                id: mediaKey
                x: root.d(46)
                y: root.d(334)
                width: root.d(80)
                height: root.d(30)
                readonly property real sink: mediaArea.pressed ? 3 : 0

                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        x: (index + 1) * 1.2 * root.kx * root.u
                        y: (index + 1) * 1.2 * root.ky * root.u + mediaKey.sink * root.u * 0.6
                        width: mediaKey.width
                        height: mediaKey.height
                        radius: height / 2
                        antialiasing: true
                        color: PM.mix(PadPalette.keyWall, PadPalette.keyBottom, index / 2)
                    }
                }
                Rectangle {
                    y: mediaKey.sink * root.u
                    width: mediaKey.width
                    height: mediaKey.height
                    radius: height / 2
                    antialiasing: true
                    border.width: Math.max(1, root.u)
                    border.color: PadPalette.alpha(PadPalette.stageBottom, 0.5)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: mediaArea.containsMouse ? PadPalette.keyHover : PadPalette.keyTop }
                        GradientStop { position: 1.0; color: PadPalette.keyBottom }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "\u25C9  MEDIA"
                        color: PadPalette.keyText
                        font.family: Theme.fontFamily
                        font.pixelSize: root.d(10)
                        font.weight: Font.Bold
                        font.letterSpacing: root.d(1.2)
                    }
                }
                MouseArea {
                    id: mediaArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.turntableRequested()
                }
            }

            // ---- D-pad ---------------------------------------------------------------------
            PadDpad {
                x: root.d(101 - 110)
                y: root.d(184 - 110)
                u: root.u
                kx: root.kx
                ky: root.ky
                renderScale: pad.rs
                onStep: dir => root.dpad(dir)
            }
            Text {
                x: root.d(101 - 88)
                y: root.d(184 + 64 + 26)
                width: root.d(176)
                horizontalAlignment: Text.AlignHCenter
                text: "\u25C0 \u25B6   SELECT BAND\n\u25B2 \u25BC   \u00B11 dB"
                lineHeight: 1.1
                color: PadPalette.label
                opacity: PadPalette.labelOpacity
                style: Text.Raised
                styleColor: PadPalette.labelEmboss
                font.family: Theme.fontFamily
                font.pixelSize: root.d(9)
                font.weight: Font.Bold
                font.letterSpacing: root.d(1.2)
            }

            // ---- dome keys --------------------------------------------------------------------
            PadDome {
                x: root.d(819 - 28)
                y: root.d(122 - 28)
                u: root.u
                kx: root.kx
                ky: root.ky
                renderScale: pad.rs
                capColor: PadPalette.domeAuto
                wallColor: PadPalette.domeAutoWall
                glyph: "\u2726"
                lit: root.eq.autoEnabled
                onClicked: {
                    if (!root.eq.autoEnabled && root.eq.lastfmKey === "")
                        screen.page = "setup"
                    root.eq.toggleAuto()
                }
            }
            PadDome {
                x: root.d(877 - 28)
                y: root.d(184 - 28)
                u: root.u
                kx: root.kx
                ky: root.ky
                renderScale: pad.rs
                capColor: PadPalette.domeSave
                wallColor: PadPalette.domeSaveWall
                glyph: "\u266A"
                lit: root.eq.pending
                enabledKey: root.eq.pending
                onClicked: root.eq.save()
            }
            PadDome {
                x: root.d(819 - 28)
                y: root.d(246 - 28)
                u: root.u
                kx: root.kx
                ky: root.ky
                renderScale: pad.rs
                capColor: PadPalette.domeUndo
                wallColor: PadPalette.domeUndoWall
                glyph: "\u21BA"
                enabledKey: root.eq.pending
                onClicked: root.eq.revert()
            }
            PadDome {
                x: root.d(761 - 28)
                y: root.d(184 - 28)
                u: root.u
                kx: root.kx
                ky: root.ky
                renderScale: pad.rs
                capColor: PadPalette.domeSaveAs
                wallColor: PadPalette.domeSaveAsWall
                glyph: "\u2606"
                onClicked: screen.openSaveAs()
            }
            Text {
                x: root.d(819 - 88)
                y: root.d(246 + 28 + 18)
                width: root.d(176)
                horizontalAlignment: Text.AlignHCenter
                text: "\u2726 AUTO    \u266A SAVE\n\u21BA UNDO    \u2606 SAVE AS"
                lineHeight: 1.1
                color: PadPalette.label
                opacity: PadPalette.labelOpacity
                style: Text.Raised
                styleColor: PadPalette.labelEmboss
                font.family: Theme.fontFamily
                font.pixelSize: root.d(9)
                font.weight: Font.Bold
                font.letterSpacing: root.d(1.2)
            }

            // ---- the LED, and the name ------------------------------------------------------------
            Item {
                x: root.d(50)
                y: root.d(50)
                Repeater {
                    model: root.eq.pending ? 4 : 0
                    Rectangle {
                        required property int index
                        readonly property real r: root.d(6 + 4 + index * 4)
                        x: -r
                        y: -r
                        width: 2 * r
                        height: 2 * r
                        radius: r
                        antialiasing: true
                        color: PadPalette.alpha(PadPalette.ledOn, 0.14)
                    }
                }
                Rectangle {
                    x: -root.d(6)
                    y: -root.d(6)
                    width: root.d(12)
                    height: root.d(12)
                    radius: width / 2
                    antialiasing: true
                    color: root.eq.pending ? PadPalette.ledOn : PadPalette.ledOff
                    border.width: 1
                    border.color: PadPalette.alpha(Qt.darker(PadPalette.ledOn, 2.2), 0.4)
                }
            }
            Text {
                x: root.d(460 - 90)
                y: root.d(362)
                width: root.d(180)
                horizontalAlignment: Text.AlignHCenter
                leftPadding: font.letterSpacing
                text: "SEKAI\u00B7EQ"
                color: PadPalette.label
                opacity: PadPalette.titleOpacity
                style: Text.Raised
                styleColor: PadPalette.labelEmboss
                font.family: Theme.fontFamily
                font.pixelSize: root.d(10)
                font.weight: Font.Bold
                font.letterSpacing: root.d(3.2)
            }
        }
        }
    }
}
