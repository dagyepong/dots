pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property var activeWindowPos: {
        const tl = Hyprland.activeToplevel;
        if (!tl) return null;
        const obj = tl.lastIpcObject;
        if (!obj || !obj.at || !obj.size) return null;
        return { x: obj.at[0], y: obj.at[1], w: obj.size[0], h: obj.size[1] };
    }
    readonly property string activeWindowClass: Hyprland.activeToplevel?.lastIpcObject?.class ?? ""
    readonly property string activeWindowTitle: Hyprland.activeToplevel?.lastIpcObject?.title ?? ""
    readonly property bool isFullscreen: {
        const tl = Hyprland.activeToplevel;
        if (!tl) return false;
        const obj = tl.lastIpcObject;
        return obj ? obj.fullscreen > 1 : false;
    }

    readonly property int windowCount: {
        const ws = Hyprland.focusedWorkspace;
        return ws ? (ws.toplevels?.values?.length ?? 0) : 0;
    }

    // Rapid focus switching = busy user
    property int _focusChanges: 0
    readonly property bool isUserBusy: _focusChanges > 4

    signal windowOpened(windowClass: string, title: string)
    signal windowFocused(windowClass: string, title: string)
    signal workspaceChanged

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            const name = event.name;
            const data = event.data;
            if (name === "openwindow") {
                const p = data.split(",");
                if (p.length >= 4) root.windowOpened(p[2], p.slice(3).join(","));
            } else if (name === "activewindow") {
                const p = data.split(",");
                if (p.length >= 2) root.windowFocused(p[0], p.slice(1).join(","));
                root._focusChanges++;
            } else if (name === "workspace") {
                root.workspaceChanged();
            }
        }
    }

    Timer {
        interval: 10000; running: true; repeat: true
        onTriggered: root._focusChanges = Math.max(0, root._focusChanges - 2)
    }
}
