import QtQuick
import Quickshell
import Quickshell.Hyprland

// The front door of one on-demand screen (see ComponentActivation.qml).
//
// shell.qml puts one of these next to the `LazyLoader` that builds the screen. `ipc call`
// handlers, buttons and shortcuts talk to the entry; the entry raises the screen's flag in
// ComponentActivation, hands the request to the screen once it exists, and lowers the flag
// again when the screen has finished closing (animation included), which is what makes the
// loader destroy it.
//
// The screen is a Scope that has `open`, `closing`, `targetScreen`, `openOn(screen)` and
// `close()` (CheatSheet, PaletteTool and Overview all do). It reports itself with
//     Component.onCompleted:   entry.attach(<its id>)
//     Component.onDestruction: entry.detach(<its id>)
// so nothing here depends on a signal of the loader itself.
//
// Rules this keeps:
//   - one request = at most one instance: a second request while the screen is built (or
//     being built) reuses it, and a request that arrives while it is closing reopens it;
//   - the flag is lowered only when `open` and `closing` are both false and nothing is
//     waiting, so a reopen that lands in the same tick as the end of the exit animation
//     does not get its screen pulled from under it;
//   - the instance is released from a `Qt.callLater`, never from inside its own signal.
Scope {
    id: root

    // The registry key: ComponentActivation.<name>Active.
    required property string name

    // What the screen is asked to do when it opens. CheatSheet / PaletteTool: openOn.
    // Overview: openBoard (its own openOn also asks the ScrollOverview plugin, which
    // shell.qml's OverviewEntry has already done by then).
    property string openFunction: "openOn"

    // The built screen, or null.
    property var item: null

    // True while the screen is up or still closing.
    readonly property bool shown: root.item !== null && (root.item.open === true || root.item.closing === true)
    // True while it is up (not closing).
    readonly property bool isOpen: root.item !== null && root.item.open === true

    // The request waiting for the screen to be built: { screen } or null.
    property var wanted: null

    function focusedScreen() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        for (const s of Quickshell.screens) {
            if (s.name === name)
                return s
        }
        return Quickshell.screens[0]
    }

    // Called from the screen's own Component.onCompleted, i.e. while it is still being
    // built: the request is handed over one event-loop turn later, when every id and
    // binding of its tree is in place.
    function attach(it) {
        root.item = it
        Qt.callLater(root.deliver)
    }

    function detach(it) {
        if (root.item === it)
            root.item = null
    }

    // Open on `screen` (null = the screen it was last on / the first one).
    function open(screen) {
        root.wanted = { screen: screen }
        ComponentActivation.setActive(root.name, true)
        // Built already (or built by the line above): hand it over now.
        root.deliver()
    }

    // Close it if it is up on `screen` (or on any screen when none is given), else open it.
    function toggle(screen) {
        const it = root.item
        if (it && it.open && (!screen || screen === it.targetScreen)) {
            root.wanted = null
            it.close()
            return
        }
        root.open(screen)
    }

    function close() {
        root.wanted = null
        if (root.item)
            root.item.close()
    }

    function deliver() {
        const it = root.item
        const w = root.wanted
        if (!it || !w)
            return
        root.wanted = null
        it[root.openFunction](w.screen)
    }

    function settle() {
        const it = root.item
        if (it && !it.open && !it.closing && root.wanted === null)
            ComponentActivation.setActive(root.name, false)
    }

    Connections {
        target: root.item
        ignoreUnknownSignals: true

        function onOpenChanged() {
            Qt.callLater(root.settle)
        }

        function onClosingChanged() {
            Qt.callLater(root.settle)
        }
    }
}
