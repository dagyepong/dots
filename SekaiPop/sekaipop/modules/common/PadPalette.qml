pragma Singleton
import QtQuick
import qs.services

// The colours of the Sekai Pad, the equalizer's handheld console
// (modules/sekai/equalizer/*). They follow the active shell theme the same way
// LockPalette.qml does: pick Leo/need and the console goes blue, pick "Wallpaper
// (matugen)" and it wears the wallpaper's colours (also Monochrome and the
// Palette tool's custom theme, since all of them come through ThemeService.palette).
//
// Nothing here is a fixed hex any more. Every colour is a hue taken from the theme
// plus a saturation and a lightness, so the console keeps the same light and shade
// whatever the theme is. The numbers were fitted to the Virtual Singer palette, so
// the default look is the teal console with the indigo screen it always was:
//
//   the shell (plastic, wall, cavity, sockets)   <- hue of A (the main accent)
//   the screen, bezel, keys, d-pad, wheel, pearl <- hue of border (the dark tone)
//   the lit gradient (AUTO, VOL, curve, chips)   <- B -> a softened A
//   bass / mids / treble, the dome keys, the LED <- A turned round the colour wheel
//                                                   (so the three groups stay apart)
//
// The console is a physical object, so it does not follow Light / Dark / Darker,
// only the theme. Kept out of Theme.qml on purpose (same idea as LockPalette.qml):
// nothing here should leak into the bar. Auto-registered like Theme.qml: a pragma
// Singleton in modules/common, used as `PadPalette.foo`.
QtObject {
    id: root

    readonly property var p: ThemeService.palette
    readonly property bool mono: p.mono === true

    readonly property color cA: Qt.color(p.A)
    readonly property color cB: Qt.color(p.B)
    readonly property color cBorder: Qt.color(p.border)

    // ===== little helpers =====
    function clamp(v) { return Math.max(0, Math.min(1, v)) }
    function wrap(h) { const r = h % 1; return r < 0 ? r + 1 : r }
    // A grey has no hue (hslHue gives -1), and Monochrome has no saturation at all.
    function hue(c) { return c.hslHue < 0 ? 0 : c.hslHue }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function hsl(h, s, l, a) { return Qt.hsla(wrap(h), root.mono ? 0 : clamp(s), clamp(l), a === undefined ? 1 : a) }

    readonly property real hA: hue(cA)
    readonly property real hS: hue(cBorder)

    // How much colour the theme's accent carries (a wallpaper that is nearly grey
    // gives a nearly grey console). The group colours keep a floor, because the
    // three lane groups must still be told apart.
    readonly property real chroma: Math.max(0.1, Math.min(1, cA.hslSaturation / 0.85))
    readonly property real gChroma: Math.max(0.4, chroma)

    function lin(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    function lum(c) { return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b) }
    function contrast(a, b) { return (Math.max(lum(a), lum(b)) + 0.05) / (Math.min(lum(a), lum(b)) + 0.05) }
    // `c`, made lighter until the dark ink reads on it.
    function readable(c) {
        let k = c
        for (let i = 0; i < 24 && contrast(k, root.ink) < 4.5; i++)
            k = Qt.hsla(hue(k), k.hslSaturation, Math.min(0.97, k.hslLightness + 0.03), c.a)
        return k
    }

    // `c`, made darker until it reads on `bg` (as far as it can).
    function deepen(c, bg) {
        let k = c
        for (let i = 0; i < 14 && contrast(k, bg) < 4.5 && k.hslLightness > 0.04; i++)
            k = Qt.hsla(hue(k), k.hslSaturation, Math.max(0.02, k.hslLightness - 0.02), c.a)
        return k
    }

    // `off` is degrees from the theme's hue.
    function sh(off, s, l, a) { return hsl(hA + off / 360, s * chroma, l, a) }      // shell tones
    function st(off, s, l, a) { return hsl(hS + off / 360, s * chroma, l, a) }      // stage / navy tones
    function gr(off, s, l, a) { return hsl(hA + off / 360, s * gChroma, l, a) }     // group tones

    // ===== the shell =====
    readonly property color faceLight: sh(-1, 0.75, 0.70)
    readonly property color faceMid: sh(7, 0.62, 0.53)
    readonly property color faceDark: sh(12, 0.71, 0.43)
    readonly property color wallFar: sh(9, 0.62, 0.48)
    readonly property color wallNear: sh(26, 0.79, 0.15)
    readonly property color rim: sh(-4, 1.0, 0.89)
    readonly property color deskShadow: sh(37, 0.82, 0.11)         // used at 4.5 %
    readonly property color shadeBottom: sh(24, 1.0, 0.18)         // used at 42 %
    readonly property color edgeDark: sh(26, 0.80, 0.20)           // used at 45 %
    readonly property color grille: sh(26, 1.0, 0.16)              // used at 18 %
    readonly property color grilleHole: sh(30, 1.0, 0.14)          // used at 75 %
    // The text printed on the shell (SELECT BAND, the key legend, SEKAI-EQ): dark when
    // that reads on the plastic (it does in the default look), light on a shell too
    // dark for it (a deep blue is), with the embossing in the opposite tone.
    readonly property color labelDark: deepen(sh(20, 0.88, 0.20), faceMid)
    readonly property color labelLight: sh(-4, 1.0, 0.92)
    readonly property bool labelIsLight: contrast(labelDark, faceMid) < 4.5 && contrast(labelLight, faceMid) > contrast(labelDark, faceMid)
    readonly property color label: labelIsLight ? labelLight : labelDark
    readonly property color labelEmboss: labelIsLight ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(1, 1, 1, 0.5)
    // the print is faint on purpose (65 %); on a shell where it reads less well it is printed bolder
    readonly property bool labelWeak: contrast(label, faceMid) < 4.5
    readonly property real labelOpacity: labelWeak ? 0.9 : 0.65
    readonly property real titleOpacity: labelWeak ? 0.9 : 0.7

    readonly property color cavityTop: sh(16, 0.82, 0.25)
    readonly property color cavityBottom: sh(14, 0.72, 0.39)
    readonly property color cavityEdge: sh(12, 0.74, 0.69)
    readonly property color socketTop: sh(16, 0.81, 0.25)
    readonly property color socketBottom: sh(14, 0.70, 0.41)
    readonly property color socketEdge: sh(11, 0.72, 0.65)
    readonly property color dpadSocket: sh(15, 0.74, 0.32)
    readonly property color dpadGlow: sh(9, 0.80, 0.75)            // used at 50 %

    // ===== the lit gradient (AUTO, VOL, the curve, chips, the cartridge's label) =====
    // Dark text sits on it (the AUTO key, the chips, the cartridge's label), so a stop
    // that is too dark for that (a blue is, at the same lightness) is lifted until the
    // text reads: 4.5 : 1. The default Virtual Singer colours are already past that.
    readonly property color ink: sh(24, 0.71, 0.13)                // dark text on the lit gradient
    readonly property color litA: readable(cB)
    readonly property color litB: readable(sh(11, 0.71, 0.59))

    // ===== the screen =====
    readonly property color stageTop: st(5, 0.54, 0.29)
    readonly property color stageMid: st(-5, 0.56, 0.21)
    readonly property color stageBottom: st(-6, 0.62, 0.10)
    readonly property color barBg: st(-2, 0.68, 0.06, 0.62)        // the bar along the top
    readonly property color sheetBg: st(-2, 0.76, 0.13, 0.99)      // the pages over the chart
    readonly property color bubbleBg: st(-4, 0.63, 0.07, 0.92)     // the readout bubble

    // ===== bezel and slot =====
    readonly property color bezelTop: st(-11, 0.31, 0.24)
    readonly property color bezelBottom: st(-5, 0.62, 0.06)
    readonly property color slotTop: st(-5, 0.68, 0.06)
    readonly property color slotBottom: st(-8, 0.49, 0.15)

    // ===== soft-touch navy keys (MEDIA key, the d-pad) =====
    readonly property color keyTop: st(-11, 0.32, 0.43)
    readonly property color keyHover: st(-10, 0.32, 0.49)
    readonly property color keyBottom: st(-9, 0.45, 0.19)
    readonly property color keyWall: st(-7, 0.57, 0.12)
    readonly property color keyText: st(-11, 1.0, 0.94)
    readonly property color dpadWallDark: st(-10, 0.49, 0.12)
    readonly property color dpadWallLight: st(-10, 0.36, 0.25)
    readonly property color dishTop: st(-11, 0.30, 0.51)
    readonly property color dishBottom: st(-10, 0.48, 0.12)
    readonly property color arrow: st(-12, 1.0, 0.89)

    // ===== the wheel =====
    readonly property color wheelBase: st(-13, 0.20, 0.36)
    readonly property color wheelRib: st(-16, 0.31, 0.79)
    readonly property color wheelWallLight: st(-12, 0.17, 0.51)
    readonly property color wheelWallDark: st(-11, 0.31, 0.24)

    // ===== pearl plastic (shoulder keys, the cartridge) =====
    readonly property color pearl: "#ffffff"
    readonly property color pearlMid: st(-19, 0.56, 0.94)
    readonly property color pearlShade: st(-18, 0.42, 0.85)
    readonly property color pearlWallLight: st(-17, 0.32, 0.77)
    readonly property color pearlWallDark: st(-16, 0.20, 0.52)
    readonly property color pearlText: st(-13, 0.38, 0.27)
    readonly property color cartLabel: sh(13, 0.47, 0.97)
    readonly property color cartInk: st(-15, 0.51, 0.23)
    readonly property color cartGrip: st(-16, 0.23, 0.64)
    readonly property color cartWallLight: st(-17, 0.29, 0.75)
    readonly property color cartWallDark: st(-17, 0.19, 0.52)
    readonly property color cartEdgeLight: st(-18, 0.33, 0.84)
    readonly property color cartBright: st(-19, 0.64, 0.98)
    readonly property color cartSoft: st(-18, 0.51, 0.93)
    readonly property color cartEdgeDark: st(-17, 0.31, 0.79)

    // ===== screws =====
    readonly property color screwLight: st(-30, 0.27, 0.70)
    readonly property color screwDark: st(-31, 0.20, 0.50)

    // ===== bass, mids, treble =====
    // The theme's accent turned round the colour wheel: mids on the accent itself,
    // bass 156 degrees round, treble 85. In Monochrome (no hue) they are told apart
    // by lightness instead.
    readonly property color bass: gr(156, 1.0, mono ? 0.88 : 0.81)
    readonly property color bassLight: gr(156, 1.0, mono ? 0.95 : 0.88)
    readonly property color bassDark: gr(158, 1.0, mono ? 0.78 : 0.75)
    readonly property color mids: gr(11, 0.75, mono ? 0.66 : 0.75)
    readonly property color midsLight: gr(13, 0.86, mono ? 0.80 : 0.86)
    readonly property color midsDark: gr(14, 0.71, mono ? 0.46 : 0.54)
    readonly property color treble: gr(85, 0.46, mono ? 0.50 : 0.74)
    readonly property color trebleLight: gr(79, 0.87, mono ? 0.62 : 0.88)
    readonly property color trebleDark: gr(79, 0.57, mono ? 0.38 : 0.64)

    readonly property var groups: [bass, mids, treble]
    readonly property var groupsLight: [bassLight, midsLight, trebleLight]
    readonly property var groupsDark: [bassDark, midsDark, trebleDark]

    // the pearl line along the bottom of the shell: bass -> a pale warm tone -> mint
    readonly property color lineMid: gr(-131, 1.0, 0.83)
    readonly property color lineEnd: gr(-7, 0.86, 0.73)

    // ===== the dome keys and the LED =====
    readonly property color domeAuto: mids
    readonly property color domeAutoWall: gr(15, 0.61, 0.45)
    readonly property color domeSave: bass
    readonly property color domeSaveWall: gr(155, 0.51, 0.56)
    readonly property color domeUndo: gr(-128, 1.0, mono ? 0.78 : 0.70)
    readonly property color domeUndoWall: gr(-130, 0.79, mono ? 0.52 : 0.41)
    readonly property color domeSaveAs: st(-13, 1.0, 0.98)
    readonly property color domeSaveAsWall: st(-13, 0.28, 0.66)
    readonly property color ledOn: gr(157, 1.0, mono ? 0.95 : 0.69)
    readonly property color ledOff: gr(152, 0.19, 0.40)
    readonly property color warn: bass                              // the "!" badge, a note to act on
}
