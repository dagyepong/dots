import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// One button of the Quick Panel, drawn natively on Pill.qml from the
// Figma frames (Wi-Fi ON / Bluetooth OFF / Keep Awake ON Button Min /
// Power OFF Hover / Unhover ...), so it presses exactly like the
// workspace badges and the media pill: it pushes down onto its own hard
// shadow on mouse-down and springs back on release.
//
// Pure UI (no Quickshell imports): QuickPanelFace.qml feeds it state
// through plain properties and turns clicked() into an action.
//
//   kind: "wide"    200x73 pill (or `wideWidth`), icon + two lines of text (Wi-Fi, ...)
//         "round"   74x73 icon-only pill (Keep Awake, Notifications)
//         "square"  73x73, corner radius 30 (Edit, Power in the header)
//
// The two looks, straight from Figma:
//   OFF  white, 3px outline, shadow 3px right / 1px down
//   ON   cyan-mint gradient inside a 9px white ring, 5px outline,
//        shadow 5px right / 2px down
// Switching between them slides everything from one to the other rather
// than snapping. For the header buttons, hoverLights makes hovering show
// the ON look (the "Hover" frames) without changing `on`.
//
// `on` is a live reflection of the real state (owned by QuickSource), so
// when it flips without a click — a mute key, another app toggling
// Bluetooth — the button pulses by itself, the same trick the workspace
// badges, tray button and media pill use.
Item {
    id: root

    property string kind: "wide"
    // How long a "wide" pill is: 200 for the two-column size, more for the
    // long (three-column) one — the text just gets the extra room.
    property real wideWidth: 200
    // Same for the round (icon-only) pill: 74, or wider when its row
    // stretches to fill the panel (see QuickTiles.pack).
    property real roundWidth: 74
    property bool on: false
    property bool hoverLights: false
    property string label: ""
    property string subtitle: ""
    // A Material Symbols Rounded name ("wifi", "lock", ...), not a file.
    property string icon: ""
    // Solid version of the same glyph (Keep Awake uses it for ON).
    property bool iconFilled: false

    // Locks the cap's border/ring/shadow at the same magnitude as the
    // ON look (see shadowLitP below) without touching the ON look's
    // other half — the gradient fill, which still only shows once
    // litP itself says lit. Used by pills that don't have a real
    // on/off state (the Power menu's action rail) but should still
    // read as raised further off the surface, like a lit or hovered
    // tile does.
    property bool elevated: false

    // A further, hover-only push on top of `elevated` — the drop shadow
    // alone grows past even the ON magnitude while the pointer is over
    // the pill, like it lifted off the rail. Border/ring stay put; only
    // shadowDx/shadowDy read this (see below), so hovering doesn't
    // re-trigger the border/ring resize `elevated` already settled.
    property bool hoverElevates: false
    property real hoverShadowExtraX: 6
    property real hoverShadowExtraY: 4

    // Which side of the cap stays put while the other does the moving.
    // false (everywhere but the Power rail): pinned to the left, same as
    // it's always been — the cap's own left edge never moves, growth
    // (the OFF->ON shadow, and hoverElevates on top of it) all spills
    // out to the right. true (the Power rail, see PowerMenu.qml): pinned
    // to the right instead, so a pill popping out — bigger shadow, bigger
    // cap — grows to the left, toward the phone it spilled out of,
    // rather than further out over open space.
    property bool anchorRight: false

    // The Quick Panel's 2D look: the hard shadow drops straight down (dx 0), as on the bar's
    // pills, instead of down and to the right. Same OFF -> ON growth (3 -> 4 down). Set by the
    // owner from Theme.quickFlat; everything outside the Quick Panel leaves it off.
    property bool flatShadow: false

    signal clicked()

    // Right-click, for the two tiles that have more to show than a
    // plain on/off (Network -> a list of nearby Wi-Fi networks,
    // Bluetooth -> paired devices — see NetworkDialog.qml /
    // BluetoothDialog.qml). Left unconnected everywhere else.
    signal rightClicked()

    readonly property bool hovered: area.containsMouse
    readonly property bool lit: on || (hoverLights && hovered)

    // Text / glyph colour: the mode's ink when OFF, the fixed dark ink when
    // the tile is lit (the accent gradient behind it is bright in both modes).
    readonly property color inkNow: Qt.tint(Theme.classicFor(root) ? Theme.pInk : Theme.ink, Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, litP))
    readonly property color inkSubNow: Qt.rgba(inkNow.r, inkNow.g, inkNow.b, 0.667)

    // 0 = OFF look, 1 = ON look; glides between them — the
    // fill/outline/shadow all read litP.
    property real litP: lit ? 1 : 0
    Behavior on litP {
        NumberAnimation {
            duration: 170
            easing.type: Easing.OutCubic
        }
    }

    // The raised cap: wide buttons are 200 either way; the round and
    // square ones are 73 OFF and 74 ON in the Figma frames.
    readonly property real capW: kind === "wide" ? wideWidth : roundWidth - 1 + litP
    readonly property real capH: 73

    // 0 = each line of a wide tile's text takes its font's natural height
    // (what the Quick Panel's tiles do). Set it to squeeze the two lines of
    // a lit tile into the cyan band when the font's lines are tall; the
    // Settings Panel's tiles use 21.
    property real lineHeightPx: 0
    // The two lines of a wide tile, when lineHeightPx is 0: 20 + 17 = 37 px, so
    // they sit centred inside the lit band (the cap is 73 tall, 28 of it ring and
    // outline when lit, which leaves 45) with a few px to spare above and below.
    // With the font's own line height (about 26 each) they filled it edge to edge.
    readonly property real titleLine: 20
    readonly property real subLine: 17

    // Drives border/ring/shadow only. Normally just litP, but `elevated`
    // floors it at the ON magnitude — the container is already sized for
    // litP's max (see implicitWidth/Height below), so this never grows
    // past what they account for.
    readonly property real shadowLitP: elevated ? Math.max(litP, 1) : litP

    // 0 -> 1 while hoverElevates is on and the pointer is actually over
    // the pill; glides like litP so the extra shadow eases in rather
    // than snapping.
    property real hoverBoostP: (hoverElevates && hovered) ? 1 : 0
    Behavior on hoverBoostP {
        NumberAnimation {
            duration: 170
            easing.type: Easing.OutCubic
        }
    }

    // The slot is sized for the ON look (cap + its 5/2 shadow). The
    // pill sits in its bottom-left corner, so the smaller OFF shadow
    // leaves the cap one pixel lower — same as the Figma rows, whose
    // buttons line up along the bottom of their shadows.
    implicitWidth: (kind === "wide" ? wideWidth : roundWidth) + 5
    implicitHeight: flatShadow ? 77 : 75

    // Programmatic press-then-pop for state changes that didn't come
    // from a click on this button.
    property bool keyPulse: false
    // Swallows that pulse for a moment right after THIS button was
    // physically clicked — the real press/release already gave it
    // tactile feedback.
    property bool suppressPulse: false

    onOnChanged: {
        if (suppressPulse)
            return
        keyPulse = true
        pulseRelease.restart()
    }

    Timer {
        id: pulseRelease
        interval: 90 // matches Pill's press-down leg
        onTriggered: root.keyPulse = false
    }

    Timer {
        id: suppressGrace
        interval: 600 // covers the round-trip to the system and back
        onTriggered: root.suppressPulse = false
    }

    Pill {
        id: cap
        // See `anchorRight` above: whichever side is anchored is the
        // side that's pinned — Pill's own width/height already grow
        // from shadowDx/shadowDy, an anchored edge just decides which
        // direction that growth reads as moving in.
        anchors.left: root.anchorRight ? undefined : parent.left
        anchors.right: root.anchorRight ? parent.right : undefined
        anchors.bottom: parent.bottom

        width: root.capW + shadowDx
        height: root.capH + shadowDy

        cornerRadius: root.kind === "square" ? 30 : 40
        borderWidth: 3 + 2 * root.shadowLitP
        ringWidth: 3 + 11 * root.shadowLitP
        shadowDx: root.flatShadow ? 0 : 3 + 2 * root.shadowLitP + root.hoverBoostP * root.hoverShadowExtraX
        shadowDy: root.flatShadow ? 3 + root.shadowLitP + root.hoverBoostP * root.hoverShadowExtraY
                                  : 1 + root.shadowLitP + root.hoverBoostP * root.hoverShadowExtraY

        pressed: area.pressed || root.keyPulse

        // The white base is Pill's own default fillColor (Theme.colBg) —
        // always there, nothing drawn over it. This gradient is the ON
        // look, fading IN on top as the button lights up, rather than a
        // white sheet fading OUT over an always-on gradient underneath,
        // which is how this used to work: OFF pills — litP 0 — used
        // to show a thin ring of the gradient color around their edge
        // even at rest: two opaque, identically-shaped rounded rects
        // stacked on top of each other don't fully cancel at their
        // antialiased edge, since each one's own edge softening lets a
        // little of what's beneath it show through, and stacking two
        // of those compounds rather than hiding it. A single layer that
        // simply isn't drawn at all when litP is 0 doesn't have that
        // problem — there's nothing there to leak.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.accentMint }
                GradientStop { position: 1.0; color: Theme.accentCyan }
            }
            opacity: root.litP
            antialiasing: true
        }

        // Everything below is positioned in the cap's own coordinates
        // (top-left of the outline), which is why this box is pulled out
        // by the ring width — `fill`, where children of a Pill land, is
        // inset by it.
        Item {
            id: capBox
            x: -cap.ringWidth
            y: -cap.ringWidth
            width: cap.capWidth
            height: cap.capHeight

            MaterialIcon {
                id: glyph
                size: 24
                x: root.kind === "wide" ? 28 - 8 * root.litP : (parent.width - width) / 2
                y: (parent.height - height) / 2
                name: root.icon
                fill: root.iconFilled ? 1 : Theme.iconFill
                color: root.inkNow
            }

            Column {
                visible: root.kind === "wide"
                x: 62 - 8 * root.litP
                width: root.wideWidth - 73
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.label
                    color: root.inkNow
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                    lineHeight: root.lineHeightPx > 0 ? root.lineHeightPx : root.titleLine
                    lineHeightMode: Text.FixedHeight
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.subtitle
                    color: root.inkSubNow
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Normal
                    lineHeight: root.lineHeightPx > 0 ? root.lineHeightPx : root.subLine
                    lineHeightMode: Text.FixedHeight
                }
            }
        }
    }

    // Deliberately a sibling of the Pill, not inside it (same reason as
    // the workspace badges and tray button): the cap moves while
    // pressed, and a MouseArea riding along with it would slide out from
    // under a click on the button's edge. This one never moves.
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // Right-click only ever fires `rightClicked` (see onClicked
        // below).
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton)
                return
            root.suppressPulse = true
        }
        onReleased: mouse => {
            if (mouse.button === Qt.RightButton)
                return
            suppressGrace.restart()
        }
        onCanceled: {
            suppressGrace.restart()
        }
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.rightClicked()
                return
            }
            root.clicked()
        }
    }
}
