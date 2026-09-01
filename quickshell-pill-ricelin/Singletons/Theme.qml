pragma Singleton
import QtQuick
import Quickshell

/**
 * Pill palette. Surfaces and text are fixed dark neutrals. Only the accent ramp
 * follows the wallpaper hue written by wallcolors.py.
 */
Singleton {
    readonly property bool dyn: true

    /**
     * Bright accent pop shared by the flame glow, charging glyphs, the unread
     * inbox dot, the calendar's today cell and the held power tile.
     */
    readonly property color onGlow: Dyn.primary

    readonly property color verm:     Qt.darker(Dyn.primary, 1.18)
    readonly property color vermLit:  Dyn.primary
    readonly property color vermDeep: Dyn.primaryContainer
    readonly property color cream:    "#eeeeee"
    readonly property color bright:   "#ffffff"
    readonly property color dim:      "#a7a7a7"
    readonly property color cardTop:  "#101010"
    readonly property color cardBot:  "#101010"
    readonly property color border:   Qt.alpha(cream, 0.14)
    readonly property color shadow:   Qt.rgba(0, 0, 0, 0.58)
    readonly property color tileBg:   "#181818"
    readonly property color subtle:   "#d0d0d0"
    readonly property color faint:    "#777777"
    readonly property color iconDim:  "#b9b9b9"
    readonly property color hair:     Qt.alpha(cream, 0.14)
    readonly property color hairSoft: Qt.alpha(cream, 0.08)
    readonly property color sheen:    Qt.alpha(cream, 0.05)
    readonly property color vermDim:   Qt.darker(Dyn.primary, 1.5)
    readonly property color vermDimDeep: Qt.darker(Dyn.primary, 2.2)
    readonly property color vermBurn:  Qt.darker(Dyn.primaryContainer, 1.1)
    readonly property color tickRest:  "#8a8a8a"
    readonly property color threadBg:  Qt.alpha(cream, 0.12)
    readonly property color flameCore: Qt.lighter(onGlow, 1.03)
    readonly property color flameGlow: onGlow

    /**
     * Flame canvas ramp: literal hex strings (color type won't work), fed
     * directly to Canvas addColorStop/strokeStyle. A color property serializes to
     * #aarrggbb and corrupts the gradient render, so these pass raw hex strings.
     */
    readonly property string flameInk:   Dyn.primary
    readonly property string flameEmber: Dyn.primaryContainer
    readonly property string flameBurn:  Dyn.primaryContainer
    readonly property string flameTip:   Dyn.onPrimaryContainer
    readonly property color todayWarm: onGlow
    readonly property color ghost:     "#252525"
    readonly property color frameBg:      Qt.alpha(cream, 0.055)
    readonly property color frameBorder:  Qt.alpha(cream, 0.12)
    readonly property color creamMenu:     Qt.alpha(cream, 0.84)
    readonly property real pillOpacity: 1.0
    readonly property real shadowOpacity: 0.52
    readonly property var fontFamilies: Qt.fontFamilies()
    readonly property string font: (Flags.uiFont.length > 0 && fontFamilies.indexOf(Flags.uiFont) >= 0) ? Flags.uiFont : "Inter"
    readonly property string fontJp: "Zen Kaku Gothic New"

    /**
     * MPRIS trackArtists arrives as a JS array from some players and as a
     * plain string from others (Spotify); calling join on the string throws
     * and kills the whole binding. Handles both, falls back to trackArtist.
     */
    function joinArtists(artists, single) {
        if (artists && typeof artists.join === "function" && artists.length > 0)
            return artists.join(", ");
        if (artists && String(artists).length > 0)
            return String(artists);
        return single ? String(single) : "";
    }
}
