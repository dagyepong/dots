import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.editMode

// The desktop clock widget: it sits on the desktop, under your windows, over
// the wallpaper, with the same drag and lock as the To-Do card.
//
//   Moving it: in Edit Desktop (right-click the desktop) it is always
//   draggable, by the shield in EditChrome.qml; a click on it there selects it
//   for editing (then the double-click and the style button below work, and
//   a right-click removes it). On the normal desktop it can
//   be dragged only while "Lock all" (a tile on the Edit Desktop shelf,
//   locked by default) is off. The lock is ignored while editing and applies
//   again when you press Done. There is no per-card lock.
//
//   double-click  switch between 12h and 24h
//   edit mode     select the clock in Edit Desktop (left click it): a small button
//                 pops up at the top-right corner; click it to go to the next
//                 design (it names the design for a moment). There is no such
//                 button on the normal desktop.
//
// Four designs (a first run starts on 3 STACK, on the right edge), all built
// from the same parts (keys, diamonds, the Pill's
// outline + ring + hard shadow):
//
//   0 KEYS     the card: a date sticker, four keycaps in a shallow V (hours
//              navy, minutes mint-to-cyan), a beat of two diamonds between
//              them, a second lane with a hopping playhead, the week.
//   1 TOWER    the same card stood on end: hours over minutes, a vertical
//              second lane on the left, the week as a column on the right.
//   2 STICKER  no card: only the time, as big sticker numerals (navy outline,
//              white ring, mint hours / cyan minutes, hard shadow) straight
//              on the wallpaper, with the two beat diamonds between.
//   3 STACK    the sticker time on end: hours over minutes.
//
// In every design a digit pops when it changes, the diamonds take turns once a
// second, and nothing animates endlessly (the card is idle between ticks). The
// two knobs for the attitude are `tilt` and `stagger` on the card below; set
// both to 0 for perfectly level rows.
//
// State (position, shown, 12h / 24h, design) lives in
// services/ClockService.qml and is remembered across restarts.
//
// How the moving works: exactly like TodoWidget.qml. ONE full-screen,
// transparent window on WlrLayer.Bottom, with the card as an Item inside it.
// Dragging just moves that Item, so it stays smooth, and the window's input
// `mask` is only the card (and the hover button), so every click anywhere else
// passes straight through to whatever is underneath. The clock never takes
// keyboard focus.
//
// Bind a key / call it from a script:
//   qs -c sekaipop ipc call clock toggle         (show / hide)
//   qs -c sekaipop ipc call clock lock           (or: unlock)
//   qs -c sekaipop ipc call clock toggleFormat   (12h <-> 24h)
//   qs -c sekaipop ipc call clock nextDesign     (Keys -> Tower -> Sticker -> Stack)
//   qs -c sekaipop ipc call clock setDesign 2    (0 Keys, 1 Tower, 2 Sticker, 3 Stack)
//   qs -c sekaipop ipc call clock resetPosition  (if it ever ends up off-screen)

