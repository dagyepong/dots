pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../config"

Singleton {
    id: root

    signal idleBegan
    signal idleEnded

    property bool _active: true
    readonly property bool userActive: _active
    property real cursorX: 0
    property real cursorY: 0
    property real _prevCursorX: 0
    property real _prevCursorY: 0

    Process {
        id: cursorProc
        command: ["hyprctl", "cursorpos"]
        stdout: SplitParser {
            onRead: function(data) {
                var parts = data.split(",");
                if (parts.length === 2) {
                    root.cursorX = parseInt(parts[0].trim()) || 0;
                    root.cursorY = parseInt(parts[1].trim()) || 0;
                    // detect cursor movement for idle reset
                    if (Math.abs(root.cursorX - root._prevCursorX) > 3 || Math.abs(root.cursorY - root._prevCursorY) > 3) {
                        root.registerMouseMove();
                    }
                    root._prevCursorX = root.cursorX;
                    root._prevCursorY = root.cursorY;
                }
            }
        }
    }
    // poll less while idle: pets only need fresh cursor data when it's moving
    Timer { interval: root._active ? 2000 : 10000; running: true; repeat: true; onTriggered: cursorProc.running = true }

    Timer {
        id: idleTimer
        interval: Config.idleTimeout * 1000
        running: true
        onTriggered: { root._active = false; root.idleBegan(); }
    }

    function registerMouseMove(): void {
        if (!root._active) { root._active = true; root.idleEnded(); }
        idleTimer.restart();
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (["activewindow", "workspace", "focusedmon", "openwindow",
                 "closewindow", "movewindow", "fullscreen"].includes(n)) {
                root.registerMouseMove();
            }
        }
    }
}
