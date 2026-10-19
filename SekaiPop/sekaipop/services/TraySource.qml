import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick

// The system side of the tray (like MediaSource.qml for media): what
// apps have put in the system tray over StatusNotifierItem, plus which
// of them you've pinned to the bar.
//
//   items          every tray icon that's currently published
//   pinnedItems    the ones you've pinned, in tray order — only the ones
//                  that are running right now (shown in the bar)
//   unpinnedItems  the rest (shown in the dropdown)
//   isPinned(i) / togglePinned(i)
//
// Pins are remembered by the app's own tray id and saved to
// ~/.local/state/sekaipop/tray.json (or under $XDG_STATE_HOME), so they
// survive restarts. A pinned app that isn't running just doesn't show;
// it's still pinned and comes back when the app does.
Scope {
    id: root

    readonly property var items: SystemTray.items.values

    onItemsChanged: console.log("[tray] " + items.length + " item(s) in the system tray: "
        + items.map(i => i.id).join(", "))

    property var pinnedIds: []
    readonly property var pinnedItems: items.filter(i => pinnedIds.indexOf(i.id) !== -1)
    // Everything else — what the dropdown shows. An app is in exactly
    // one of the two places, never both.
    readonly property var unpinnedItems: items.filter(i => pinnedIds.indexOf(i.id) === -1)

    readonly property string stateDir:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/sekaipop"

    // Which apps are asking for attention (their tray status is "needs
    // attention": a new message, a failed backup...). The pinned ones show it on
    // their own icon in the bar; the tray button shows it for the dropdown's.
    readonly property bool unpinnedAttention: unpinnedItems.some(i => i.status === Status.NeedsAttention)

    function isPinned(item) {
        return item ? pinnedIds.indexOf(item.id) !== -1 : false
    }

    function togglePinned(item) {
        if (!item)
            return
        // Always assign a fresh array — mutating in place wouldn't
        // notify the bindings above.
        pinnedIds = isPinned(item)
            ? pinnedIds.filter(id => id !== item.id)
            : pinnedIds.concat([item.id])
        store.setText(JSON.stringify(pinnedIds))
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", stateDir])

    FileView {
        id: store
        path: root.stateDir + "/tray.json"
        printErrors: false // no file yet on first run is normal

        onLoaded: {
            try {
                const saved = JSON.parse(text())
                if (Array.isArray(saved))
                    root.pinnedIds = saved
            } catch (e) {
                console.warn("TraySource: couldn't read " + path + ": " + e)
            }
        }
    }
}
