pragma Singleton
import QtQuick
import qs.services

// The colours of the lockscreen. They follow the active shell theme, the same
// way the bar does: pick Leo/need and the lock goes blue, pick "Wallpaper
// (matugen)" and it wears the wallpaper's colours. The shape is still the
// Project Sekai gacha screen it's modelled on: a soft accent (the selected
// tab, the Unlock pill), a candy second accent (callout bubble, small tags), a
// translucent slate panel, and a glow around the big title type.
//
// Every colour is worked out from the theme's palette roles (services/
// ThemeService.qml) — nothing here is a fixed hex any more, except that
// Virtual Singer pins its two accents (lockMint / lockPink) to the original
// mint and candy pink, so the default look is the one you already know.
//
//   accent  <- B (softened)          candy  <- A (softened)
//   panel, caps, well, dividers <- border      glow, text tint <- glint
//   pill    <- B (nearly white)      shadows, scrims <- border / deep
//
// Kept out of Theme.qml on purpose (same idea as ScrapbookTheme.qml) — nothing
// here should leak into the bar. Auto-registered like Theme.qml: a pragma
// Singleton at the config's root, used everywhere as `LockPalette.foo`.
QtObject {
    id: root

    // ThemeService.lockPalette is the shell palette, except with the matugen theme
    // and a separate lockscreen wallpaper, where it is matugen's colours for that
    // wallpaper (ThemeService.qml, "matugen, for the lockscreen's own wallpaper").
    readonly property var p: ThemeService.lockPalette

    // ===== the theme's roles, as colours =====
    readonly property color cBorder: Qt.color(p.border)
    readonly property color cA: Qt.color(p.A)
    readonly property color cB: Qt.color(p.B)
    readonly property color cDeep: Qt.color(p.deep)
    readonly property color cRim: Qt.color(p.rimHi)
    readonly property color cGlint: Qt.color(p.glint)
    readonly property color cWall: Qt.color(p.wallMid)

    // ===== little helpers =====
    function hue(c) { return c.hslHue < 0 ? 0 : c.hslHue }
    // A grey has no hue (hue() gives 0 = red), so with a fixed saturation these
    // colours would turn pink. The Monochrome theme drops the saturation to 0.
    function hsl(h, s, l, a) { return Qt.hsla(h, (p && p.mono === true) ? 0 : Math.max(0, Math.min(1, s)), Math.max(0, Math.min(1, l)), a === undefined ? 1 : a) }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // ===== accents =====
    readonly property color mint: p.lockMint !== undefined ? Qt.color(p.lockMint)         // the selected tab, the Unlock pill, the AM/PM tag
                                : hsl(hue(cB), Math.min(cB.hslSaturation, 0.75), 0.72)
    readonly property color mintDeep: hsl(hue(mint), 0.6, 0.52)                            // halftone dots on the mint tab
    readonly property color pink: p.lockPink !== undefined ? Qt.color(p.lockPink)          // callout bubble, small tags
                                : hsl(hue(cA), Math.min(cA.hslSaturation, 0.95), 0.73)
    readonly property color paper: hsl(hue(cB), 0.6, 0.99)                                 // the white pill

    // ===== slate parts =====
    readonly property color panel: alpha(Qt.darker(cBorder, 1.15), 0.85)                   // the side panel (85%)
    readonly property color panelEdge: alpha(cRim, 0.4)                                    // its faint lighter rim
    readonly property color divider: alpha(cBorder, 0.5)                                   // dotted rules between rows
    readonly property color cap: alpha(Qt.darker(cBorder, 1.2), 0.85)                      // dark capsules (battery, "locked since")
    readonly property color well: Qt.darker(cBorder, 1.35)                                 // the dark inset inside a pill (dots live here)

    // ===== glow and text =====
    readonly property color periwinkle: cGlint                                             // glow around the big type
    readonly property color band: hsl(hue(cGlint), Math.min(cGlint.hslSaturation, 0.6), 0.62, 0.55)  // the band behind the date line
    readonly property color bandClear: alpha(band, 0)                                      // ...fading out to the right
    readonly property color lavenderText: hsl(hue(cGlint), 0.8, 0.89)                      // soft secondary text on the panel

    readonly property color shadow: alpha(cDeep, 0.25)                                     // soft flat shadow under pills

    // ===== behind everything =====
    readonly property color scrimBase: Qt.darker(cBorder, 1.45)
    readonly property color scrimTop: alpha(scrimBase, 0.1)
    readonly property color scrimClear: alpha(scrimBase, 0)
    readonly property color scrimBottom: alpha(scrimBase, 0.6)

    // The wash under the wallpaper, in case there is none yet.
    readonly property color fallbackTop: Qt.lighter(cWall, 1.1)
    readonly property color fallbackBottom: Qt.darker(cBorder, 1.6)

    // The little twinkles drifting over the wallpaper (every third one).
    readonly property color sparkle: hsl(hue(cA), 1, 0.94)

    // ===== the Calendar lockscreen (LockCalendar.qml) =====
    // The shell's own blocks (outline, white ring, hard shadow: LockPlate.qml) in the
    // THEME's colours: the outline, shadow and text are the border colour (cBorder), the
    // plates are white (`paper` above) or one of three inks worked out like the rest of
    // this file -- the candy pink (A) for weekends and the main alerts, the mint (B) for
    // today and the Enter key, and a lilac from the glint -- on a pale tint of the theme
    // for the sheet. A theme change (or the matugen wallpaper theme) recolours all of it.
    readonly property color calPaper: hsl(hue(cGlint), 0.45, 0.91)                         // the sheet behind the plates
    readonly property color calAccent: hsl(hue(pink), Math.max(0.7, Math.min(1, pink.hslSaturation)), 0.58)
    readonly property color calMint: hsl(hue(mint), Math.max(0.6, Math.min(1, mint.hslSaturation)), 0.66)
    readonly property color calLilac: hsl(hue(cGlint), 0.75, 0.74)
    readonly property color calMuted: alpha(cBorder, 0.7)                                  // small captions
}
