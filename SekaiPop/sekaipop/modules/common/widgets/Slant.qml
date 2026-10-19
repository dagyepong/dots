import QtQuick

// A leaning ("italic") rounded rectangle: the basic shape of the Settings
// Panel's new look. Project SEKAI's menus are full of slanted plates and
// keys; this is the one place that makes them.
//
// It is an ordinary Rectangle with a skew applied, so it can have a fill, a
// gradient, an outline and rounded corners, and everything stays crisp.
// The skew only moves the top and bottom edges sideways: the item's own box
// is exactly as wide as the shape's widest point (so `width` is honest and
// layouts work), and the body is narrower by `lean`.
//
// Put text and icons NEXT to a Slant, not inside it (a child would lean too).
Item {
    id: root

    // How far the top edge leans right (and the bottom one left), as a
    // fraction of the height. 0 = a plain rectangle, 0.2 = the default lean.
    property real skew: 0.2
    property real radius: 12
    property color color: "transparent"
    property color borderColor: "transparent"
    property real borderWidth: 0
    property Gradient gradient: null

    // The total sideways travel from the bottom edge to the top edge.
    readonly property real lean: skew * height

    Rectangle {
        x: root.lean / 2
        width: Math.max(0, root.width - root.lean)
        height: root.height
        radius: Math.min(root.radius, height / 2)
        color: root.color
        gradient: root.gradient
        border.width: root.borderWidth
        border.color: root.borderColor
        antialiasing: true

        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(1, -root.skew, 0, root.skew * root.height / 2,
                                 0, 1, 0, 0,
                                 0, 0, 1, 0,
                                 0, 0, 0, 1)
        }
    }
}
