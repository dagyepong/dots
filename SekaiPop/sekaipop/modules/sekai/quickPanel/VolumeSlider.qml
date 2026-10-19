import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.phone

// A draggable volume slider, sized to sit where a "wide" QuickToggle
// would (200px wide) — just a little taller, to fit a track under the
// label. There's no Figma frame for this one (a slider didn't exist in
// the mockup): sized to match its neighbors and drawn from the same
// pieces everything else here uses (Theme's colors, the progress-bar
// look ResourcePopup.qml already established), the same way the bar
// extras (resources/battery/keyboard layout) were fit in pragmatically
// rather than traced from a frame.
//
// Pure UI (no Quickshell imports): QuickPanelFace.qml feeds it `value`
// (0-100, the real system volume, from QuickSource.qml) and reads
// changes back out through `moved` while the user drags or taps the
// track. Clicking anywhere on the cap — not the track — is a separate
// click, wired to `iconClicked` (the existing mute toggle); it doesn't
// fight the drag. Right-clicking the cap is a third, separate signal
// (`rightClicked`) — QuickPanelFace wires it to VolumeMixerDialog.qml:
// a compact default-device dropdown plus a per-app volume mixer,
// rather than the plain device list Network/Bluetooth get.
Item {
    id: root

    property string label: ""
    property string icon: ""   // Material Symbols Rounded name
    property bool muted: false
    property real value: 0   // 0-100, the real state fed in from outside

    // Brightness has no mute to toggle and no dialog to open on right-click
    // — its cap was a button that did nothing when clicked, just taking up
    // space and looking interactive when it wasn't. `simple: true` drops
    // the whole Pill (border/ring/shadow, press animation, on/off tint) and
    // the button's MouseArea, leaving a plain icon + label + value header
    // that just names the slider below it. Mic/Speaker leave this false and
    // keep their real button.
    property bool simple: false

    // The cap's resting width (Mic/Speaker keep the default 200 they were
    // designed at). Brightness stretches this to span the full row instead
    // of sharing it with a second tile — everything below already reads
    // off `parent.width`/`root.width`, so nothing else needs to change.
    property real sliderWidth: 200

    signal moved(real value)
    signal iconClicked()
    signal rightClicked()

    implicitWidth: sliderWidth
    // simple mode's header is a plain text line, not a 73px-tall button
    // face, so the whole control is shorter too (56 vs. 97) — see the
    // header Item and the track's y below, which is where the other half
    // of that math lives.
    implicitHeight: root.simple ? 56 : 97

    // While a drag (or a tap-to-set) is in progress, the track follows
    // the pointer directly rather than `value` — which only catches up
    // once the round trip through wpctl and the next poll lands, a
    // couple hundred ms later at best. Released, it settles back onto
    // `value` the instant that arrives (by then they already match: the
    // last `moved()` in the drag set the real state to the same number).
    // The Quick Panel's 2D look (see QuickToggle.flatShadow): shadow straight down.
    property bool flatShadow: false

    property bool dragging: false
    property real dragValue: 0
    readonly property real shownValue: dragging ? dragValue : value

    // 0 = OFF (muted) look, 1 = ON (unmuted) look — the exact same
    // border/ring/shadow growth QuickToggle's wide pills use for
    // Wi-Fi/Bluetooth, so these two read as on/off toggles too instead
    // of just a fading fill. Glides between them rather than snapping.
    property real litP: root.muted ? 0 : 1

    // Text / glyph colour: mode ink when muted (plain surface), dark ink when
    // lit (accent gradient behind it). `simple` (Brightness) has no button
    // and no gradient behind its text -- it always sits on the plain surface,
    // so it always wears the mode ink (it was going navy on the dark surface).
    readonly property color inkNow: root.simple
        ? Theme.pInk
        : Qt.tint(Theme.pInk, Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, litP))
    readonly property color inkSubNow: Qt.rgba(inkNow.r, inkNow.g, inkNow.b, 0.667)
    Behavior on litP {
        NumberAnimation {
            duration: 170
            easing.type: Easing.OutCubic
        }
    }

    // Programmatic press-then-pop for state changes that didn't come
    // from a click on this button (a hardware mute key, another mixer)
    // — same trick QuickToggle/the workspace badges/tray button/media
    // pill all use, so a mute flipping elsewhere still pulses the cap.
    property bool keyPulse: false
    // Swallows that pulse for a moment right after THIS button was
    // physically clicked — the real press/release already gave it
    // tactile feedback.
    property bool suppressPulse: false

    onMutedChanged: {
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
        visible: !root.simple
        anchors.left: parent.left
        anchors.top: parent.top
        // capWidth/capHeight (the actual drawn face) stay fixed at
        // sliderWidth x73 — only the extra shadow reveal grows/shrinks —
        // same trick QuickToggle uses.
        width: root.sliderWidth + shadowDx
        height: 73 + shadowDy
        cornerRadius: 40
        borderWidth: 3 + 2 * root.litP
        ringWidth: 3 + 11 * root.litP
        shadowDx: root.flatShadow ? 0 : 3 + 2 * root.litP
        shadowDy: root.flatShadow ? 3 + root.litP : 1 + root.litP

        // Pushes the cap down onto its own shadow on press and springs
        // it back on release, exactly like QuickToggle's pills — either
        // from a real press (buttonArea, below) or a programmatic pulse
        // for an external mute change.
        pressed: buttonArea.pressed || root.keyPulse

        // The white base is Pill's own default fillColor — always
        // there, nothing drawn over it. This gradient fades IN on top
        // as litP rises, same as QuickToggle's ON look.
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
        // (top-left of the outline), same reason QuickToggle pulls its
        // capBox out by the ring width: children of a Pill land inside
        // `fill`, which is inset by ringWidth on every side — as the
        // ring grows for the ON look, an unpinned child would drift
        // inward with it. This box cancels that out, so the icon and
        // the percentage on the right stay put through the whole
        // OFF->ON glide instead of sliding as the ring resizes.
        Item {
            id: capBox
            x: -cap.ringWidth
            y: -cap.ringWidth
            width: cap.capWidth
            height: cap.capHeight

            MaterialIcon {
                color: root.inkNow
                id: glyph
                x: 20
                size: 24
                anchors.verticalCenter: parent.verticalCenter
                name: root.icon
                opacity: root.muted ? 0.4 : 1
            }

            Text {
                id: nameLabel
                anchors.left: glyph.right
                anchors.leftMargin: 12
                anchors.right: pctLabel.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: root.label
                color: root.muted ? Theme.pInkSub : root.inkNow
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }

            Text {
                id: pctLabel
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: root.muted ? "MUTE" : Math.round(root.shownValue) + "%"
                color: root.inkSubNow
                font.family: Theme.fontFamily
                font.pixelSize: 14
            }
        }
    }

    // simple: true's whole header — just the icon, the label, and the
    // current value, sitting where the Pill button would otherwise be.
    // No fill/border/shadow, no press state, nothing clickable: there's
    // nothing for a click here to do, so it doesn't invite one. It only
    // exists to name the slider underneath it.
    Item {
        visible: root.simple
        x: 0
        y: 0
        width: root.sliderWidth
        // Just tall enough for the 24px icon and 18px label, not the old
        // button's 73 — see implicitHeight/track.y above and below, which
        // shrink by the same 41px this frees up.
        height: 32

        MaterialIcon {
            color: root.inkNow
            id: simpleGlyph
            x: 20
            size: 24
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
        }

        Text {
            anchors.left: simpleGlyph.right
            anchors.leftMargin: 12
            anchors.right: simplePct.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.label
            color: root.inkNow
            font.family: Theme.fontFamily
            font.pixelSize: 18
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        Text {
            id: simplePct
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.shownValue) + "%"
            color: root.inkSubNow
            font.family: Theme.fontFamily
            font.pixelSize: 14
        }
    }

    // The whole cap toggles mute now, not just the 24px glyph — reads
    // as a real button the same way the Wi-Fi/Bluetooth tiles do,
    // rather than needing a precise tap on the icon. A sibling of
    // Pill, not nested inside it — same reason QuickToggle's own button
    // MouseArea is: the cap moves while pressed, and a MouseArea riding
    // along with it would slide out from under a click on the button's
    // edge. Sized to the cap's own rest footprint (sliderWidth+5 x75, its
    // max with the ON-look's shadow) and placed above the track, which
    // keeps its own separate MouseArea for dragging/tapping the volume
    // level.
    //
    // Skipped entirely in simple mode — there's no mute to toggle and no
    // dialog to open, so this would just be a click target that does
    // nothing.
    MouseArea {
        id: buttonArea
        visible: !root.simple
        enabled: !root.simple
        x: 0
        y: 0
        width: root.sliderWidth + 5
        height: 75
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.suppressPulse = true
        }
        onReleased: mouse => {
            if (mouse.button === Qt.LeftButton)
                suppressGrace.restart()
        }
        onCanceled: suppressGrace.restart()
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked()
            else
                root.iconClicked()
        }
    }

    // The track, below the cap. Its own thin rounded rect (like the
    // CPU/RAM bars in ResourcePopup.qml) rather than another full Pill
    // — no border/ring needed at this size. Pinned to a fixed y (73 +
    // the ON-look's max shadowDy of 2, +8 gap) rather than tracking
    // cap.height directly, so the cap's on/off shadow growth doesn't
    // nudge the track up and down as it animates.
    Rectangle {
        id: track
        x: 20
        // Pinned right under whichever header is showing: the full-size
        // cap (73 tall, +2 for its max shadow, +8 gap) normally, or
        // simple mode's plain 32px line (+10 gap) when there's no cap.
        y: root.simple ? (32 + 10) : (73 + 2 + 8)
        width: parent.width - 40
        height: 14
        radius: 7
        color: Theme.pSurfaceDivider

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.shownValue / 100))
            height: parent.height
            radius: 7
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.muted ? Theme.pInkSub : Theme.accentMint }
                GradientStop { position: 1.0; color: root.muted ? Theme.pInkSub : Theme.accentCyan }
            }
            opacity: root.muted ? 0.5 : 1
            Behavior on width {
                enabled: !root.dragging
                NumberAnimation {
                    duration: 150
                }
            }
            antialiasing: true
        }

        MouseArea {
            id: trackArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            // Not nested inside a Flickable here, so this isn't strictly
            // needed the way it is on the per-app mixer's sliders (see
            // VolumeMixerDialog.qml) — set anyway so dragging keeps
            // working the same way if this ever ends up inside a
            // scrollable container down the line.
            preventStealing: true

            function setFromX(mx) {
                const p = Math.max(0, Math.min(1, mx / track.width))
                root.dragValue = p * 100
                root.moved(root.dragValue)
                // No Behavior runs while dragging (see above) -- the
                // track's width is set straight from the pointer every
                // move, which needs its own touch() to keep the phone
                // off full quality for the whole drag.
                PanelActivity.touch()
            }

            onPressed: mouse => {
                root.dragging = true
                setFromX(mouse.x)
            }
            onPositionChanged: mouse => {
                if (pressed)
                    setFromX(mouse.x)
            }
            onReleased: root.dragging = false
            onCanceled: root.dragging = false
        }
        antialiasing: true
    }
}
