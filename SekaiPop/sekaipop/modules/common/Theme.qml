pragma Singleton
import QtQuick
import qs.services

// Palette + sizing pulled straight from the Figma file. Workspace
// badge colors live in the real SVG exports now (assets/workspace-
// active-*.svg), not here — everything else that still needs QML
// styling (Active Window, Media, Weather, Clock) reads from this.
QtObject {
    id: theme

    // The group colours follow the active theme (services/ThemeService.qml:
    // Virtual Singer's navy / cyan / mint by default; Ctrl+Shift+T picks
    // another group). The names stay "accentCyan" / "accentMint" — they're
    // just the two stops of the accent gradient, whatever colour that is.
    readonly property var pal: ThemeService.palette

    // True for the Monochrome theme: the decorative pastels below turn into greys.
    readonly property bool mono: pal.mono === true

    readonly property color colBorder: pal.border  // outline / shadow / dark text
    readonly property color colBg: "#ffffff"
    readonly property color accentCyan: pal.A
    readonly property color accentMint: pal.B
    readonly property color textWhite: "#ffffff"

    // ===== Modes =====
    readonly property string mode: ThemeService.mode
    readonly property bool dark: ThemeService.dark          // true for dark AND darker
    readonly property bool darker: ThemeService.darker

    // Light mode: how much of the theme's border colour stays in the border
    // and in the drop shadow (0 = white, 1 = the full navy). Lower = lighter.
    // Pixels one mouse-wheel notch scrolls any list in the shell (WheelScroll.qml).
    readonly property real wheelStep: 110

    // How far one wheel event should move a list, in px: a mouse notch is
    // `wheelStep`, a touchpad follows the fingers 1:1. Every scrolling area in
    // the shell takes its distance from here, so none feels faster or slower
    // than the rest. `sideways` is for horizontal rows: it takes whichever of
    // the two axes moved more (a plain wheel is vertical, shift+wheel or a
    // two-finger swipe can be horizontal).
    function wheelPx(event, sideways) {
        const pd = event.pixelDelta
        const ad = event.angleDelta
        if (sideways) {
            if (pd.x !== 0 || pd.y !== 0)
                return Math.abs(pd.x) > Math.abs(pd.y) ? pd.x : pd.y
            return (Math.abs(ad.x) > Math.abs(ad.y) ? ad.x : ad.y) / 120 * wheelStep
        }
        return pd.y !== 0 ? pd.y : ad.y / 120 * wheelStep
    }
    readonly property real lightLineAlpha: 0.42
    readonly property real lightShadowAlpha: 0.30
    // Light mode: how much navy stays in the fill of the chips (weather, clock ...).
    readonly property real lightChipAlpha: 0.14
    // Dark mode: how much theme colour tints the white inner ring (0 = pure white).
    readonly property real darkRingTint: 0.08
    // Dark mode: how much darker the drop shadow is than the navy border.
    readonly property real darkShadowFactor: 1.3
    // Darker mode: how dark the surface goes (Qt.darker factor on the
    // palette's dark tone), how much darker than the navy the border and the
    // drop shadow are, and how bright the (grey, not white) inner ring is.
    readonly property real darkerFactor: 1.4
    readonly property real darkerLineFactor: 1.35
    readonly property real darkerShadowFactor: 1.8
    readonly property real darkerRingLift: 2.0

    // The dark surface is the palette's own dark tone, one step lighter, so
    // every group theme (and matugen) gets its own tint of dark. Darker goes
    // the other way, below the palette's dark tone.
    readonly property color surface: darker
        ? Qt.darker(Qt.color(pal.deep), darkerFactor)
        : (dark ? Qt.lighter(Qt.color(pal.deep), 1.18) : "#ffffff")
    readonly property color surfaceHover: dark ? Qt.lighter(surface, 1.35) : "#f2f2f2"
    readonly property color surfaceDivider: dark ? Qt.lighter(surface, 1.75) : pal.divider
    // The INNER rings. Dark: white. Darker: a dim grey. Light: as always.
    readonly property color ringWhite: darker
        ? Qt.lighter(surface, darkerRingLift)
        : (dark ? Qt.tint(Qt.color("#ffffff"), Qt.rgba(colBorder.r, colBorder.g, colBorder.b, darkRingTint)) : "#ffffff")   // the gap ring inside a Pill
    // The flat cards (the bar's popups, the launcher's search pill and results)
    // keep their outline and fill; in Dark and Darker they also get an inner
    // ring just inside the outline, in `ringWhite` (white in Dark, the dim grey
    // in Darker), the same outline -> ring -> fill look as the bar's pills. It
    // is drawn over the edge of the fill, so no card changes size. Light mode
    // has none (a white ring on a white card would not show).
    readonly property real cardRing: dark ? borderWidth : 0
    readonly property color surfaceRing: darker
        ? Qt.lighter(surface, darkerRingLift * 0.8)
        : (dark ? Qt.tint(Qt.color("#ffffff"), Qt.rgba(colBorder.r, colBorder.g, colBorder.b, darkRingTint + 0.1)) : "#d9d9d9")   // the bar / dock inner ring
    readonly property color surfaceTint: dark
        ? Qt.tint(surface, Qt.rgba(accentCyan.r, accentCyan.g, accentCyan.b, 0.2))
        : pal.hoverTint                                                                // hover wash
    readonly property color ink: dark ? Qt.color(pal.divider) : pal.border             // text and icons on a surface
    readonly property color inkSub: Qt.rgba(ink.r, ink.g, ink.b, 0.667)
    // The launcher / overview's warm paper tones, and their dark stand-ins.
    readonly property color paper: dark ? Qt.lighter(surface, 1.28) : "#f5f1e6"
    readonly property color paperHover: dark ? Qt.lighter(surface, 1.6) : "#ece6d4"
    readonly property color paperEdge: dark ? Qt.lighter(surface, 1.9) : "#e4dcc6"

    // The OUTER border of every Pill, dialog and card edge.
    readonly property color line: darker
        ? Qt.darker(colBorder, darkerLineFactor)                                      // darker than the navy
        : (dark
            ? Qt.color(colBorder)                                                     // the theme's navy
            : Qt.tint(Qt.color("#ffffff"), Qt.rgba(colBorder.r, colBorder.g, colBorder.b, lightLineAlpha)))  // soft, light border

    // The hard drop shadow under them, kept apart from the border.
    readonly property color lineShadow: darker
        ? Qt.darker(colBorder, darkerShadowFactor)
        : (dark
            ? Qt.darker(colBorder, darkShadowFactor)
            : Qt.tint(Qt.color("#ffffff"), Qt.rgba(colBorder.r, colBorder.g, colBorder.b, lightShadowAlpha)))  // soft, light shadow

    // The filled "chips" of the bar and the popups (weather, clock, date,
    // tray, battery, nav buttons ...). They were navy with white ink in every
    // mode; now Light gets a pale fill with navy ink, Dark keeps the navy
    // with white ink, and Darker goes darker than the navy.
    readonly property color chipFill: darker
        ? Qt.darker(colBorder, darkerLineFactor)
        : (dark ? Qt.color(colBorder) : Qt.tint(Qt.color("#ffffff"), Qt.rgba(colBorder.r, colBorder.g, colBorder.b, lightChipAlpha)))
    readonly property color chipInk: dark ? textWhite : Qt.color(colBorder)

    // The tint behind dialogs / the power menu: the palette's dark tone in
    // Dark and Darker, a pale wash in Light.
    readonly property color scrim: dark
        ? Qt.color(pal.deep)
        : Qt.tint(Qt.color("#ffffff"), Qt.rgba(colBorder.r, colBorder.g, colBorder.b, 0.10))

    // ===== Classic panel look =====
    readonly property bool classic: dark && !darker
    readonly property color pSurface: classic ? colBg : surface
    readonly property color pSurfaceHover: classic ? colHover : surfaceHover
    readonly property color pSurfaceDivider: classic ? colDivider : surfaceDivider
    readonly property color pSurfaceRing: classic ? colOuterRing : surfaceRing
    readonly property color pRingWhite: classic ? Qt.color("#ffffff") : ringWhite
    readonly property color pLine: classic ? colBorder : line
    readonly property color pLineShadow: classic ? colBorder : lineShadow
    readonly property color pInk: classic ? colBorder : ink
    readonly property color pInkSub: classic ? colSubText : inkSub

    // Shared pieces (Pill, MaterialIcon, QuickToggle) are also used by the
    // bar, so they can't just switch. They ask this instead: is `item`
    // inside something that sets `classicPanel: true` (QuickPanelFace's
    // root, the To-Do card)? Only then, and only in classic mode, they use
    // the classic colours.
    function classicFor(item) {
        if (!classic)
            return false
        for (let p = item; p; p = p.parent)
            if (p.classicPanel === true)
                return true
        return false
    }

    // Other colours that used to be hard-coded navy / teal in a few files
    // and now follow the theme too.
    readonly property color colDeep: pal.deep            // dialog + scrim background (was #232235)
    readonly property color colHoverTint: pal.hoverTint  // pale hover wash on white buttons (was #d9fff6)

    // The phone mock-up's plastics (PhoneBody.qml).
    readonly property color phoneRimHighlight: pal.rimHi
    readonly property color phoneBezel: pal.bezel
    // Phone glass geometry: the one place the rim + bezel thickness lives, so
    // PhoneBody and every dimming scrim that has to cover exactly the visible
    // glass stay in step when the bezel is retuned.
    readonly property real phoneRimWidth: 10
    readonly property real phoneBezelWidth: 9
    readonly property real phoneScreenInset: phoneRimWidth + phoneBezelWidth
    readonly property real phoneCornerRadius: 100
    readonly property color phoneWallLight: pal.wallLight
    readonly property color phoneWallMid: pal.wallMid
    readonly property color phoneWallDark: pal.wallDark
    readonly property color phoneHardware: pal.hardware
    readonly property color phoneLens: pal.lens
    readonly property color phoneLensGlint: pal.glint

    // The five Project Sekai card attributes — Cool, Cute, Happy,
    // Mysterious, Pure — as the pastel fills of the attribute icons. Used
    // wherever something wants a friendly rotating palette (the lockscreen's
    // password dots).
    // Monochrome swaps them for five greys, light and dark taking turns so two
    // neighbours (the workspace badges, the lock dots) still read as different.
    readonly property var attributeColors: mono
        ? ["#e4e4e4", "#b0b0b0", "#f6f6f6", "#8c8c8c", "#cecece"]
        : ["#8EE3EF", "#FF9ECB", "#FFE066", "#B39DDB", "#A5E6A5"]

    readonly property int pillHeight: 36
    readonly property int radiusOuter: 13
    readonly property int radiusBadge: 15
    readonly property int borderWidth: 3
    // The white line between a block's navy outline and its colour (a Pill's ring on the
    // desktop cards' keys and digit blocks), and the white ring inside a sticker text's navy
    // outline (StickerText). It is the clock's digit blocks' line (the clock is the reference,
    // so it is left exactly as it was). ONE number, so they all match:
    // a block's ringWidth is borderWidth + whiteLine. The card housing's wide pale ring
    // (outerRingWidth) and Dark mode's inner ring (cardRing) are different things, not this.
    readonly property real whiteLine: 2
    readonly property int shadowOffset: 4

    // The Quick Panel phone in its flat (2D) look: Settings -> Quick -> Quick Panel phone, and
    // always while Game Mode is on (GameModeService.qml), whatever that says.
    // The phone faces straight on with no side wall, and its buttons, cards and dialogs drop
    // their hard shadow straight down (like the bar's pills) instead of down and to the right.
    readonly property bool quickFlat: SettingsService.flag("quick.flat") || GameModeService.enabled

    // A standing bar (on the left or right edge): how wide the bar body
    // is, and how wide its pills are. The pills are a bit narrower than
    // the body, the same way they sit inside the flat bar's height.
    readonly property int barVBody: 72
    readonly property int barVPillWidth: 52

    // The pale ring between the navy outline and the white fill on the
    // bar's own background (Status_Bar.qml's bgFace/bgFill) — sampled
    // from the old status_Bar_BG.png export. Hoisted here (rather than
    // staying a Status_Bar-local property) so any other outer housing
    // that wants the bar's exact look — see Dock.qml's dockPill — can
    // share the same two values instead of re-guessing them.
    readonly property color colOuterRing: "#d9d9d9"
    readonly property int outerRingWidth: 4

    // Float bar style: how far the bar is inset from the left and right
    // screen edges. It's the same gap the bar keeps between its own edge
    // and the workspace badges (Status_Bar.qml's content margins), so the
    // space outside the workspaces reads the same on both sides of the
    // bar's outline. Change it here to make the Float bar wider/narrower.
    readonly property int barFloatInset: 16

    // ===== Capsule bar style (BarStyleService "capsule") =====
    // The slim bar and its pills, measured off the reference screenshot (design px):
    //   bar      36 tall = 3 rim + 30 body + 3 rim, a hard shadow 3 px below it,
    //            fully rounded; the strip reserved for it is 8 + 39 + 8
    //   dots     workspaces: 12 fill + 3 ring = 18 across, the active one 28 + 6 = 34 wide
    //   chips    every other pill: flat, 21 tall, no outline, ring or shadow
    //   spacing  6 between neighbours, 6 above / below and 7 beside the pills
    readonly property real capBarHeight: 39        // bar + its hard shadow
    readonly property real capBarFace: 36          // the rimmed bar without its shadow
    readonly property real capRimWidth: 3
    readonly property real capShadowDy: 3
    readonly property real capEdgeGap: 8           // between the bar and the screen edge
    readonly property real capStrip: 55            // what the bar reserves: 8 + 39 + 8
    readonly property real capPadX: 7
    readonly property real capGap: 6
    readonly property real capDotFill: 12
    readonly property real capDotRing: 3
    readonly property real capDot: capDotFill + 2 * capDotRing              // 18
    readonly property real capDotActive: 28 + 2 * capDotRing                // 34
    readonly property real capChipHeight: 21
    readonly property real capClockSize: 14        // the clock chip's digits

    // The same bar standing on the left / right edge. Its chips are 40 wide (what the
    // stacked two-line texts need), with 5 px between the chip and the rim; the first and
    // last chip keep 8 px from the rim along the bar (a full 40 px chip then still sits
    // inside the rounded end). Body = 50, face = 56, the strip reserved = 8 + 56 + 8 = 72.
    readonly property real capVChip: 40
    readonly property real capVPadX: 5
    readonly property real capVPadY: 8
    readonly property real capVBarFace: capVChip + 2 * (capRimWidth + capVPadX)   // 56
    readonly property real capStripV: capEdgeGap * 2 + capVBarFace                // 72

    // The colours come from the theme's own surface, so every group theme and
    // matugen gets its tint of the capsule: rim = body x 1.87, shadow = body x 1.42
    // (the reference's #2e233f / #564078 / #42315c are exactly those ratios). Light
    // mode has no dark body to lift, so it uses the light outline + shadow tones.
    readonly property color capBody: dark ? surface : Qt.color("#ffffff")
    readonly property color capRim: dark ? Qt.lighter(surface, 1.87) : line
    readonly property color capShade: dark ? Qt.lighter(surface, 1.42) : lineShadow
    readonly property color capChip: capRim
    readonly property color capInk: dark ? textWhite : Qt.color(colBorder)
    // One fixed pastel per workspace, wrapping round after the fifth.
    // What the Capsule bar and dock light up with, from the active theme (a group palette or
    // matugen), so they re-colour with it: `capLit` is the lit key / the focused app's dot,
    // `capLitSoft` the running app's dot.
    readonly property color capLit: accentCyan
    readonly property color capLitSoft: Qt.color(pal.glint)
    // The workspace dots of the Capsule bar: one colour each. The lit colour first, then the
    // soft one, the second accent stop and the palette's light wall and pale divider tones,
    // so five neighbours stay apart even in a theme whose two accents are close.
    readonly property var capWsColors: mono
        ? attributeColors.map(c => Qt.color(c))
        : [capLit, capLitSoft, accentMint, Qt.color(pal.wallLight), Qt.color(pal.divider)]

    // Is `item` inside a bar drawn in the Capsule style (on any edge)? Status_Bar.qml sets
    // `capsuleBar` while that style is up; Pill, MaterialIcon and the workspace
    // badges ask this (the same way classicFor() finds `classicPanel`) and redraw
    // themselves as flat chips / small icons / dots. Nothing outside the bar sets it.
    function capsuleFor(item) {
        for (let p = item; p; p = p.parent)
            if (p.capsuleBar === true)
                return true
        return false
    }

    // ...and is that bar standing on the left / right edge? (Status_Bar.qml sets
    // `capsuleVertical` next to `capsuleBar`.)
    function capsuleVerticalFor(item) {
        for (let p = item; p; p = p.parent)
            if (p.capsuleBar === true)
                return p.capsuleVertical === true
        return false
    }

    // Fixed three-colour motif for the sekaiIris wallpaper-transition
    // shader specifically — white/pink/green, independent of whatever
    // accentCyan/accentMint the active group theme is using, since the
    // iris wipe is meant to read the same regardless of which group's
    // colours are active elsewhere in the shell. See
    // shaders/sekai_iris.frag for how the three are laid out.
    readonly property color irisColorWhite: "#ffffff"
    readonly property color irisColorPink: "#ff8fd6"
    readonly property color irisColorGreen: "#00ffcb"

    // ===== wallpaper-transition colours =====
    // The motif every wallpaper transition paints with (ring, star, blocks,
    // iris). Settings -> Desktop -> Wallpaper -> "Transition colours":
    //   Theme    follows the active theme: a group palette, or the wallpaper's
    //            own colours with "Wallpaper (matugen)"
    //   Classic  the fixed white / pink / cyan above
    // Virtual Singer (the default theme) always gives the classic three, so
    // the look you know is the look it keeps. Pass the palette to wear:
    // ThemeService.palette for the desktop, ThemeService.lockPalette for the
    // lockscreen. Returns { white, pink, cyan, green } (colours).
    //   cyan, green <- the theme's A       pink <- its B
    //   white       <- white with a faint tint of A
    // Two themes whose A and B are close (Leo/need, Vivid BAD SQUAD...) would
    // give two near-identical bands, so A is deepened (B stays soft, white the
    // lightest) until the bands read as different steps.
    function transitionColors(p) {
        const classic = {
            white: Qt.color(irisColorWhite),
            pink: Qt.color(irisColorPink),
            cyan: Qt.color("#22e6d3"),
            green: Qt.color(irisColorGreen)
        }
        if (!p || !SettingsService.flag("wallpaper.themedTransition"))
            return classic
        const vs = ThemeService.baseGroups[0].c
        if (String(p.A).toLowerCase() === String(vs.A).toLowerCase()
                && String(p.B).toLowerCase() === String(vs.B).toLowerCase())
            return classic

        const a = Qt.color(p.A)
        const b = Qt.color(p.B)
        let cyan = a
        let pink = b
        if (a.hslHue >= 0 && b.hslHue >= 0) {
            const dh = Math.min(Math.abs(a.hslHue - b.hslHue), 1 - Math.abs(a.hslHue - b.hslHue))
            const dl = Math.abs(a.hslLightness - b.hslLightness)
            if (dh < 0.09 && dl < 0.14) {
                // Too close: deepen A (so it is the strong band, B the soft one,
                // white the lightest), or if A is already dark, lighten B.
                if (a.hslLightness > 0.45)
                    cyan = Qt.hsla(a.hslHue, a.hslSaturation, a.hslLightness - 0.10, 1)
                else
                    pink = Qt.hsla(b.hslHue, b.hslSaturation, Math.min(0.9, b.hslLightness + 0.2), 1)
            }
        }
        return {
            white: Qt.tint(Qt.color("#ffffff"), Qt.rgba(a.r, a.g, a.b, 0.1)),
            pink: pink,
            cyan: cyan,
            green: cyan
        }
    }

    // Free since Nov 2025 on Google Fonts (SIL Open Font License) —
    // grab it there and drop the .ttf in ~/.local/share/fonts.
    readonly property string fontFamily: "Google Sans Flex"
    readonly property int fontSize: 16

    // Icons: the Solar Icon Set (assets/icons, SVG), drawn by MaterialIcon.qml
    // with the old Material Symbols names (functions/IconMap.js turns them into
    // Solar files). iconFill restyles every icon at once — 0 = outline,
    // 1 = solid (the Solar "Bold" set). iconWeight only reaches the Material
    // Symbols Rounded font, which is what an icon with no Solar file falls back
    // to (check it is installed with:  fc-list | grep -i "material symbols")
    readonly property string iconFont: "Material Symbols Rounded"
    readonly property real iconFill: 0
    readonly property string iconStyle: SettingsService.get("appearance.iconStyle")
    readonly property real iconWeight: 400
    // The Settings panel's icons are heavier than the rest, so their outlines
    // hold up against the panel's thick borders (outline only: iconFill stays 0).
    readonly property real settingsIconWeight: 600

    // The style every bold text in the shell asks for, next to
    // `font.weight: Font.ExtraBold`. Google Sans Flex is a variable font,
    // and Qt doesn't always pick the instance you want from the weight
    // alone, so the style is named outright. Black was too heavy at the
    // small sizes (the 7-10px pill text clogs up), so this is ExtraBold;
    // try "Bold" for lighter or "Black" for heavier. If the name doesn't
    // exist on your system Qt falls back to the weight, so nothing
    // breaks. See what yours has with:
    //   fc-list "Google Sans Flex" style
    readonly property string fontStyleBold: "ExtraBold"

    // Two-line pills (Media, Active Window): bold first line, lighter
    // second line. A pill with only one line uses the idle size.
    readonly property int fontSizeTitle: 10
    readonly property int fontSizeSub: 7
    readonly property int fontSizeIdle: 12
    // Single-line info pills (Weather, Clock).
    readonly property int fontSizeInfo: 12
    readonly property color colSubText: Qt.rgba(colBorder.r, colBorder.g, colBorder.b, 0.667)   // colBorder at 67%

    // Tray right-click menu (from the Figma frame).
    // How much the Settings' keys, tiles and chips lean (italic slant) on top
    // of the phone's own tilt. 0 = upright, like the Quick Panel's buttons, so
    // they sit in the phone's 2.5D plane exactly; 1 = the original lean.
    readonly property real settingsLean: 0
    readonly property int fontSizeMenu: 14
    readonly property int menuRowHeight: 32
    readonly property color colHover: "#f2f2f2"       // hovered menu row
    readonly property color colDivider: pal.divider   // menu separator line
}
