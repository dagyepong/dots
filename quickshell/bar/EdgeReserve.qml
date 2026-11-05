import QtQuick
import Quickshell

// Invisible 1px window that only reserves room on one edge of the screen (Vertical style):
// the main window covers the whole screen, and windows must not go under the bar and the frame.
PanelWindow {
    id: win

    property string edge: "left"        // left | top | right | bottom
    property int size: 8

    anchors {
        left: edge !== "right"
        right: edge !== "left"
        top: edge !== "bottom"
        bottom: edge !== "top"
    }

    implicitWidth: 1
    implicitHeight: 1
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: size

    // No input at all
    mask: Region {}
}
