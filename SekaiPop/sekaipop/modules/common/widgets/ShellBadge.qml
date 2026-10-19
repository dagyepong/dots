import QtQuick
import qs.modules.common
import "../functions/NotifyKinds.js" as NK

// The shell's own notification icon: the badge a screenshot, a recording, a
// timer or an error wears, so it is told apart at a glance from the app and
// browser notifications (which show the app's own icon). It is the Project
// SEKAI card-attribute look: a pastel fill (Cool / Cute / Happy / Mysterious /
// Pure, picked from the glyph by NotifyKinds.js), a white glyph outlined in
// the attribute outline colour, a thick outline and a hard offset shadow, in
// the same #555473 the attribute icons use.
//
//   ShellBadge { size: 56; glyph: "photo_camera" }
//
// `glyph` is the Material Symbols name, the part after "material:" in the
// notification's icon. The shadow is drawn outside the item's box (down-right,
// `size * 0.05`), so leave a little room for it. Nothing here moves or
// repaints on its own: it is a handful of static shapes.
Item {
    id: root

    property string glyph: ""
    property real size: 56

    readonly property int kind: NK.index(root.glyph)
    readonly property color fillColor: Theme.attributeColors[root.kind]
    // Outline and shadow: the same colour in the shell's attribute icons.
    readonly property color ink: Theme.mono ? Theme.colBorder : "#555473"
    readonly property real outline: Math.max(2, root.size * 0.055)
    readonly property real glyphSize: Math.round(root.size * 0.6)

    width: root.size
    height: root.size

    // Hard shadow.
    Rectangle {
        x: Math.round(root.size * 0.05)
        y: Math.round(root.size * 0.05)
        width: root.size
        height: root.size
        radius: root.size * 0.34
        color: root.ink
        antialiasing: true
    }

    // Outline + pastel fill.
    Rectangle {
        anchors.fill: parent
        radius: root.size * 0.34
        color: root.fillColor
        border.width: root.outline
        border.color: root.ink
        antialiasing: true
    }

    // A soft highlight, top-left, so the badge reads as a raised key.
    Rectangle {
        x: root.size * 0.17
        y: root.size * 0.13
        width: root.size * 0.30
        height: root.size * 0.13
        radius: height / 2
        rotation: -24
        color: Qt.rgba(1, 1, 1, 0.5)
        antialiasing: true
    }

    // The glyph's outline: the glyph drawn eight times around a small
    // circle, in the outline colour; the white one goes on top. The boxes are
    // a little bigger than the glyph so the outline is not clipped.
    Repeater {
        model: 8

        delegate: MaterialIcon {
            required property int index

            readonly property real a: index * Math.PI / 4
            readonly property real r: Math.max(1.4, root.glyphSize * 0.055)

            anchors.centerIn: parent
            anchors.horizontalCenterOffset: Math.cos(a) * r
            anchors.verticalCenterOffset: Math.sin(a) * r
            size: root.glyphSize
            width: root.glyphSize + 12
            height: root.glyphSize + 12
            fill: 1
            weight: 600
            color: root.ink
            name: root.glyph
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        size: root.glyphSize
        width: root.glyphSize + 12
        height: root.glyphSize + 12
        fill: 1
        weight: 600
        color: "#ffffff"
        name: root.glyph
    }
}
