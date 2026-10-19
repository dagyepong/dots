import QtQuick
import Quickshell
import qs.services

// The front door of the workspace board (Overview.qml), which is built only while it is
// open (ComponentActivation.overviewActive, shell.qml).
//
// What used to sit at the top of Overview.qml and has to work when the board does not
// exist lives here: which overview a key opens (this shell's board or the ScrollOverview
// plugin's), the Edit Desktop rules, and closing whichever one is up. The functions keep
// the names and meaning Overview.qml had (`openOn`, `toggleOn`, `hide`, `close`), so the
// dock's Overview key calls `overviewBoard.toggleOn(screen)` as before.
//
// With the plugin picked (Settings -> Hyprland -> Overview -> scroll) and loaded, the
// board is never built at all: the plugin is asked and that is the end of it. The board is
// the fallback when the plugin is not there.
ActivationEntry {
    id: root

    name: "overview"
    // The board's own openOn asks the plugin again; by the time the board is built the
    // plugin has already been asked (or is not there), so open the board itself.
    openFunction: "openBoard"

    readonly property bool scrollStyle: SettingsService.get("overview.style") === "scroll"

    // Same rule as the board's old `openOn`.
    function openOn(screen) {
        if (EditMode.active)
            return
        if (root.scrollStyle)
            ScrollOverviewService.run("on", () => root.open(screen))
        else
            root.open(screen)
    }

    // Same rule as the board's old `toggleOn`.
    function toggleOn(screen) {
        const it = root.item
        if (it && it.open && (!screen || screen === it.targetScreen)) {
            root.close()
            return
        }
        if (EditMode.active)
            return
        if (root.scrollStyle)
            ScrollOverviewService.run("toggle", () => root.open(screen))
        else
            root.open(screen)
    }

    // Closes whichever overview is up: the board, and the plugin's when that one is picked.
    function hide() {
        root.close()
        if (root.scrollStyle && ScrollOverviewService.available)
            ScrollOverviewService.dispatch("off")
    }

    // Edit Desktop starting closes an overview that is already open.
    Connections {
        target: EditMode

        function onActiveChanged() {
            if (EditMode.active)
                root.hide()
        }
    }
}
