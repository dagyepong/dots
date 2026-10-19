import QtQuick
import qs.services
import qs.modules.common

// The thin divider between the dock's groups (Dock.qml): a short rounded bar
// across the row, or across the column when the dock stands on the left / right.
Item {
    id: root

    property bool vertical: false
    property real iconSize: 35
    property real thickness: 4
    // Capsule dock: in the Capsule bar's rim colour.
    property bool capsule: false

    width: root.vertical ? root.iconSize : root.thickness
    height: root.vertical ? root.thickness : root.iconSize + Theme.shadowOffset

    Rectangle {
        width: root.vertical ? root.iconSize * 0.7 : parent.width
        height: root.vertical ? parent.height : root.iconSize * 0.7
        x: root.vertical ? (parent.width - width) / 2 : 0
        y: root.vertical ? 0 : (root.iconSize - height) / 2
        radius: Math.min(width, height) / 2
        color: root.capsule ? Theme.capRim : Theme.surfaceDivider
    }
}
