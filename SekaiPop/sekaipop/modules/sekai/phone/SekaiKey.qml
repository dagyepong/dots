import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// The Settings Panel's keycap: a leaning plate with the shell's usual
// layers (hard drop shadow -> navy outline -> white ring -> fill) and the
// same physical behaviour as Pill.qml (it pushes into its shadow while
// pressed and springs back with an overshoot). What is new is the shape,
// and how it lights up: the cyan-mint fill is not a cross-fade but a wipe
// that runs in from the left, inside the white ring, like a note being hit.
//
//   SekaiKey {
//       capW: 220; capH: 60
//       lit: someSetting
//       hovered: area.containsMouse
//       pressed: area.pressed
//       Text { ... }              // content leans with the plate
//   }
//
// Whatever is put inside leans by the same amount as the plate (a shear
// about the plate's middle, so the middle of a line of text stays put and
// its top edge goes right while its bottom edge goes left), like the writing
// on a Project SEKAI button. Set `leanContent: false` to keep it upright.
//
// The item is exactly the cap's size: the shadow is drawn outside it, to the
// right and below, so give whatever holds it a few pixels of room.
Item {
    id: root

    property real capW: 200
    property real capH: 60
    property real skew: 0.2 * Theme.settingsLean
    property real radius: 18

    property bool lit: false
    property bool hovered: false
    property bool pressed: false

    // 0..1, the wipe. Follows `lit` unless something drives it directly.
    property real litP: lit ? 1 : 0
    Behavior on litP {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    property real borderBase: 3
    property real borderLit: 4
    // How wide the white ring around the lit fill gets (on top of the outline).
    property real ringExtra: 6

    readonly property real border: borderBase + (borderLit - borderBase) * litP
    // Distance from the cap's outer edge to the fill.
    readonly property real inset: border + ringExtra * litP

    property real shadowBaseX: 4
    property real shadowBaseY: 3
    // The 2D look (Theme.quickFlat, set by the Settings' keys): the shadow drops straight
    // down, like the bar's pills and the Quick Panel's 2D buttons, instead of down and to the
    // right. The depth (shadowBaseY + 1 when lit) is unchanged.
    property bool flatShadow: false
    readonly property real shadowDx: flatShadow ? 0 : shadowBaseX + 2 * litP
    readonly property real shadowDy: shadowBaseY + 1 * litP

    // What the fill is when it is not lit.
    property color idleColor: Theme.pSurface
    property color hoverColor: Theme.pSurfaceHover
    property Gradient litGradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Theme.accentMint }
        GradientStop { position: 1.0; color: Theme.accentCyan }
    }

    // Icons and text inside lean with the plate. Turn off for upright content.
    property bool leanContent: true

    default property alias content: inner.data
    property alias contentItem: inner

    width: capW
    height: capH

    // The inset shapes have to be shifted in by a bit more than the inset
    // itself, because a leaning plate gets shorter as it is inset.
    function insetX(t) {
        return t * (1.02 + root.skew)
    }

    Slant {
        x: root.shadowDx
        y: root.shadowDy
        width: root.capW
        height: root.capH
        skew: root.skew
        radius: root.radius
        color: Theme.pLineShadow
    }

    Item {
        id: surface

        width: root.capW
        height: root.capH
        x: root.pressed ? root.shadowDx : 0
        y: root.pressed ? root.shadowDy : 0

        Behavior on x {
            NumberAnimation {
                duration: root.pressed ? 80 : 260
                easing.type: root.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: root.pressed ? 0 : 2.2
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: root.pressed ? 80 : 260
                easing.type: root.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: root.pressed ? 0 : 2.2
            }
        }

        // outline + ring
        Slant {
            anchors.fill: parent
            skew: root.skew
            radius: root.radius
            color: Theme.pRingWhite
            borderColor: Theme.pLine
            borderWidth: root.border
        }

        // the idle fill
        Slant {
            x: root.insetX(root.inset)
            y: root.inset
            width: root.capW - 2 * x
            height: root.capH - 2 * root.inset
            skew: root.skew
            radius: Math.max(0, root.radius - root.inset)
            color: root.hovered && root.litP < 0.5 ? root.hoverColor : root.idleColor
        }

        // the lit fill, wiping in from the left
        Slant {
            visible: root.litP > 0.01
            x: root.insetX(root.inset)
            y: root.inset
            width: Math.max(0, (root.capW - 2 * x) * root.litP)
            height: root.capH - 2 * root.inset
            skew: root.skew
            radius: Math.max(0, root.radius - root.inset)
            gradient: root.litGradient
        }

        // The same shear the plate itself is drawn with (see Slant.qml), about
        // the plate's middle line.
        Item {
            id: inner

            width: root.capW
            height: root.capH

            transform: Matrix4x4 {
                matrix: root.leanContent
                    ? Qt.matrix4x4(1, -root.skew, 0, root.skew * root.capH / 2,
                                   0, 1, 0, 0,
                                   0, 0, 1, 0,
                                   0, 0, 0, 1)
                    : Qt.matrix4x4(1, 0, 0, 0,
                                   0, 1, 0, 0,
                                   0, 0, 1, 0,
                                   0, 0, 0, 1)
            }
        }
    }
}
