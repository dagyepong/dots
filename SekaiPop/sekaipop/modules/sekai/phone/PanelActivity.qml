pragma Singleton
import QtQuick

// Everything drawn inside PhoneBody (QuickPanelFace and the toggles,
// sliders and dialogs it's built from) sits inside PhoneBody's own
// supersampled + mipmapped layers (see PhoneBody's `crisp`/`moving`/
// `busy`). This singleton is what feeds PhoneBody's `busy`: it goes true
// the moment something calls touch(), and back false `holdMs` after the
// last one. PhoneBody itself no longer drops draw quality for `busy`
// (dragging a slider or holding a button used to blur exactly what you
// were looking at, for a barely-there performance gain) — `busy` now
// only feeds the `crisp` bookkeeping QuickPanel.qml's close animation
// reads, so this file's job is unchanged even though PhoneBody stopped
// using it to trim anything.
//
// Only genuinely continuous, many-frame gestures call touch() -- a
// dragged slider, a scrolled/flicked list, a swipe-to-dismiss, a held
// press-and-fill. A one-shot ~150-300ms press bounce or hover fade does
// NOT call it -- there'd be nothing for a short animation to gain by
// triggering it now anyway. Sustained gestures are the case this
// singleton actually earns its keep on -- see the call sites
// (`onContentYChanged`, `onPositionChanged: if (drag.active)`,
// `onHoldFillChanged`) for which ones those are.
//
// touch()-and-expire rather than a start/stop counter on purpose: a
// counter can only go back to zero if every start is matched by a
// stop, and a delegate that's destroyed mid-animation (a dismissed
// notification, a mixer row that scrolled out of view mid-drag) would
// leave it stuck non-zero forever, pinning the phone on light quality
// permanently. Touching a timer has no such failure mode -- worst
// case it just settles a `holdMs` late.
QtObject {
    id: root

    // Comfortably longer than a pointer-move gap during a drag/scroll
    // so one touch() per frame of gesture is enough to keep `busy`
    // continuously true for as long as the gesture runs.
    readonly property int holdMs: 320

    readonly property bool busy: hold.running

    function touch() {
        hold.restart()
    }

    property Timer hold: Timer {
        interval: root.holdMs
    }
}
