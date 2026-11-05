// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   F O N T   S E R V I C E                                                │
// │   installed fonts                                                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Loaded on demand: only the settings window ever asks, and fontconfig takes
// long enough that doing it at startup would delay the bar for nothing.
Singleton {
    id: root

    property var sans: []
    property var mono: []
    property bool loaded: false

    readonly property Process query: Process {
        command: [Quickshell.shellPath("scripts/fonts.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "")
                    return
                try {
                    const result = JSON.parse(text)
                    root.sans = result.sans ?? []
                    root.mono = result.mono ?? []
                    root.loaded = true
                } catch (error) {
                    console.warn("Cannot parse the font list:", error)
                }
            }
        }
    }

    function load(): void {
        if (!root.loaded)
            root.query.running = true
    }
}
