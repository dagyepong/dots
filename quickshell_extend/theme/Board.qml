// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B   O   A   R   D                                                      │
// │   singleton · the palette board, and where its paint sits                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The logo: a painter's palette whose five daubs are the active palette's
// colours. The board is a PNG; the daubs are drawn over it in Theme tokens.
//
// Daub positions come from `palette-board.json` beside the PNG, which
// theme_manager.py also reads, so both renderers share one geometry. `ready`
// stays false if the file is missing, so callers can fall back.

Singleton {
    id: root

    // Read-only data, installed with the wallpapers.
    readonly property string directory:
        `${Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share"}/impasto`
    readonly property string board: `file://${root.directory}/palette-board.png`

    // In board coordinates (a square `canvas` on a side). Zero means not
    // loaded.
    property int canvas: 0
    property real daubWidth: 0
    property real daubHeight: 0
    property real daubRadius: 0

    // One entry per daub: `key` is a palette token, plus `x`, `y`, `rotation`.
    property var paint: []

    readonly property bool ready: root.canvas > 0 && root.paint.length > 0

    readonly property FileView geometry: FileView {
        path: `${root.directory}/palette-board.json`

        onLoaded: {
            // A malformed file leaves the board unpainted.
            try {
                const description = JSON.parse(text())
                if (!description.canvas || !description.daub
                        || !Array.isArray(description.paint))
                    throw new Error("no canvas, no daub or no paint")
                root.daubWidth = description.daub.width
                root.daubHeight = description.daub.height
                root.daubRadius = description.daub.radius
                root.paint = description.paint
                root.canvas = description.canvas
            } catch (error) {
                console.warn("Board geometry unreadable, no paint:", error)
            }
        }
        // A missing board is expected on partial installs; stay quiet.
        onLoadFailed: error => {}
    }
}
