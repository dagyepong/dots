pragma Singleton
import QtQuick
import Quickshell

// The activation registry: which on-demand screens exist right now.
//
// A flag here is true only while its screen is wanted (asked for, or still playing its
// exit animation) and every flag starts false, so at rest none of these trees is built:
// no window, no bindings, no models, no timers, no per-instance MediaSource.
//
// This file instantiates nothing and decides nothing. The only writers are the entry
// points in shell.qml (one small `QtObject` per screen: the `ipc call` handler, the
// buttons and the shortcuts all go through it), and the only readers are the
// `LazyLoader`s in shell.qml. A flag goes true on the first request and false again once
// the screen has finished closing; a second request while it is still up reuses the
// instance, so one screen can never be built twice and activating one never touches
// another.
//
// Not in here on purpose (see docs/PERF-AUDIT-4.md for why each stays built):
//   Quick Panel / Settings phone, the Apps phone, the Wallpapers phone: one phone whose
//     window, size maths and state are shared by the bar, the dock and the notification
//     source (QuickPanel.qml); it needs splitting into controller and view first.
//   Edit Desktop shelf (EditTray), desktop menu, notification popups, OSD, reload report,
//     region picker, on-screen keyboard: each has start-up work tied to a state change
//     that has already happened by the time a lazily built copy would exist.
//   Desktop widgets, Edit guides, the lyrics source picker: already built by their own
//     `LazyLoader`s on their own state (Desktop Focus, Game Mode, lock).
Singleton {
    id: root

    // The keybind cheat sheet (modules/sekai/cheatSheet/CheatSheet.qml).
    property bool cheatSheetActive: false

    // The Palette tool (modules/sekai/palette/PaletteTool.qml), with the MediaSource and
    // the picture reader it owns.
    property bool paletteToolActive: false

    // The workspace board (modules/sekai/overview/Overview.qml). The ScrollOverview
    // plugin's own overview never needs it.
    property bool overviewActive: false

    // Everything the registry governs, for tests and for `ipc call` diagnostics.
    readonly property var names: ["cheatSheet", "paletteTool", "overview"]

    function isActive(name) {
        return !!root[name + "Active"]
    }

    // Only ActivationEntry calls this. Unknown names do nothing.
    function setActive(name, on) {
        if (root.names.indexOf(name) < 0)
            return
        root[name + "Active"] = !!on
    }
}
