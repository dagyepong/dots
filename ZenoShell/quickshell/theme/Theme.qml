pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "themes.js" as ThemeLib

Singleton {
    id: root

    // ---- pywal palette (~/.cache/wal/colors.json), updates by itself ----
    FileView {
        id: walFile
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            id: pal

            property JsonObject special: JsonObject {
                property string background: "#0d0d0d"
                property string foreground: "#e6e6e6"
            }
            property JsonObject colors: JsonObject {
                property string color0: "#0d0d0d"
                property string color1: "#e06c75"
                property string color2: "#98c379"
                property string color3: "#e5c07b"
                property string color4: "#3ecfa8"
                property string color5: "#c678dd"
                property string color6: "#56b6c2"
                property string color7: "#e6e6e6"
                property string color8: "#5c6370"
                property string color9: "#e06c75"
                property string color10: "#98c379"
                property string color11: "#e5c07b"
                property string color12: "#3ecfa8"
                property string color13: "#c678dd"
                property string color14: "#56b6c2"
                property string color15: "#ffffff"
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: walFile.reload()
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1)
    }

    // ---- Palette as plain data (for the theme recipes) ----
    readonly property var palette: ({
        bg: pal.special.background,
        fg: pal.special.foreground,
        c: [pal.colors.color0, pal.colors.color1, pal.colors.color2, pal.colors.color3,
            pal.colors.color4, pal.colors.color5, pal.colors.color6, pal.colors.color7,
            pal.colors.color8, pal.colors.color9, pal.colors.color10, pal.colors.color11,
            pal.colors.color12, pal.colors.color13, pal.colors.color14, pal.colors.color15]
    })

    // light scheme = pywal generated it with `wal -l` (the background is light)
    readonly property bool light: ThemeLib.lightness(palette.bg) > 0.5

    // the colors of the current theme (see theme/themes.js)
    readonly property var scheme: ThemeLib.compute(palette, Appearance.theme, light)

    // the same recipe applied to any theme, to draw the previews in the selector
    function preview(id) { return ThemeLib.compute(palette, id, light) }

    // ---- Semantic colors ----
    readonly property color background:  scheme.background
    readonly property color foreground:  scheme.foreground
    readonly property color accent:      scheme.accent
    readonly property color note:        scheme.note      // days with notes
    readonly property color muted:       scheme.muted
    readonly property color danger:      scheme.danger

    readonly property color island:       scheme.island
    readonly property color islandHover:  scheme.islandHover
    readonly property color surfaceSoft:  scheme.surfaceSoft
    readonly property color border:       scheme.border

    // veil over cover art and wallpapers so the text stays readable
    // (dark in dark mode, light in light mode)
    readonly property color scrim: Qt.rgba(island.r, island.g, island.b, 0.58)

    // ---- Dimensioni ----
    readonly property int islandHeight: 34
    readonly property int gap:          8
    readonly property int padding:      14
    readonly property int topMargin:    6
    readonly property int weekStart:    Settings.weekStart   // 1 = Monday, 0 = Sunday (Settings > Bar)

    // ---- Font ----
    readonly property string fontFamily: Qt.application.font.family
    readonly property int    fontSize:   13
}