PanelWindow {
    id: win

    function resetPosition(): void {
        ClockService.posX = -1;
        ClockService.posY = -1;
        win.place();
        ClockService.setPosition(card.x, card.y, win.screen ? win.screen.name : "", win.uiScale);
    }
    // Which monitor it lives on, by name (`hyprctl monitors`), e.g. "DP-1".
    // Empty = the monitor the card was last dropped on (remembered in
    // ClockService), or the first screen if it has never been moved.
    property string monitor: ""

    readonly property string wantedScreen: win.monitor !== "" ? win.monitor : ClockService.screenName
    screen: Quickshell.screens.find(s => s.name === win.wantedScreen) ?? Quickshell.screens[0]

    // This monitor's scale (scale.json / services/ShellScale.qml). The card is
    // drawn in design pixels inside a ScaleHost, so `roomW` x `roomH` is the
    // screen as the card sees it (real size / scale); positions are kept in
    // that same design space.
    readonly property real uiScale: ShellScale.forScreen(win.screen)
    readonly property real fullW: win.screen ? win.screen.width : 0
    readonly property real fullH: win.screen ? win.screen.height : 0
    readonly property real roomW: win.fullW / win.uiScale
    readonly property real roomH: win.fullH / win.uiScale

    // ===== a small window while nothing needs the whole screen =====
    // A full-screen layer makes the compositor redraw (and re-blend) the whole screen on every
    // frame the card draws, even when the card is a small corner of it. So at rest the window is
    // just the card plus some room around it for the pop-in overshoot, the shadow and the name
    // tag, and only Edit Desktop (and dragging on an unlocked desktop) gets the full screen back.
    // Everything inside still lives in screen coordinates: `shifter` slides the whole stage by the
    // window's own position, so the card is drawn where it always was. (Same as the visualizer.)
    readonly property bool compact: !EditMode.active && !win.gliding && EditMode.screenName === ""
        && EditMode.compactWindows && !EditMode.desktopDragAllowed && win.fullW > 0 && win.placed
    readonly property real boxPad: Math.ceil((0.16 * Math.max(card.width, card.height) + 24) * win.uiScale)
    readonly property real boxX: win.compact ? Math.max(0, Math.floor(card.x * win.uiScale - win.boxPad)) : 0
    readonly property real boxY: win.compact ? Math.max(0, Math.floor(card.y * win.uiScale - win.boxPad)) : 0
    readonly property real boxW: Math.max(1, Math.min(win.fullW,
        Math.ceil((card.x + card.width) * win.uiScale + win.boxPad)) - win.boxX)
    readonly property real boxH: Math.max(1, Math.min(win.fullH,
        Math.ceil((card.y + card.height) * win.uiScale + win.boxPad)) - win.boxY)

    // On / off: the card pops in with a little overshoot and is swallowed
    // (straight shrink, nothing before it) on the way out, the same language
    // as Edit Desktop, instead of fading. The window stays up until the
    // swallow has finished.
    //
    // Two fixed animations, started from onWantChanged. (A Behavior whose
    // easing is picked by a binding on the same flag can start with the
    // PREVIOUS direction's easing, which is what made the way out misbehave.)
    // Desktop Focus Mode (FocusGate.qml, services/FocusService.qml): `gate.show` is
    // false while an application is on this monitor's workspace, so `want` goes
    // false and the usual swallow + unmap below does the hiding. `switchedOn` is
    // the user's own switch; `working` is whether the card's clock / fetches may
    // run (they stop while it is hidden, unless Settings keeps them going).
    FocusGate {
        id: gate
        widgetId: "clock"
        screenName: win.screen ? win.screen.name : ""
    }

    readonly property bool switchedOn: ClockService.shown && ClockService.loaded
    readonly property bool want: win.switchedOn && gate.show
    property real reveal: 0

    // Off while the saved state is read back, so a reload doesn't replay the pop.
    property bool armed: false

    // Stays false until the card has been put on its saved spot, and keeps it
    // drawn at size 0 until then. After a reload the window maps before the
    // compositor has told it its real size, and a card placed (or clamped) in
    // that window sits at the top-left corner for a moment before it jumps to
    // where it was saved. place() waits for a believable window instead.
    property bool placed: false

    onWantChanged: {
        if (!win.armed) {
            popIn.stop()
            swallow.stop()
            win.reveal = win.want ? 1 : 0
        } else if (win.want) {
            swallow.stop()
            popIn.restart()
        } else {
            popIn.stop()
            swallow.restart()
        }
    }

    NumberAnimation {
        id: popIn
        target: win
        property: "reveal"
        to: 1
        duration: 460
        easing.type: Easing.OutBack
        easing.overshoot: 1.9
    }

    NumberAnimation {
        id: swallow
        target: win
        property: "reveal"
        to: 0
        duration: 300
        easing.type: Easing.InCubic
    }

    Timer {
        interval: 800
        running: ClockService.loaded
        onTriggered: win.armed = true
    }

    // `live`: the card is on, or still being swallowed.
    readonly property bool live: win.want || win.reveal > 0.001

    // On screen, or switched on and not suspended by Focus Mode. Rendering follows `live`, the clock follows this.
    readonly property bool working: win.live || (win.switchedOn && !gate.suspended)

    // Not mapped while the widget is off: a full-screen transparent layer that is only
    // sitting there still costs the compositor a blend on every frame.
    visible: ClockService.loaded && (win.live || EditMode.active)

    // Always BELOW the dock: the widgets rest on Background (mapped after the wallpaper,
    // so over it) and the dock is on Bottom or Top, so the dock is never behind a widget.
    // Up a layer while this widget is edited or moved (EditChrome.raised), so the one
    // edited last is in front of the other widgets (see EditChrome.qml); Bottom is as far
    // up as it goes, because the dock is on Top while editing (see Dock.qml).
    WlrLayershell.layer: (chrome.raised || WallpaperService.restacking) ? WlrLayer.Bottom : WlrLayer.Background
    WlrLayershell.namespace: "sekaipop-clock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        left: true
        right: !win.compact
        bottom: !win.compact
    }

    margins {
        left: win.boxX
        top: win.boxY
    }

    implicitWidth: win.boxW
    implicitHeight: win.boxH

    // Only the card takes clicks; the rest of the screen falls through.
    // (In real window pixels, so it is the card's design rectangle times the
    // scale.)
    // The hover button sits half outside the card's corner, so it gets its
    // own rectangle in the mask (and only while it is showing).
    mask: Region {
        item: cardMask

        Region { item: btnMask }
    }

    // Edit Desktop widens the card's rectangle a little (its outline and tag sit
    // half outside it), and everything here follows the shrink: `stage` is the
    // transform the content is drawn with (EditStage.qml; scale 1 and no
    // offset when not editing).
    Item {
        id: cardMask
        readonly property real m: stage.editing ? 38 : 0
        readonly property real k: win.uiScale * stage.scale
        readonly property real x1: shifter.x + stage.x + (card.x + card.width + m) * k
        readonly property real y1: shifter.y + stage.y + (card.y + card.height + m) * k
        x: !win.live ? 0 : Math.max(0, Math.round(shifter.x + stage.x + (card.x - m) * k))
        y: !win.live ? 0 : Math.max(0, Math.round(shifter.y + stage.y + (card.y - m) * k))
        width: !win.live ? 1 : Math.max(0, Math.ceil(x1) - x)
        height: !win.live ? 1 : Math.max(0, Math.ceil(y1) - y)
    }

    Item {
        id: btnMask
        readonly property real k: win.uiScale * stage.scale
        x: Math.max(0, Math.round(shifter.x + stage.x + (card.x + btn.x) * k))
        y: Math.max(0, Math.round(shifter.y + stage.y + (card.y + btn.y) * k))
        width: card.btnShown && win.live ? Math.ceil(btn.width * k) : 0
        height: card.btnShown && win.live ? Math.ceil(btn.height * k) : 0
    }

    // ===== the time =====
    SystemClock {
        id: clock
        enabled: win.working || EditMode.active
        precision: SystemClock.Seconds
    }

    readonly property date now: clock.date
    readonly property int hours24: win.now.getHours()
    readonly property int mins: win.now.getMinutes()
    readonly property int secs: win.now.getSeconds()
    readonly property bool pm: win.hours24 >= 12
    readonly property int hoursShown: ClockService.use24h
        ? win.hours24
        : (win.hours24 % 12 === 0 ? 12 : win.hours24 % 12)

    function two(n) {
        return (n < 10 ? "0" : "") + n
    }

    readonly property string hh: win.two(win.hoursShown)
    readonly property string mm: win.two(win.mins)
    readonly property string ss: win.two(win.secs)

    // ===== placement =====
    function place(force) {
        if (win.roomW <= 0 || win.roomH <= 0)
            return
        // Not before the saved spot has been read, and not while the window is
        // still smaller than the card (the clamp below would put it at 0, 0).
        if (!force && (!ClockService.loaded || win.roomW < card.width || win.roomH < card.height))
            return
        let x = ClockService.posX
        let y = ClockService.posY
        if (x < 0 || y < 0) {
            x = win.roomW - card.width - 40
            y = (win.roomH - card.height) / 2
        } else if (ClockService.posScale > 0 && win.uiScale > 0) {
            // Saved at another shell scale: same spot on the screen, not the
            // same design pixels (the card keeps its top-left corner).
            const k = ClockService.posScale / win.uiScale
            x *= k
            y *= k
        }
        card.x = Math.max(0, Math.min(x, win.roomW - card.width))
        card.y = Math.max(0, Math.min(y, win.roomH - card.height))
        win.placed = true
    }

    // After a reload the window, the monitor list and scale.json all settle
    // over a few frames; place again once they have, so the card always ends
    // on its saved spot (never while it is being dragged).
    Timer {
        id: settle
        interval: 300
        onTriggered: {
            // A position saved before the scale was kept with it: it was in design
            // pixels of the scale in use now (nothing has changed it since), so
            // keep that from here on.
            if (ClockService.loaded && ClockService.posX >= 0 && ClockService.posScale <= 0 && !dragArea.drag.active) {
                ClockService.posScale = win.uiScale
                ClockService.persist()
            }
            if (!chrome.dragging && !dragArea.drag.active)
                win.place(!win.placed && ClockService.loaded)
        }
    }

    // The window's size is `implicitWidth` / `implicitHeight` (boxW / boxH), and those read
    // card.x / card.y, which place() sets. Calling place() from inside the size's own change
    // notification therefore changed card.x while implicitWidth was still being worked out,
    // and Qt logged "Binding loop detected for property implicitWidth" at start-up and at
    // every Edit Desktop start / end. place() now runs one turn of the event loop later
    // (Qt.callLater, before the next frame, and several calls become one).
    // To undo: `onWidthChanged: { win.place(); settle.restart() }` (same for the height).
    onWidthChanged: { Qt.callLater(win.place); settle.restart() }
    onHeightChanged: { Qt.callLater(win.place); settle.restart() }
    onUiScaleChanged: { win.place(); settle.restart() }
    onScreenChanged: { win.place(); settle.restart() }
    onVisibleChanged: settle.restart()
    Component.onCompleted: {
        win.reveal = win.want ? 1 : 0
        win.place()
    }

    Connections {
        target: ClockService
        function onLoadedChanged() {
            win.place()
            settle.restart()
        }
        // A desktop preset hands the service another saved spot while the card
        // is on screen. Without this the card only looked at the service when
        // it loaded or when the window / scale / monitor changed, so wearing a
        // preset moved nothing. The spot arrives as several properties one
        // after the other (x, y, scale), so wait a beat and place once.
        function onPosXChanged() { follow.restart() }
        function onPosYChanged() { follow.restart() }
        function onPosScaleChanged() { follow.restart() }
    }

    // A preset hands the card another spot: it glides there instead of jumping
    // (not while it is being dragged, and not when it is already where it
    // should be, which is what dropping it by hand and the scale check come to).
    // `gliding` first, so a small window grows to the whole screen (see
    // `compact`), then `glideOn` switches the card's Behaviors on.
    property bool gliding: false
    property bool glideOn: false

    Timer {
        id: follow
        interval: 16
        onTriggered: {
            if (chrome.dragging || dragArea.drag.active)
                return
            const ox = card.x
            const oy = card.y
            win.place()
            if (Math.abs(card.x - ox) + Math.abs(card.y - oy) < 2)
                return
            card.x = ox
            card.y = oy
            win.gliding = true
            glideStart.restart()
        }
    }

    Timer {
        id: glideStart
        interval: 80
        onTriggered: {
            win.glideOn = true
            win.place()
            glideEnd.restart()
        }
    }

    // A preset changes this card's variant or switches it off: it shrinks away, the
    // preset goes on, and the new variant pops back in (see PresetMotion.qml).
    // 1 = in place, 0 = away. Two fixed animations started from the flag, not one Behavior (see
    // `reveal`).
    property real swapK: 1
    NumberAnimation {
        id: swapOut
        target: win
        property: "swapK"
        to: 0
        duration: PresetMotion.outMs
        easing.type: Easing.InCubic
    }
    NumberAnimation {
        id: swapIn
        target: win
        property: "swapK"
        to: 1
        duration: PresetMotion.inMs
        easing.type: Easing.OutBack
        easing.overshoot: 1.4
    }
    Connections {
        target: PresetMotion
        function onClockOutChanged() {
            if (PresetMotion.clockOut) {
                swapIn.stop()
                swapOut.restart()
            } else if (win.want) {
                swapOut.stop()
                swapIn.restart()
            } else {
                // Switched off: stays away until the swallow is over, or the card
                // would come back for a moment while it is still being swallowed.
                swapOut.stop()
                swapRest.restart()
            }
        }
    }
    Timer {
        id: swapRest
        interval: 420
        onTriggered: win.swapK = 1
    }
    Connections {
        target: win
        function onWantChanged() {
            if (win.want && swapRest.running) {
                swapRest.stop()
                win.swapK = 1
            }
        }
    }

    Timer {
        id: glideEnd
        interval: 640
        onTriggered: {
            win.glideOn = false
            win.gliding = false
                bumpAnim.restart()
        }
    }

    // Edit Desktop's shelf shows the clock as it really looks: a picture of the
    // card, taken every second while the mode is on (EditPreview.qml).
    EditPreview {
        widgetId: "clock"
        target: card
        pixelRatio: win.uiScale
    }


    // One key of the time: a Pill cap with one digit on it. Hours are the navy
    // chip, minutes the mint-to-cyan gradient. The key hard-shadows down-right
    // and presses in whenever its digit changes (Pill's own press / spring).
    component KeyTile: Item {
        id: tile

        property string digit: "0"
        property bool gradientFill: false     // minutes: true
        property bool ghost: false            // a leading 0 in 12h mode
        property real tilt: 0

        width: 57                              // 54 cap + 3 shadow
        height: 82                             // 78 cap + 4 shadow
        rotation: tile.tilt
        transformOrigin: Item.Center

        onDigitChanged: {
            press.pressed = true
            release.restart()
        }

        Timer {
            id: release
            interval: 90
            onTriggered: press.pressed = false
        }

        Gradient {
            id: minuteFill
            GradientStop { position: 0.0; color: Theme.accentMint }
            GradientStop { position: 1.0; color: Theme.accentCyan }
        }

        Pill {
            id: press
            anchors.fill: parent
            cornerRadius: 16
            ringWidth: Theme.borderWidth + Theme.whiteLine
            shadowDx: 3
            shadowDy: 4
            fillColor: Theme.chipFill
            fillGradient: tile.gradientFill ? minuteFill : null

            Text {
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: tile.digit
                color: tile.gradientFill ? Theme.colBorder : Theme.chipInk
                opacity: tile.ghost ? 0.28 : 1
                font.family: Theme.fontFamily
                font.pixelSize: 50
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold

                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }
            }
        }
    }

    // ===== small parts shared by the designs =====

    component GlyphRing: Item {
        id: gr

        property string value: "0"
        property color ink: "#000000"
        property real radius: 5
        property real dx: 0
        property real dy: 0
        property int steps: 8

        Repeater {
            model: gr.steps

            Text {
                required property int index

                x: gr.dx + Math.cos(index * 2 * Math.PI / gr.steps) * gr.radius
                y: gr.dy + Math.sin(index * 2 * Math.PI / gr.steps) * gr.radius
                width: gr.width
                height: gr.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: gr.value
                color: gr.ink
                font.family: Theme.fontFamily
                font.pixelSize: 84
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }
    }

    // One sticker numeral, straight on the wallpaper: the navy outline and the
    // hard shadow in one (the shadow is the same outline moved down-right),
    // a white ring, then the colour. Pops when its digit changes.
    component StickerDigit: Item {
        id: sd

        property string value: "0"
        property color fillColor: Theme.accentMint
        property bool ghost: false            // a leading 0 in 12h mode: pale grey fill, still fully solid
        property real tilt: 0
        property real pop: 1

        width: 56
        height: 96
        rotation: sd.tilt
        scale: sd.pop
        transformOrigin: Item.Center

        // (No `opacity` for the ghost: the numeral is many stacked copies of
        // the glyph, and fading each one lets the others show through, which
        // turns the outline muddy. A pale fill keeps every edge crisp.)
        onValueChanged: popAnim.restart()

        NumberAnimation {
            id: popAnim
            target: sd
            property: "pop"
            from: 0.82
            to: 1
            duration: 340
            easing.type: Easing.OutBack
            easing.overshoot: 2.4
        }

        GlyphRing { anchors.fill: parent; value: sd.value; ink: Theme.colBorder; radius: 6; dx: 3; dy: 4 }
        GlyphRing { anchors.fill: parent; value: sd.value; ink: Theme.colBorder; radius: 6 }
        GlyphRing { anchors.fill: parent; value: sd.value; ink: "#ffffff"; radius: 3.2 }
        GlyphRing { anchors.fill: parent; value: sd.value; ink: sd.ghost ? Theme.colOuterRing : sd.fillColor; radius: 0; steps: 1 }
    }

    // A diamond of the beat: lit on its turn, and it pops when it lights.
    component BeatDiamond: Rectangle {
        id: bd

        property bool lit: false
        property color litColor: Theme.accentMint
        property color offColor: Theme.pSurfaceDivider
        property color lineColor: Theme.pLine
        property real pop: 1

        width: 12
        height: 12
        radius: 3
        rotation: 45
        scale: bd.pop
        color: bd.lit ? bd.litColor : bd.offColor
        border.width: 2
        border.color: bd.lineColor

        onLitChanged: {
            if (bd.lit)
                beatPop.restart()
        }

        NumberAnimation {
            id: beatPop
            target: bd
            property: "pop"
            from: 1.7
            to: 1
            duration: 360
            easing.type: Easing.OutBack
            easing.overshoot: 2.2
        }
    }

    // The tilted gradient sticker with today's date number.
    component DateSticker: Pill {
        id: ds

        property int day: 1

        width: 44
        height: 44
        cornerRadius: 13
        ringWidth: 3
        rotation: -5
        transformOrigin: Item.Center
        fillGradient: Gradient {
            GradientStop { position: 0.0; color: Theme.accentMint }
            GradientStop { position: 1.0; color: Theme.accentCyan }
        }

        Text {
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: ds.day
            color: Theme.colBorder
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }

    // The AM / PM switch. In 12h mode the mint thumb sits under the current
    // half; in 24h mode it stretches over the whole track and reads "24H".
    component AmPmSwitch: Item {
        id: sw

        property bool full: false      // 24h
        property bool pm: false
        readonly property real half: (sw.width - 6) / 2

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Theme.pSurfaceHover
            border.width: Theme.borderWidth
            border.color: Theme.pLine
        }

        Rectangle {
            y: 3
            height: sw.height - 6
            radius: 7
            color: Theme.accentMint
            x: 3 + (sw.full ? 0 : (sw.pm ? sw.half : 0))
            width: sw.full ? sw.width - 6 : sw.half

            Behavior on x {
                NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
            }

            Behavior on width {
                NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
            }
        }

        Text {
            x: 3
            width: sw.half
            height: sw.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "AM"
            opacity: sw.full ? 0 : 1
            color: sw.pm ? Theme.pInkSub : Theme.colBorder
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        Text {
            x: 3 + sw.half
            width: sw.half
            height: sw.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "PM"
            opacity: sw.full ? 0 : 1
            color: sw.pm ? Theme.colBorder : Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        Text {
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "24H"
            opacity: sw.full ? 1 : 0
            color: Theme.colBorder
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }
    }

    // The seconds, on a small navy chip.
    component SecChip: Pill {
        id: sc

        property string label: "00"
        property color ink: Theme.colBorder

        width: 56
        height: 30
        cornerRadius: 10
        ringWidth: 3
        fillColor: Theme.chipFill
        rotation: 3
        transformOrigin: Item.Center

        Text {
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: sc.label
            color: sc.ink
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }

    // The little AM / PM tag the two card-less designs show in 12h mode.
    component AmPmChip: Pill {
        id: chip

        property string label: "AM"

        width: 36
        height: 28
        cornerRadius: 9
        ringWidth: 2
        fillColor: Theme.accentMint
        rotation: 3
        transformOrigin: Item.Center

        Text {
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: chip.label
            color: Theme.colBorder
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }

    // One day of the week: today is raised, tilted and lit; days already gone
    // are dimmed. Fills whatever size it is given.
    component DayBadge: Item {
        id: db

        property int dow: 0
        property bool today: false
        property bool past: false

        // Today's hard shadow, like a Pill's.
        Rectangle {
            visible: db.today
            x: 0
            y: 5
            width: db.width
            height: db.height - 6
            radius: 9
            color: Theme.pLineShadow
        }

        Rectangle {
            width: db.width
            height: db.height - (db.today ? 6 : 8)
            y: db.today ? 1 : 3
            radius: 9
            color: db.today ? "transparent" : Theme.pSurfaceHover
            opacity: db.past ? 0.55 : 1
            rotation: db.today ? -3 : 0
            transformOrigin: Item.Center
            border.width: db.today ? Theme.borderWidth : 0
            border.color: Theme.pLine
            gradient: db.today ? todayFill : null

            Gradient {
                id: todayFill
                GradientStop { position: 0.0; color: Theme.accentMint }
                GradientStop { position: 1.0; color: Theme.accentCyan }
            }

            Text {
                anchors.centerIn: parent
                text: Qt.locale().dayName(db.dow, Locale.ShortFormat).toUpperCase()
                color: db.today ? Theme.colBorder : Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }
    }

    // ===== Edit Desktop =====
    Item {
        id: shifter
        x: -win.boxX
        y: -win.boxY
        width: win.fullW
        height: win.fullH

    // ===========================================================================
    // Edit Desktop shrinks every desktop window into the same card with the same
    // transform (see EditStage.qml / services/EditMode.qml). Out of edit mode
    // this is a no-op: scale 1, no offset.
    EditStage {
        id: stage
        screenObj: win.screen
        uiScale: win.uiScale

        ScaleHost {
            anchors.fill: parent
            factor: win.uiScale

            Item {
                id: card

                // Gliding to a preset's spot (win.glideOn, see `follow`). Off the rest of the time,
                // so dragging and placing are exact.
                Behavior on x {
                    enabled: win.glideOn
                    NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
                }
                Behavior on y {
                    enabled: win.glideOn
                    NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
                }

                // Keeps the classic (white) look in the first dark mode; see Theme.classicFor.
                readonly property bool classicPanel: true

                // Which design is showing. 0 and 1 sit on the card; 2 and 3 are
                // only the time, straight on the wallpaper.
                readonly property int designIndex: ClockService.design
                readonly property bool housed: card.designIndex < 2
                readonly property var designNames: ["KEYS", "TOWER", "STICKER", "STACK"]

                // Where the content starts on the card: the pill's own border +
                // ring, plus room. Without the card, `pad` leaves room for the
                // numerals' outline and shadow.
                readonly property int inset: Theme.borderWidth + Theme.outerRingWidth + 10
                readonly property int pad: 14

                // How much attitude the keys have. 0 / 0 = a flat, level row.
                readonly property real tilt: 2.5       // degrees, outer keys; inner keys lean 40% of it
                readonly property int stagger: 10      // px the inner keys sit lower (the V)

                // On the navy chip: bright accents in the dark modes, navy ink in
                // Light (where the chip is pale and mint would vanish).
                readonly property color glow: Theme.dark ? Theme.accentMint : Theme.colBorder

                readonly property real contentW: content.item ? content.item.implicitWidth : 0
                readonly property real contentH: content.item ? content.item.implicitHeight : 0

                width: card.housed ? card.contentW + card.inset * 2 : card.contentW + card.pad * 2
                height: card.housed
                    ? card.contentH + card.inset * 2 + Theme.shadowOffset
                    : card.contentH + card.pad * 2

                // Drop-and-settle bounce when the design changes.
                property real bump: 1
                scale: card.bump * Math.max(0, win.reveal) * (win.placed ? 1 : 0) * (0.7 + 0.3 * Math.max(0, win.swapK))
                opacity: Math.max(0, Math.min(1, win.swapK))
                transformOrigin: Item.Center

                SequentialAnimation {
                    id: bumpAnim
                    NumberAnimation { target: card; property: "bump"; to: 1.035; duration: 90; easing.type: Easing.OutQuad }
                    NumberAnimation { target: card; property: "bump"; to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 3 }
                }

                // A new design is a new size: keep the card on screen (not while
                // it is being dragged: then the drag owns the position).
                onWidthChanged: {
                    if (!chrome.dragging && !dragArea.drag.active)
                        win.place()
                }

                onHeightChanged: {
                    if (!chrome.dragging && !dragArea.drag.active)
                        win.place()
                }

                Connections {
                    target: ClockService
                    function onDesignChanged() {
                        // (Not for the saved design being read back at startup.)
                        if (ClockService.loaded) {
                            bumpAnim.restart()
                            labelTimer.restart()
                        }
                    }
                }

                // The housing — the same navy outline / pale ring / surface fill /
                // hard shadow as the bar, the dock and the To-Do card. Only the
                // card designs have it; the other two are just the time.
                Pill {
                    anchors.fill: parent
                    visible: card.housed
                    cornerRadius: Theme.radiusOuter
                    ringWidth: Theme.borderWidth + Theme.outerRingWidth
                    ringColorTop: Theme.pSurfaceRing
                    ringColorBottom: ringColorTop
                    fillColor: Theme.pSurface
                }

                // Edit Desktop: outline, corner diamonds, a tag and a drag
                // shield (EditChrome.qml). Draws nothing outside the mode.
                EditChrome {
                    id: chrome
                    widgetId: "clock"
                    target: card
                    roomW: win.roomW
                    roomH: win.roomH
                    screenName: win.screen ? win.screen.name : ""
                    onMoved: ClockService.setPosition(card.x, card.y, win.screen ? win.screen.name : "", win.uiScale)
                    onRemoveRequested: ClockService.setShown(false)
                }

                // Left button: drag the card on the normal desktop, unless Lock all
                // is on (EditMode.desktopDragAllowed; while editing, the shield in
                // EditChrome.qml does the moving instead, until the clock is
                // selected for editing: then this does, like on the desktop).
                // Double-click flips 12h / 24h. The hover button sits on top of this.
                MouseArea {
                    id: dragArea
                    z: 10
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: EditMode.desktopDragAllowed || chrome.selected
                        ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor

                    drag.target: EditMode.desktopDragAllowed || chrome.selected ? card : null
                    drag.axis: Drag.XAndYAxis
                    drag.minimumX: 0
                    drag.maximumX: Math.max(0, win.roomW - card.width)
                    drag.minimumY: 0
                    drag.maximumY: Math.max(0, win.roomH - card.height)

                    onDoubleClicked: ClockService.toggleFormat()

                    // Remember the new spot when a drag ends (also when it is cut
                    // short). A plain click doesn't save anything, so a card that
                    // is squeezed onto a small screen for a moment can't overwrite
                    // where you put it.
                    drag.onActiveChanged: {
                        // Edit Desktop's alignment grid (EditChrome.qml) needs to know
                        // about a drag that is not its own shield's.
                        chrome.ownDrag = drag.active
                        if (!drag.active)
                            ClockService.setPosition(card.x, card.y, win.screen ? win.screen.name : "", win.uiScale)
                    }
                }

                // ===== the hover button: next design =====
                HoverHandler {
                    id: cardHover
                }

                Timer {
                    id: labelTimer
                    interval: 1400
                }

                Timer {
                    id: hideTimer
                    interval: 350
                    onTriggered: card.btnShown = false
                }

                property bool btnShown: false
                // The design button is an Edit Desktop thing: it is there only while the
                // clock is selected for editing (click it on the card), never on the
                // normal desktop.
                readonly property bool wantBtn: chrome.selected

                onWantBtnChanged: {
                    if (card.wantBtn) {
                        hideTimer.stop()
                        card.btnShown = true
                    } else {
                        hideTimer.restart()
                    }
                }

                Item {
                    id: btn
                    z: 20
                    width: 30
                    height: 34
                    x: card.width - btn.width + 10
                    y: -12
                    visible: opacity > 0.01
                    opacity: card.btnShown ? 1 : 0
                    scale: card.btnShown ? 1 : 0.6
                    transformOrigin: Item.Center

                    Behavior on opacity {
                        NumberAnimation { duration: 140 }
                    }

                    Behavior on scale {
                        NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2 }
                    }

                    Pill {
                        anchors.fill: parent
                        cornerRadius: 10
                        ringWidth: 3
                        pressed: btnArea.pressed
                        fillGradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.accentMint }
                            GradientStop { position: 1.0; color: Theme.accentCyan }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            name: "style"
                            size: 18
                            weight: 600
                            color: Theme.colBorder
                        }
                    }

                    MouseArea {
                        id: btnArea
                        anchors.fill: parent
                        // An invisible button must not eat clicks meant for the card.
                        enabled: card.btnShown
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ClockService.cycleDesign()
                    }
                }

                Pill {
                    id: nameChip
                    z: 19
                    visible: card.btnShown && (btnArea.containsMouse || labelTimer.running)
                    anchors.right: btn.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: btn.verticalCenter
                    width: nameText.implicitWidth + 24
                    height: 30
                    cornerRadius: 10
                    ringWidth: 3
                    fillColor: Theme.chipFill

                    Text {
                        id: nameText
                        anchors.centerIn: parent
                        text: card.designNames[card.designIndex] + "  " + (card.designIndex + 1) + "/" + card.designNames.length
                        color: Theme.chipInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                }

                // ===== the current design =====
                Loader {
                    id: content
                    z: 2
                    x: card.housed ? card.inset : card.pad
                    y: card.housed ? card.inset : card.pad
                    sourceComponent: card.designIndex === 0 ? keysDesign
                        : card.designIndex === 1 ? towerDesign
                        : card.designIndex === 2 ? stickerDesign
                        : stackDesign
                }

                // ===== 0 KEYS =====
                Component {
                    id: keysDesign

                    Item {
                        id: kroot
                        implicitWidth: 286
                        implicitHeight: kcol.implicitHeight

                        Column {
                            id: kcol
                            width: kroot.implicitWidth
                            spacing: 10

                            // ===== header =====
                            Item {
                                width: kcol.width
                                height: 46

                                DateSticker {
                                    id: ksticker
                                    x: 2
                                    y: 1
                                    day: win.now.getDate()
                                }

                                Column {
                                    anchors.left: ksticker.right
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 0

                                    Text {
                                        text: Qt.locale().dayName(win.now.getDay(), Locale.LongFormat)
                                        color: Theme.pInk
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 20
                                        font.weight: Font.ExtraBold
                                        font.styleName: Theme.fontStyleBold
                                    }

                                    Text {
                                        text: Qt.formatDate(win.now, "MMMM yyyy")
                                        color: Theme.pInkSub
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }
                                }

                                AmPmSwitch {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 84
                                    height: 30
                                    full: ClockService.use24h
                                    pm: win.pm
                                }
                            }

                            // ===== the stage =====
                            Item {
                                id: kstage
                                width: kcol.width
                                height: 100

                                // Faint lane lines behind the keys, one per key.
                                Repeater {
                                    model: 4

                                    Rectangle {
                                        required property int index
                                        // Keys are 57 wide with 6 between, and the beat column is 24 wide.
                                        readonly property real rowW: 4 * 57 + 24 + 4 * 6
                                        readonly property real laneLeft: (kstage.width - rowW) / 2
                                        x: laneLeft + (index < 2 ? index * 63 : 2 * 63 + 24 + 6 + (index - 2) * 63) + 27 - 1
                                        y: 0
                                        width: 2
                                        height: kstage.height
                                        radius: 1
                                        color: Theme.pSurfaceDivider
                                    }
                                }

                                // The beat ring: starts at the lit diamond each second and
                                // grows and fades. Drawn behind the keys.
                                Rectangle {
                                    id: kripple
                                    property real r: 10
                                    property real cy: kstage.height / 2
                                    width: kripple.r * 2
                                    height: kripple.r * 2
                                    x: kstage.width / 2 - kripple.r
                                    y: kripple.cy - kripple.r
                                    radius: kripple.r
                                    color: "transparent"
                                    border.width: 3
                                    border.color: win.secs % 2 === 0 ? Theme.accentMint : Theme.accentCyan
                                    opacity: 0
                                }

                                ParallelAnimation {
                                    id: krippleAnim
                                    NumberAnimation { target: kripple; property: "r"; from: 10; to: 48; duration: 560; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: kripple; property: "opacity"; from: 0.85; to: 0; duration: 560; easing.type: Easing.OutQuad }
                                }

                                Connections {
                                    target: win
                                    function onSecsChanged() {
                                        kripple.cy = kstage.height / 2 + (win.secs % 2 === 0 ? -14 : 14)
                                        krippleAnim.restart()
                                    }
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    height: kstage.height
                                    spacing: 6

                                    // 12h mode: a leading zero is ghosted, not removed, so
                                    // nothing moves.
                                    KeyTile {
                                        y: 4
                                        digit: win.hh.charAt(0)
                                        ghost: !ClockService.use24h && win.hh.charAt(0) === "0"
                                        tilt: -card.tilt
                                    }

                                    KeyTile {
                                        y: 4 + card.stagger
                                        digit: win.hh.charAt(1)
                                        tilt: -card.tilt * 0.4
                                    }

                                    // The beat: two diamonds that take turns.
                                    Item {
                                        width: 24
                                        height: kstage.height

                                        BeatDiamond {
                                            x: 6
                                            y: kstage.height / 2 - 14 - 6
                                            lit: win.secs % 2 === 0
                                            litColor: Theme.accentMint
                                        }

                                        BeatDiamond {
                                            x: 6
                                            y: kstage.height / 2 + 14 - 6
                                            lit: win.secs % 2 !== 0
                                            litColor: Theme.accentCyan
                                        }
                                    }

                                    KeyTile {
                                        y: 4 + card.stagger
                                        gradientFill: true
                                        digit: win.mm.charAt(0)
                                        tilt: card.tilt * 0.4
                                    }

                                    KeyTile {
                                        y: 4
                                        gradientFill: true
                                        digit: win.mm.charAt(1)
                                        tilt: card.tilt
                                    }
                                }
                            }

                            // ===== the second lane =====
                            Item {
                                id: klane
                                width: kcol.width
                                height: 30

                                SecChip {
                                    id: ksec
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    label: win.ss
                                    ink: card.glow
                                }

                                Item {
                                    id: ktrack
                                    anchors.left: parent.left
                                    anchors.leftMargin: 4
                                    anchors.right: ksec.left
                                    anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: -2
                                    height: 20

                                    readonly property real headSize: 12
                                    // The playhead is a second ahead, so it is at the far end at :59.
                                    readonly property real pos: ktrack.width * Math.min(60, win.secs + 1) / 60
                                    readonly property real headX: Math.min(ktrack.width - ktrack.headSize, Math.max(0, ktrack.pos - ktrack.headSize / 2))

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: 12
                                        radius: 6
                                        color: Theme.pSurfaceDivider
                                        border.width: 2
                                        border.color: Theme.pLine
                                    }

                                    // What has played this minute.
                                    Rectangle {
                                        x: 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 8
                                        radius: 4
                                        width: Math.max(0, ktrack.headX + ktrack.headSize / 2 - 2)

                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: Theme.accentMint }
                                            GradientStop { position: 1.0; color: Theme.accentCyan }
                                        }

                                        // At :00 the lane just resets instead of sweeping backwards.
                                        Behavior on width {
                                            enabled: win.secs !== 0
                                            NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 }
                                        }
                                    }

                                    // Gates at 15 / 30 / 45 s.
                                    Repeater {
                                        model: 3

                                        Rectangle {
                                            required property int index
                                            x: ktrack.width * (index + 1) / 4 - 1.5
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 3
                                            height: 12
                                            radius: 1.5
                                            color: Theme.pLine
                                            opacity: 0.45
                                        }
                                    }

                                    // The playhead: a diamond note.
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: ktrack.headSize
                                        height: ktrack.headSize
                                        radius: 3
                                        rotation: 45
                                        color: Theme.accentMint
                                        border.width: 2
                                        border.color: Theme.pLine
                                        x: ktrack.headX

                                        Behavior on x {
                                            enabled: win.secs !== 0
                                            NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                                        }
                                    }
                                }
                            }

                            // ===== the week =====
                            Row {
                                id: kweek
                                width: kcol.width
                                height: 32
                                spacing: 4

                                // Sunday = 0 ... Saturday = 6; Qt's firstDayOfWeek is Monday = 1 ... Sunday = 7.
                                readonly property int firstDow: Qt.locale().firstDayOfWeek % 7
                                readonly property int todayIdx: (win.now.getDay() - kweek.firstDow + 7) % 7

                                Repeater {
                                    model: 7

                                    DayBadge {
                                        required property int index
                                        width: (kweek.width - 6 * kweek.spacing) / 7
                                        height: kweek.height
                                        dow: (kweek.firstDow + index) % 7
                                        today: index === kweek.todayIdx
                                        past: index < kweek.todayIdx
                                    }
                                }
                            }
                        }
                    }
                }

                // ===== 1 TOWER =====
                Component {
                    id: towerDesign

                    Item {
                        id: troot
                        implicitWidth: 208
                        implicitHeight: tcol.implicitHeight

                        Column {
                            id: tcol
                            width: troot.implicitWidth
                            spacing: 10

                            // ===== header =====
                            Item {
                                width: tcol.width
                                height: 46

                                DateSticker {
                                    id: tsticker
                                    x: 2
                                    y: 1
                                    day: win.now.getDate()
                                }

                                Column {
                                    anchors.left: tsticker.right
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 0

                                    Text {
                                        text: Qt.locale().dayName(win.now.getDay(), Locale.LongFormat)
                                        color: Theme.pInk
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 20
                                        font.weight: Font.ExtraBold
                                        font.styleName: Theme.fontStyleBold
                                    }

                                    Text {
                                        text: Qt.formatDate(win.now, "MMMM yyyy")
                                        color: Theme.pInkSub
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }

                            // ===== body =====
                            Item {
                                id: tbody
                                width: tcol.width
                                height: 212

                                // The second lane, standing up: the playhead hops down it.
                                Item {
                                    id: vlane
                                    x: 0
                                    width: 26
                                    height: tbody.height

                                    readonly property real headSize: 12
                                    // A second ahead, so it is at the bottom at :59.
                                    readonly property real headY: Math.min(vlane.height - vlane.headSize,
                                        Math.max(0, vlane.height * Math.min(60, win.secs + 1) / 60 - vlane.headSize / 2))

                                    Rectangle {
                                        x: 7
                                        width: 12
                                        height: vlane.height
                                        radius: 6
                                        color: Theme.pSurfaceDivider
                                        border.width: 2
                                        border.color: Theme.pLine
                                    }

                                    // What has played this minute.
                                    Rectangle {
                                        x: 9
                                        y: 2
                                        width: 8
                                        radius: 4
                                        height: Math.max(0, vlane.headY + vlane.headSize / 2 - 2)

                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: Theme.accentMint }
                                            GradientStop { position: 1.0; color: Theme.accentCyan }
                                        }

                                        // At :00 the lane just resets instead of sweeping backwards.
                                        Behavior on height {
                                            enabled: win.secs !== 0
                                            NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 }
                                        }
                                    }

                                    // Gates at 15 / 30 / 45 s.
                                    Repeater {
                                        model: 3

                                        Rectangle {
                                            required property int index
                                            x: 7
                                            y: vlane.height * (index + 1) / 4 - 1.5
                                            width: 12
                                            height: 3
                                            radius: 1.5
                                            color: Theme.pLine
                                            opacity: 0.45
                                        }
                                    }

                                    // The playhead: a diamond note.
                                    Rectangle {
                                        x: 7
                                        width: vlane.headSize
                                        height: vlane.headSize
                                        radius: 3
                                        rotation: 45
                                        color: Theme.accentMint
                                        border.width: 2
                                        border.color: Theme.pLine
                                        y: vlane.headY

                                        Behavior on y {
                                            enabled: win.secs !== 0
                                            NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                                        }
                                    }
                                }

                                // Hours on top, the beat in the middle, minutes below. The
                                // keys zig-zag: each row has one key sitting lower.
                                Item {
                                    id: tkeys
                                    x: 36
                                    width: 120
                                    height: tbody.height

                                    KeyTile {
                                        x: 0
                                        y: 0
                                        digit: win.hh.charAt(0)
                                        ghost: !ClockService.use24h && win.hh.charAt(0) === "0"
                                        tilt: -card.tilt
                                    }

                                    KeyTile {
                                        x: 63
                                        y: card.stagger * 0.8
                                        digit: win.hh.charAt(1)
                                        tilt: -card.tilt * 0.4
                                    }

                                    BeatDiamond {
                                        x: 60 - 14 - 6
                                        y: 106 - 6
                                        lit: win.secs % 2 === 0
                                        litColor: Theme.accentMint
                                    }

                                    BeatDiamond {
                                        x: 60 + 14 - 6
                                        y: 106 - 6
                                        lit: win.secs % 2 !== 0
                                        litColor: Theme.accentCyan
                                    }

                                    KeyTile {
                                        x: 0
                                        y: 122 + card.stagger * 0.8
                                        gradientFill: true
                                        digit: win.mm.charAt(0)
                                        tilt: card.tilt * 0.4
                                    }

                                    KeyTile {
                                        x: 63
                                        y: 122
                                        gradientFill: true
                                        digit: win.mm.charAt(1)
                                        tilt: card.tilt
                                    }
                                }

                                // The week, standing up.
                                Column {
                                    id: tweek
                                    x: 166
                                    width: 42
                                    spacing: 2

                                    readonly property int firstDow: Qt.locale().firstDayOfWeek % 7
                                    readonly property int todayIdx: (win.now.getDay() - tweek.firstDow + 7) % 7

                                    Repeater {
                                        model: 7

                                        DayBadge {
                                            required property int index
                                            width: tweek.width
                                            height: (tbody.height - 6 * tweek.spacing) / 7
                                            dow: (tweek.firstDow + index) % 7
                                            today: index === tweek.todayIdx
                                            past: index < tweek.todayIdx
                                        }
                                    }
                                }
                            }

                            // ===== bottom =====
                            Item {
                                width: tcol.width
                                height: 30

                                SecChip {
                                    id: tsec
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    label: win.ss
                                    ink: card.glow
                                }

                                AmPmSwitch {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: tcol.width - tsec.width - 12
                                    height: 30
                                    full: ClockService.use24h
                                    pm: win.pm
                                }
                            }
                        }
                    }
                }

                // ===== 2 STICKER =====
                Component {
                    id: stickerDesign

                    Item {
                        id: sroot
                        implicitWidth: 4 * 56 + 24 + 4 * 2
                        implicitHeight: 96 + card.stagger

                        Row {
                            spacing: 2

                            StickerDigit {
                                y: 0
                                value: win.hh.charAt(0)
                                ghost: !ClockService.use24h && win.hh.charAt(0) === "0"
                                fillColor: Theme.accentMint
                                tilt: -card.tilt
                            }

                            StickerDigit {
                                y: card.stagger
                                value: win.hh.charAt(1)
                                fillColor: Theme.accentMint
                                tilt: -card.tilt * 0.4
                            }

                            // The beat: two diamonds that take turns.
                            Item {
                                width: 24
                                height: sroot.implicitHeight

                                BeatDiamond {
                                    x: 6
                                    y: sroot.implicitHeight / 2 - 14 - 6
                                    lit: win.secs % 2 === 0
                                    litColor: Theme.accentMint
                                    offColor: "#ffffff"
                                    lineColor: Theme.colBorder
                                }

                                BeatDiamond {
                                    x: 6
                                    y: sroot.implicitHeight / 2 + 14 - 6
                                    lit: win.secs % 2 !== 0
                                    litColor: Theme.accentCyan
                                    offColor: "#ffffff"
                                    lineColor: Theme.colBorder
                                }
                            }

                            StickerDigit {
                                y: card.stagger
                                value: win.mm.charAt(0)
                                fillColor: Theme.accentCyan
                                tilt: card.tilt * 0.4
                            }

                            StickerDigit {
                                y: 0
                                value: win.mm.charAt(1)
                                fillColor: Theme.accentCyan
                                tilt: card.tilt
                            }
                        }

                        AmPmChip {
                            visible: !ClockService.use24h
                            label: win.pm ? "PM" : "AM"
                            x: sroot.implicitWidth - width + 6
                            y: sroot.implicitHeight - height + 4
                        }
                    }
                }

                // ===== 3 STACK =====
                Component {
                    id: stackDesign

                    Item {
                        id: aroot
                        implicitWidth: 2 * 56 + 2
                        implicitHeight: 2 * (96 + card.stagger) + 24 + 8

                        // Hours on top...
                        Row {
                            spacing: 2

                            StickerDigit {
                                y: 0
                                value: win.hh.charAt(0)
                                ghost: !ClockService.use24h && win.hh.charAt(0) === "0"
                                fillColor: Theme.accentMint
                                tilt: -card.tilt
                            }

                            StickerDigit {
                                y: card.stagger
                                value: win.hh.charAt(1)
                                fillColor: Theme.accentMint
                                tilt: -card.tilt * 0.4
                            }
                        }

                        // ...the beat in the middle...
                        BeatDiamond {
                            x: aroot.implicitWidth / 2 - 14 - 6
                            y: 96 + card.stagger + 4 + 12 - 6
                            lit: win.secs % 2 === 0
                            litColor: Theme.accentMint
                            offColor: "#ffffff"
                            lineColor: Theme.colBorder
                        }

                        BeatDiamond {
                            x: aroot.implicitWidth / 2 + 14 - 6
                            y: 96 + card.stagger + 4 + 12 - 6
                            lit: win.secs % 2 !== 0
                            litColor: Theme.accentCyan
                            offColor: "#ffffff"
                            lineColor: Theme.colBorder
                        }

                        // ...and minutes below.
                        Row {
                            y: 96 + card.stagger + 4 + 24 + 4
                            spacing: 2

                            StickerDigit {
                                y: card.stagger
                                value: win.mm.charAt(0)
                                fillColor: Theme.accentCyan
                                tilt: card.tilt * 0.4
                            }

                            StickerDigit {
                                y: 0
                                value: win.mm.charAt(1)
                                fillColor: Theme.accentCyan
                                tilt: card.tilt
                            }
                        }

                        AmPmChip {
                            visible: !ClockService.use24h
                            label: win.pm ? "PM" : "AM"
                            x: aroot.implicitWidth - width + 6
                            y: aroot.implicitHeight - height + 4
                        }
                    }
                }
            }
        }
    }
    }
}
