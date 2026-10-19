import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// A small "this reacts to the scroll wheel" marker for a bar module: a dark
// dot with an up-down glyph on the module's top right corner, shown once the
// pointer has rested on the module for a moment and gone as soon as it leaves.
//
//   WorkspaceBadges {
//       ...
//       ScrollHint { anchors { top: parent.top; right: parent.right; margins: -4 } }
//   }
//
// It watches its parent with a HoverHandler, so it takes no clicks and never
// gets in the way of the module's own mouse areas. Settings -> Bar -> Scroll
// hints switches every one of them off (`bar.scrollHints`).
Item {
    id: root

    property string glyph: "unfold_more"
    // The module can switch its hint off (nothing to scroll right now).
    property bool active: true
    property int dwell: 450

    readonly property bool wanted: active && SettingsService.flag("bar.scrollHints")
    property bool shown: false

    width: 16
    height: 16
    z: 60

    visible: dot.opacity > 0.01
    HoverHandler {
        id: hover
        enabled: root.wanted
        onHoveredChanged: if (!hovered) root.shown = false
    }

    Timer {
        running: hover.hovered && root.wanted
        interval: root.dwell
        onTriggered: root.shown = true
    }

    Rectangle {
        id: dot
        anchors.fill: parent
        radius: width / 2
        color: Theme.colBorder
        border.width: 2
        border.color: Theme.ringWhite
        antialiasing: true
        opacity: root.shown && root.wanted ? 1 : 0
        scale: root.shown && root.wanted ? 1 : 0.5

        Behavior on opacity { NumberAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2 } }

        MaterialIcon {
            anchors.centerIn: parent
            name: root.glyph
            size: 11
            fill: 1
            color: Theme.textWhite
        }
    }
}
