import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// The tray toggle, drawn natively (Pill.qml) from the Figma
// "Tray Down / Up Widget Bar" frames instead of exported images.
//
// Pure UI (no Quickshell imports): Bar.qml -> Status_Bar.qml feed it
// `open` and turn toggleRequested() into an action, same as the
// workspace badges and the media pill.
//
//   open: false -> tray is closed, shows the drop-down arrow
//   open: true  -> tray is open, the same arrow turned upside down
//
// Same shape as the workspace badges: 36px square-cle (radiusBadge
// corners, not a full circle), 8px white ring, navy fill (matching
// Weather/Clock/Battery/Resources rather than the badges' cyan, since
// this is a utility toggle, not a workspace). It physically pushes into
// its own shadow on
// mouse-down and springs back on release. `open` is a live reflection
// of the real state (owned by Bar.qml), so if it flips without a click
// — a keybind, or the dropdown closing itself when you click away —
// the button pulses on its own, the same trick the workspace badges
// and media pill use for keyboard shortcuts / media keys.
Item {
    id: root

    property bool open: false

    // Real screen pixels per design pixel (shell scale x the screen's device
    // pixel ratio). Not used by the arrow any more (it's a font glyph, crisp at
    // any scale); kept so the owner that sets it doesn't break.
    property real texel: 1

    // False when there's nothing for the dropdown to show: the button
    // shrinks and fades away (and comes back the same way).
    property bool present: true

    // Degrees to turn the arrow. 0 on a flat bar (the dropdown opens
    // downwards, or upwards on a bottom bar); on a standing bar it's
    // turned to point at the side the dropdown opens on.
    property real glyphRotation: 0

    // Some app in the dropdown is asking for attention: a coral dot.
    property bool attention: false

    signal toggleRequested()

    implicitWidth: Theme.pillHeight
    implicitHeight: Theme.pillHeight + Theme.shadowOffset

    // 0 -> 1. Also what a RowLayout uses to shrink the button's slot and
    // take back the gap around it gradually (see Status_Bar.qml).
    property real reveal: present ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }

    visible: reveal > 0.001
    opacity: Math.min(1, reveal * 1.5)
    scale: 0.75 + 0.25 * reveal

    // Programmatic press-then-pop for state changes that didn't come
    // from a click on this button.
    property bool keyPulse: false

    // Swallows that pulse for a moment right after THIS button was
    // physically clicked — the real press/release already gave it
    // tactile feedback.
    property bool suppressPulse: false

    onOpenChanged: {
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
        interval: 400 // covers the round-trip through Bar.qml and back
        onTriggered: root.suppressPulse = false
    }

    Pill {
        id: cap
        anchors.fill: parent

        cornerRadius: Theme.radiusBadge
        ringWidth: 6   // the bar's pills all share the Utility pill's ring
        fillColor: Theme.chipFill

        pressed: area.pressed || root.keyPulse

        // One Material Symbols Rounded glyph, "arrow_drop_down", centered on
        // the navy fill. It turns upside down (-> the "up" caret) while the
        // tray is open, so the arrow swaps with a little spin instead of a cut.
        Item {
            id: glyphs
            anchors.centerIn: parent
            width: 28
            height: 28
            rotation: root.glyphRotation

            MaterialIcon {
                id: arrow
                anchors.centerIn: parent
                name: "arrow_drop_down"
                size: 28
                fill: 1
                color: Theme.chipInk
                rotation: root.open ? 180 : 0
                Behavior on rotation {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    // Something in the dropdown wants attention: a coral dot on the corner
    // (a sibling of the Pill so it does not sink with the cap).
    Rectangle {
        visible: root.attention && root.present
        width: 11
        height: 11
        radius: 5.5
        x: root.width - 9
        y: -2
        color: "#ff5c7a"
        border.width: 2
        border.color: Theme.ringWhite
        antialiasing: true

        SequentialAnimation on scale {
            running: root.attention
            loops: Animation.Infinite
            NumberAnimation { to: 1.35; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
        }
    }

    // Deliberately a sibling of the Pill, not inside it (same reason as
    // the workspace badges): the Pill's cap moves down 4px while
    // pressed, and a MouseArea riding along with it would slide out
    // from under a click on the button's top edge. This one never
    // moves, so the whole button is always clickable.
    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleRequested()
        onPressed: root.suppressPulse = true
        onReleased: suppressGrace.restart()
        onCanceled: suppressGrace.restart()
    }
}
