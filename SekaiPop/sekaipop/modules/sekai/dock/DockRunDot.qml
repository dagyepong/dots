import QtQuick
import qs.modules.common

// The running indicator under a dock key (Dock.qml) — the small diamond of the
// shell's own beat widgets rather than macOS's round dot:
//
//   "none"      nothing drawn (app not running)
//   "running"   mint diamond
//   "focused"   bigger, cyan: this is the app you are in
//   "hidden"    hollow: the app is open but every window is minimized
//
// It springs when its state changes.
Item {
    id: root

    property string mode: "none"
    // Capsule dock: a round dot like the Capsule bar's workspace dots (the bar's
    // pastels, no navy outline) instead of the diamond.
    property bool capsule: false

    readonly property real base: root.mode === "focused" ? 8 : 6

    width: 10
    height: 10
    visible: root.mode !== "none"

    Rectangle {
        id: diamond
        anchors.centerIn: parent
        width: root.capsule ? root.base + 1 : root.base
        height: root.capsule ? root.base + 1 : root.base
        radius: root.capsule ? height / 2 : 2
        rotation: root.capsule ? 0 : 45
        antialiasing: true
        color: root.capsule
            ? (root.mode === "focused" ? Theme.capLit
                : (root.mode === "hidden" ? "transparent" : Theme.capLitSoft))
            : (root.mode === "focused" ? Theme.accentCyan
                : (root.mode === "hidden" ? "transparent" : Theme.accentMint))
        border.width: root.capsule ? (root.mode === "hidden" ? 1.5 : 0)
            : (root.mode === "hidden" ? 1.5 : 1)
        border.color: root.capsule ? Theme.capRim : Theme.line

        Behavior on width {
            NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 3 }
        }
        Behavior on height {
            NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 3 }
        }
        Behavior on color {
            ColorAnimation { duration: 140 }
        }
    }
}
