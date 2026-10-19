import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.quickPanel

// One little key for Edit Desktop's BAR and DOCK tabs: a screen drawing (the
// ScreenGlyph the Settings Panel uses) or a Material icon, lit with the accent
// gradient when it is the one that is on. It is a Pill like the bar's own pills
// (ring 3, short hard shadow, the same as the keycaps on the BAR lanes).
//
//   EditPickKey { edge: "top"; variant: "float"; on: ...; onPicked: ... }
//   EditPickKey { icon: "visibility"; on: ...; onPicked: ... }
//
// `hovered` lets the owner show the name of the key under the pointer.
Item {
    id: pk

    // A screen drawing: which edge, and (optionally) which bar look.
    property string edge: "top"
    property string variant: ""
    // Or an icon instead of the drawing.
    property string icon: ""
    property bool on: false

    signal picked()

    readonly property bool hovered: pkArea.containsMouse

    width: 52
    height: 34

    Gradient {
        id: pkFill
        GradientStop { position: 0.0; color: Theme.accentMint }
        GradientStop { position: 1.0; color: Theme.accentCyan }
    }

    Pill {
        anchors.fill: parent
        cornerRadius: 11
        ringWidth: 3
        shadowDy: 3
        pressed: pkArea.pressed
        fillColor: pk.hovered && !pk.on ? Theme.pSurfaceHover : Theme.pSurface
        fillGradient: pk.on ? pkFill : null

        ScreenGlyph {
            visible: pk.icon === ""
            anchors.centerIn: parent
            width: 30
            height: 20
            edge: pk.edge
            variant: pk.variant
            color: pk.on ? Theme.colBorder : Theme.pInk
        }

        MaterialIcon {
            visible: pk.icon !== ""
            anchors.centerIn: parent
            name: pk.icon
            size: 20
            weight: 600
            color: pk.on ? Theme.colBorder : Theme.pInk
        }
    }

    MouseArea {
        id: pkArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: pk.picked()
    }
}
