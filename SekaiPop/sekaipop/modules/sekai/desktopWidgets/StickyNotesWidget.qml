import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.editMode
import "../../common/functions/NotesMath.js" as NM

// The desktop Sticky Notes: any number of paper notes (up to 12) you can move,
// resize, recolour, pin and type into. Each note is a StickyNote.qml; their state
// (text, colour, place, size, pinned) is kept by services/NotesService.qml and
// remembered across restarts.
//
// Two windows come from this one file (shell.qml makes both):
//
//   pinnedLayer: false   the DESKTOP layer: unpinned notes, on WlrLayer.Background
//                        like the other widgets, under your windows and the dock.
//   pinnedLayer: true    the PINNED layer: pinned notes, on WlrLayer.Top, so they
//                        float above your windows. They ignore Desktop Focus Mode
//                        (that is the point of pinning), but not Game Mode.
//
// A note is drawn by exactly one of them. While Edit Desktop is open on this
// monitor the pinned layer steps aside and the desktop layer draws every note, so
// they shrink into the card with the rest of the desktop (EditStage) and stay
// under the shelf.
//
// How the moving works (same idea as the To-Do): a note is an Item inside ONE
// full-screen, transparent window; dragging only moves the Item, never the window,
// so it stays smooth. The window's input `mask` is only the notes (one slot each,
// see MaskSlot), so a click anywhere else on the desktop falls through to whatever
// is underneath. Keyboard focus is OnDemand: click a note and type, click a real
// window and the keyboard goes back to it.
//
// Not part of this widget (on purpose, to keep it small): the alignment grid of
// Edit Desktop (it snaps whole widgets, notes are free), the shelf's live picture
// of the widget (it shows the icon). Desktop presets: each preset has its OWN notes
// (NotesService.switchSet), unlike the To-Do, whose tasks are shared.
//
//   qs -c sekaipop ipc call notes toggle | show | hide | create | arrange
PanelWindow {
    id: win

    // See the header.
    property bool pinnedLayer: false

    // Notes live on the first monitor, like the To-Do.
    screen: Quickshell.screens.find(s => s.name === EditMode.homeScreen("")) ?? Quickshell.screens[0]

    // This monitor's scale (scale.json / services/ShellScale.qml). The notes are drawn
    // in design pixels inside a ScaleHost, so `roomW` x `roomH` is the screen as they
    // see it (real size / scale); places and sizes are kept in that same space.
    readonly property real uiScale: ShellScale.forScreen(win.screen)
    readonly property real fullW: win.screen ? win.screen.width : 0
    readonly property real fullH: win.screen ? win.screen.height : 0
    readonly property real roomW: win.fullW / win.uiScale
    readonly property real roomH: win.fullH / win.uiScale

    // Edit Desktop is open on this monitor (also while it is growing back).
    readonly property bool editingHere: EditMode.editing(win.screen ? win.screen.name : "")

    // How many notes this layer draws.
    readonly property int myCount: win.pinnedLayer
        ? (win.editingHere ? 0 : NotesService.pinnedCount)
        : (win.editingHere ? NotesService.count : NotesService.count - NotesService.pinnedCount)

    // Desktop Focus Mode (FocusGate.qml): `gate.show` is false while an application is
    // on this monitor's workspace. Only the desktop layer obeys it.
    FocusGate {
        id: gate
        widgetId: "notes"
        screenName: win.screen ? win.screen.name : ""
    }

    // On / off: the notes pop in with a little overshoot and are swallowed (a straight
    // shrink) on the way out, like the other widgets. Two fixed animations started from
    // onWantChanged. The window stays up until the swallow has finished.
    readonly property bool want: NotesService.loaded && NotesService.shown && win.myCount > 0
        && (win.pinnedLayer || gate.show)
    property real reveal: 0

    // Off while the saved state is read back, so a reload does not replay the pop.
    property bool armed: false

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
        running: NotesService.loaded
        onTriggered: win.armed = true
    }

    // The notes are on, or still being swallowed.
    readonly property bool live: win.want || win.reveal > 0.001

    // Not mapped while there is nothing to show: a full-screen transparent layer that is
    // only sitting there still costs the compositor a blend on every frame.
    visible: NotesService.loaded && win.live

    WlrLayershell.layer: win.pinnedLayer ? WlrLayer.Top
        : (WallpaperService.restacking ? WlrLayer.Bottom : WlrLayer.Background)
    WlrLayershell.namespace: win.pinnedLayer ? "sekaipop-notes-pinned" : "sekaipop-notes"
    // Not while editing the desktop: the shelf keeps the keyboard then (Esc).
    WlrLayershell.keyboardFocus: EditMode.active ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // ===== place the notes on screen =====
    // After a reload the window, the monitor list and scale.json all settle over a few
    // frames; fit again once they have: follows a changed shell scale and keeps every
    // note on screen. Both layers ask; the service does it once (it is idempotent).
    Timer {
        id: settle
        interval: 300
        onTriggered: NotesService.fit(win.roomW, win.roomH, win.uiScale)
    }

    onWidthChanged: settle.restart()
    onHeightChanged: settle.restart()
    onUiScaleChanged: settle.restart()
    onScreenChanged: settle.restart()
    onVisibleChanged: settle.restart()
    Component.onCompleted: {
        win.reveal = win.want ? 1 : 0
        settle.restart()
    }

    Connections {
        target: NotesService
        function onLoadedChanged() { settle.restart() }
        // A drop ends: the screen may have changed under the pointer meanwhile.
        function onInteractingChanged() {
            if (!NotesService.interacting)
                settle.restart()
        }
    }

    // ===== input mask =====
    // One rectangle per note, in real window pixels: the note's design rectangle times
    // the scale (and Edit Desktop's shrink). The service's row is read through
    // noteRect(), and `rev` is read there so it is worked out again whenever any note
    // moves, resizes, changes layer, appears or goes.
    function noteRect(i) {
        const rev = NotesService.rev
        if (!win.live || i >= NotesService.items.count)
            return null
        const n = NotesService.items.get(i)
        const here = win.pinnedLayer ? (n.pinned && !win.editingHere) : (!n.pinned || win.editingHere)
        if (!here)
            return null
        return NM.windowRect({ x: n.nx, y: n.ny, w: n.nw, h: n.nh }, stage.x, stage.y, win.uiScale * stage.scale)
    }

    component MaskSlot: Item {
        property int slot: 0
        property var host: null
        readonly property var r: host ? host.noteRect(slot) : null
        x: r ? r.x : 0
        y: r ? r.y : 0
        width: r ? r.w : 0
        height: r ? r.h : 0
    }

    // One pixel that always takes input, so the mask is never an empty region (an empty
    // one can mean "no mask" and would swallow every click on the desktop).
    Item {
        id: hole
        x: 0
        y: 0
        width: 1
        height: 1
    }

    MaskSlot { id: m0; slot: 0; host: win }
    MaskSlot { id: m1; slot: 1; host: win }
    MaskSlot { id: m2; slot: 2; host: win }
    MaskSlot { id: m3; slot: 3; host: win }
    MaskSlot { id: m4; slot: 4; host: win }
    MaskSlot { id: m5; slot: 5; host: win }
    MaskSlot { id: m6; slot: 6; host: win }
    MaskSlot { id: m7; slot: 7; host: win }
    MaskSlot { id: m8; slot: 8; host: win }
    MaskSlot { id: m9; slot: 9; host: win }
    MaskSlot { id: m10; slot: 10; host: win }
    MaskSlot { id: m11; slot: 11; host: win }

    mask: Region {
        item: hole
        regions: [
            Region { item: m0 }, Region { item: m1 }, Region { item: m2 }, Region { item: m3 },
            Region { item: m4 }, Region { item: m5 }, Region { item: m6 }, Region { item: m7 },
            Region { item: m8 }, Region { item: m9 }, Region { item: m10 }, Region { item: m11 }
        ]
    }

    // ===== the notes =====
    // Edit Desktop shrinks every desktop window into the same card with the same
    // transform (EditStage.qml / services/EditMode.qml). Out of edit mode this is a
    // no-op: scale 1, no offset.
    EditStage {
        id: stage
        screenObj: win.screen
        uiScale: win.uiScale

        ScaleHost {
            anchors.fill: parent
            factor: win.uiScale

            Item {
                id: deskRoom
                anchors.fill: parent

                Repeater {
                    model: NotesService.items

                    StickyNote {
                        room: deskRoom
                        roomW: win.roomW
                        roomH: win.roomH
                        reveal: win.reveal
                        mine: win.pinnedLayer ? (pinned && !win.editingHere) : (!pinned || win.editingHere)
                    }
                }
            }
        }
    }
}
