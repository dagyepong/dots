import QtQuick
import qs.modules.common

// The inner ring of a flat card drawn as a plain Rectangle (the launcher's
// search pill and results card): put it inside the card and it sits just
// inside the card's outline, like Pill.qml's innerRing. Nothing to set: it
// follows the card's radius and the mode (Theme.cardRing is 0 in Light mode,
// where it is hidden). Mouse input passes through it.
Rectangle {
    // The outline it sits inside: the card's own radius and border width.
    readonly property real outline: parent && parent.border ? parent.border.width : Theme.borderWidth

    anchors.fill: parent
    anchors.margins: outline
    radius: Math.max(0, (parent && parent.radius !== undefined ? parent.radius : 0) - outline)
    color: "transparent"
    border.width: Theme.cardRing
    border.color: Theme.ringWhite
    visible: Theme.cardRing > 0
    antialiasing: true
    z: 10
}
