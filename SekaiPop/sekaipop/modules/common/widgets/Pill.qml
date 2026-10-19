import QtQuick
import qs.modules.common

// Shared building block: a thick navy outline with a white "ring"
// gap between the outline and the actual colored fill, sitting on a
// flat offset "hard" shadow. Confirmed straight from the current
// Figma file — every pill in the bar uses this exact three-layer
// structure (outline -> white ring -> color), just with different
// ring widths (8px is the default everywhere except Media, which
// uses 5px). Set fillColor for a flat fill or fillGradient for the
// cyan/mint gradient pills; the ring itself is plain white unless a
// caller sets ringColorTop/ringColorBottom (the dock's hover/running
// glow — see Dock.qml). Anything declared inside a Pill lands on top
// of the fill.
//
// Inside a bar drawn in the Capsule style (see `capsule` below) all of that is
// dropped: the pill is one flat, fully rounded chip with no outline, ring or shadow.
// On a flat bar it is Theme.capChipHeight tall and centred in whatever box the caller
// gave it; on a standing bar (`capsuleV`) it is the whole box (less the shadow's room at
// the bottom), so the two-line texts have room.
//
// A popup card that hangs off a Capsule bar is not inside the bar, so it cannot
// find `capsuleBar` up the tree. Its owner (SekaiPopup, TrayPopups) sets
// `capRim` instead: the card keeps its own shape but takes the bar's colours --
// outline = the bar's rim, hard shadow = the bar's shadow, ring and fill = the
// bar's body.
Item {
    id: root

    // Inside the Capsule bar (Theme.capsuleFor): draw as a flat chip instead.
    readonly property bool capsule: Theme.capsuleFor(root)
    // ...on a bar standing on the left / right edge.
    readonly property bool capsuleV: root.capsule && Theme.capsuleVerticalFor(root)
    // The width of a pill on a standing bar: the Capsule bar's chips are narrower.
    readonly property real barVWidth: root.capsule ? Theme.capVChip : Theme.barVPillWidth
    // A chip normally takes the capsule's chip colour. A pill whose colour means
    // something (a Discord call, the mic in use, updates waiting) sets this to keep
    // its own fillColor there.
    property bool capKeepsFill: false
    // A popup card under a Capsule bar: outline, shadow, ring and fill in the
    // bar's rim / shadow / body colours (Theme.capRim / capShade / capBody).
    property bool capRim: false
    // No background at all: no hard shadow, outline, ring or fill. Whatever is
    // declared inside the Pill is still drawn, and the Pill keeps its size, so
    // nothing round it moves. The dock's Transparent style (Dock.qml).
    property bool bare: false
    // No hard shadow: the cap sits flat (a press only dips it 1 px). The pill keeps
    // its size, so the room the shadow took stays empty. The dock's Capsule keys.
    property bool flat: false

    // Inside the Quick Panel / To-Do in the first dark mode: the classic look.
    readonly property bool classicScope: Theme.classicFor(root)

    property color fillColor: classicScope ? Theme.pSurface : Theme.surface
    property Gradient fillGradient: null
    property real cornerRadius: height / 2
    property real ringWidth: 8

    // A ring drawn over the outer edge of the fill (inside, so the pill does
    // not grow), for the flat cards whose ringWidth equals their outline and
    // so show no ring of their own. 0 = none. Cards pass Theme.cardRing.
    property real innerRing: 0

    // Outline thickness, and where the hard shadow sits. The bar's pills
    // only ever drop it straight down (shadowDy 4, shadowDx 0); the Quick
    // Panel's buttons cast it down-right and change all three between
    // their OFF and ON looks, which is why they're properties here.
    property real borderWidth: Theme.borderWidth
    property real shadowDx: 0
    property real shadowDy: Theme.shadowOffset

    // Ring color, as the top/bottom stops of a vertical gradient. Both
    // default to plain white, so every existing Pill (badges, QuickToggle,
    // the launcher's search pill) looks exactly like it always has — set
    // these when a Pill's *ring* itself needs to carry color, like the
    // dock's hover/running glow (see Dock.qml), rather than just its fill.
    property color ringColorTop: classicScope ? Theme.pRingWhite : Theme.ringWhite
    property color ringColorBottom: classicScope ? Theme.pRingWhite : Theme.ringWhite

    // The raised part of the pill — the size without its shadow.
    readonly property real capWidth: width - shadowDx
    readonly property real capHeight: height - shadowDy
    default property alias content: fill.data

    // Physical-button press state. Pill itself never listens for
    // clicks (callers each have their own MouseArea, with their own
    // hit-test shape) — bind this to that MouseArea's own "pressed"
    // so the cap below reacts to the real press/release, not just a
    // completed click.
    property bool pressed: false

    implicitHeight: Theme.pillHeight + shadowDy

    // Fixed hard shadow — never moves. It's what the cap below either
    // reveals (raised) or fully covers (pressed).
    Rectangle {
        visible: !root.capsule && !root.bare && !root.flat
        x: root.shadowDx
        y: root.shadowDy
        width: root.capWidth
        height: root.capHeight
        radius: root.cornerRadius
        color: root.capRim ? Theme.capShade
            : (root.classicScope ? Theme.pLineShadow : Theme.lineShadow)
        antialiasing: true
    }

    // The "cap" — outline, white ring, colored fill, and anything a
    // caller declares inside this Pill (it all ends up inside "fill"
    // below, so it rides along) — moves as one unit. Resting, it sits
    // at y:0 with the shadow peeking out beneath by shadowOffset,
    // reading as raised. Pressed, it drops onto the shadow (y:
    // shadowOffset), exactly covering it so the offset disappears —
    // the button looks pushed flush into the surface. Releasing lets
    // it spring back past rest and settle, like a real keycap
    // popping back up.
    Item {
        id: surface
        // Capsule: the whole box wide, one chip tall, in the middle of it; a press
        // only dips it 1 px (there is no shadow to sink into).
        x: root.capsule ? 0 : (root.pressed && !root.flat ? root.shadowDx : 0)
        y: root.capsule ? (root.capsuleV ? 0 : (root.height - surface.height) / 2) + (root.pressed ? 1 : 0)
                        : (root.pressed ? (root.flat ? 1 : root.shadowDy) : 0)
        width: root.capsule ? root.width : root.capWidth
        height: root.capsule ? (root.capsuleV ? Math.max(0, root.height - root.shadowDy)
                                              : Math.min(root.height, Theme.capChipHeight))
                             : root.capHeight

        Behavior on x {
            NumberAnimation {
                duration: root.pressed ? 80 : 260
                easing.type: root.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: root.pressed ? 0 : 2.2
                // Every pill in the Quick Panel's phone -- toggles,
                // sliders -- presses in and springs back through this
                // same Behavior. It used to call PanelActivity.touch()
                // here, which meant every click or hover dropped the
                // whole phone to reduced quality for the ~300ms of the
                // bounce -- visible as a blur on click/hover since this
                // Behavior runs on essentially every interaction. A
                // one-shot ~300ms animation isn't the expensive case
                // PanelActivity exists for (that's sustained per-frame
                // redraw -- a drag, a hold, a scroll); it's cheap enough
                // to just let it render at full quality. See
                // PanelActivity and the *actually* continuous touch()
                // calls (drag/scroll/hold) for the ones that still
                // matter.
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: root.pressed ? 80 : 260
                easing.type: root.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: root.pressed ? 0 : 2.2
            }
        }

        Rectangle {
            id: face
            visible: !root.capsule && !root.bare
            anchors.fill: parent
            radius: root.cornerRadius
            border.width: root.borderWidth
            border.color: root.capRim ? Theme.capRim
                : (root.classicScope ? Theme.pLine : Theme.line)
            antialiasing: true

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: root.capRim ? Theme.capBody : root.ringColorTop
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                GradientStop {
                    position: 1.0
                    color: root.capRim ? Theme.capBody : root.ringColorBottom
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }

        Rectangle {
            id: fill
            anchors.fill: face
            anchors.margins: root.capsule ? 0 : root.ringWidth
            radius: root.capsule ? Math.min(width, height) / 2 : Math.max(0, root.cornerRadius - root.ringWidth)
            color: root.bare ? "transparent"
                : (root.capsule
                    ? (root.capKeepsFill ? root.fillColor : Theme.capChip)
                    : (root.capRim ? Theme.capBody
                        : (root.fillGradient ? "transparent" : root.fillColor)))
            gradient: (root.capsule || root.capRim || root.bare) ? null : root.fillGradient

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
            antialiasing: true
        }

        // Above the fill and everything declared inside the Pill.
        Rectangle {
            anchors.fill: fill
            radius: fill.radius
            color: "transparent"
            border.width: root.innerRing
            border.color: root.capRim ? Theme.capBody : root.ringColorTop
            visible: root.innerRing > 0 && !root.capsule && !root.bare
            antialiasing: true
        }
    }
}
