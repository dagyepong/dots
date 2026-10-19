import QtQuick
import qs.modules.common
import "../../common/functions/WelcomeMath.js" as WM

// One big icon sticker, built up like the layer-by-layer breakdown in the
// reference video: first the bare glossy shape ("Base"), a moment later the
// dark rim and the extrusion grow in ("+ Outline"). `reveal` (0..1) runs all
// of it; `idle` (radians) is a slow float once it has landed.
Item {
    id: root

    property real unit: 1
    property real reveal: 0
    property real idle: 0
    property bool idling: false
    property string glyph: "phone_iphone"
    // 0 = outline icon, 1 = solid icon (the Material Symbols FILL axis).
    property int glyphFill: 0
    property color fill: Qt.tint(Theme.pal.B, Qt.rgba(1, 1, 1, 0.42))
    property color ink: Theme.pal.deep

    readonly property real landed: WM.stagger(root.reveal, 0, 1, 0.4)
    readonly property real built: WM.easeOutCubic(WM.clamp01((root.reveal - 0.46) / 0.34))

    width: 200 * root.unit
    height: 250 * root.unit

    WelcomeLetter {
        id: icon

        anchors.centerIn: parent
        anchors.verticalCenterOffset: (root.idling ? Math.sin(root.idle) * 3.5 * root.unit : 0) + (1 - root.landed) * 30 * root.unit
        text: root.glyph
        family: Theme.iconFont
        weight: Font.Normal
        pixelSize: Math.round(210 * root.unit)
        axes: ({ "FILL": root.glyphFill, "wght": 700, "opsz": 48 })
        fill: root.fill
        outlineColor: root.ink
        // a thinner rim than the letters have: an icon has holes (the screen),
        // and a thick rim would fill them in
        outline: Math.round(pixelSize * 0.036)
        extrudeX: pixelSize * 0.028
        extrudeY: pixelSize * 0.05
        build: root.built
        opacity: Math.min(1, root.landed * 3)
        scale: WM.easeOutBack(root.landed)
        rotation: (1 - root.landed) * -12 + (root.idling ? Math.sin(root.idle * 0.7) * 1.8 : 0)
        transformOrigin: Item.Center
    }
}
