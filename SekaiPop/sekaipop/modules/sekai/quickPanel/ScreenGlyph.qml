import QtQuick
import qs.modules.common

// A tiny drawing of a screen with the bar on it, for the bar-position and
// bar-style choices: where the strip sits says which one it is.
//   edge:    "top" | "right" | "bottom" | "left"
//   variant: "float"       a short rounded strip, inset from the edges
//            "straight"    a strip flush with the edges, square corners
//            "transparent" no strip, just the pills floating
//            "capsule"     a short, fully rounded strip, inset from the edges
//            ""            the plain strip (position choices)
Item {
    id: root

    property string edge: "top"
    property string variant: ""
    property color color: Theme.pInk

    implicitWidth: 40
    implicitHeight: 28

    readonly property bool vertical: edge === "left" || edge === "right"

    Rectangle {
        anchors.fill: parent
        radius: Math.min(7, root.height / 4)
        color: "transparent"
        border.width: 2
        border.color: root.color
        antialiasing: true
    }

    // The strip (or, when transparent, three pills where it would be).
    Item {
        id: strip
        readonly property real t: Math.max(4, Math.round(root.height * 0.27))
        readonly property real inset: (root.variant === "float" || root.variant === "capsule") ? 5 : 0
        x: root.edge === "right" ? parent.width - t : (root.vertical ? 0 : inset)
        y: root.edge === "bottom" ? parent.height - t : (root.vertical ? inset : 0)
        width: root.vertical ? t : parent.width - inset * 2
        height: root.vertical ? parent.height - inset * 2 : t

        Rectangle {
            visible: root.variant !== "transparent"
            anchors.fill: parent
            radius: root.variant === "straight" ? 0 : (root.variant === "capsule" ? Math.min(width, height) / 2 : 3)
            color: root.color
            antialiasing: true
        }

        Repeater {
            model: root.variant === "transparent" ? 3 : 0

            delegate: Rectangle {
                required property int index
                width: root.vertical ? strip.t * 0.55 : strip.t * 0.9
                height: root.vertical ? strip.t * 0.9 : strip.t * 0.55
                radius: 2
                color: root.color
                x: root.vertical ? (strip.width - width) / 2 : root.width * 0.14 + index * root.width * 0.22
                y: root.vertical ? root.height * 0.18 + index * root.height * 0.26 : (strip.height - height) / 2
            }
        }
    }
}
