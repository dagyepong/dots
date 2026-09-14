// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D O C K   I T E M                                                      │
// │   one application on the dock · its icon, its dot and its drag           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../theme"
import "../services"

// One application on the dock: the icon and a running dot. The position comes
// from DockService, so the name label can use the same arithmetic.
//
// Hovering lifts the icon slightly instead of magnifying it: magnification
// shifts the neighbours and moves the target.
Item {
    id: root

    required property var modelData
    required property int index

    // The capsule this sits in, passed in rather than reached through parents.
    required property Item capsule

    readonly property string key: root.modelData.key
    readonly property bool running: root.modelData.running
    readonly property bool active: root.modelData.active
    readonly property bool multiple: root.modelData.windows.length > 1

    readonly property bool vertical: DockService.vertical
    readonly property string edge: DockService.edge

    // Only pinned applications can be reordered, and only among themselves.
    readonly property bool movable: root.modelData.pinned && DockService.pinnedCount > 1
    readonly property bool held: DockService.dragging === root.key

    readonly property bool hovered: hover.hovered

    // The menu has to draw outside the capsule and above the other icons, so
    // the request goes up to the dock.
    signal menuRequested(string key)

    // The dot lane is on the screen-edge side, so the icon is pushed off it.
    readonly property real along: DockService.offsetOf(DockService.shifted(root.index))

    width: root.vertical ? Theme.dockDepth : Theme.dockIcon
    height: root.vertical ? Theme.dockIcon : Theme.dockDepth

    z: root.held ? 2 : (root.hovered ? 1 : 0)

    // Dragging assigns x or y directly, which would break a plain binding, so
    // the binding is separate and disabled while held (as in Widget).
    Binding {
        target: root
        property: "x"
        value: root.vertical ? Theme.dockPadding : root.along
        when: !drag.active
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        target: root
        property: "y"
        value: root.vertical ? root.along : Theme.dockPadding
        when: !drag.active
        restoreMode: Binding.RestoreBindingOrValue
    }

    // Animates the neighbours making room, and the held icon returning when the
    // drop changes nothing.
    Behavior on x {
        enabled: !drag.active
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }

    Behavior on y {
        enabled: !drag.active
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }

    // ── ICON ────────────────────────────────────────────────────────────────

    Item {
        id: slot

        width: Theme.dockIcon
        height: Theme.dockIcon

        // Against the far side of the box; the dot takes the side nearest the
        // screen edge.
        x: root.edge === "right" ? 0 : root.width - Theme.dockIcon
        y: root.edge === "bottom" ? 0 : (root.height - Theme.dockIcon) / 2

        scale: root.hovered || root.held ? Theme.dockLift : 1

        Behavior on scale {
            NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
        }

        // Hover highlight, kept inside the gap between icons.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: Theme.radiusMedium
            color: Theme.islandSurfaceHover
            opacity: root.hovered || root.held ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
            }
        }

        // The desktop entry's icon from the icon theme, falling back to the
        // launcher mark when it is missing.
        readonly property string iconSource: root.modelData.icon
            ? Quickshell.iconPath(root.modelData.icon, true) : ""

        Image {
            id: picture

            anchors.fill: parent
            source: slot.iconSource
            sourceSize: Qt.size(Theme.dockIcon * 2, Theme.dockIcon * 2)
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            visible: slot.iconSource !== "" && status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: !picture.visible
            text: "󰀻"
            font.family: Theme.fontMono
            font.pixelSize: Math.round(Theme.dockIcon * 0.6)
            color: Theme.textMuted
        }
    }

    // ── RUNNING INDICATOR ───────────────────────────────────────────────────
    //
    // One window is a dot, several a longer one. The accent for the focused
    // application, muted when it is running but not focused.
    Rectangle {
        readonly property real reach: root.multiple ? Theme.dockDot * 2.8 : Theme.dockDot

        width: root.vertical ? Theme.dockDot : reach
        height: root.vertical ? reach : Theme.dockDot
        radius: Theme.radiusPill
        color: root.active ? Theme.accent : Theme.textMuted

        x: root.edge === "right"
            ? root.width - Theme.dockDot
            : (root.edge === "left" ? 0 : (root.width - width) / 2)
        y: root.edge === "bottom"
            ? root.height - Theme.dockDot
            : (root.height - height) / 2

        opacity: root.running ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
        }

        Behavior on width {
            NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
        }

        Behavior on height {
            NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
        }

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    // ── INPUT ───────────────────────────────────────────────────────────────

    HoverHandler {
        id: hover

        cursorShape: root.held ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        // The next item can be entered before this one is left, so only clear
        // the hover if it still points here.
        onHoveredChanged: {
            if (hover.hovered)
                root.capsule.hoveredIndex = root.index
            else if (root.capsule.hoveredIndex === root.index)
                root.capsule.hoveredIndex = -1
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        // A drag takes the grab, so a press that moved never arrives as a tap.
        onSingleTapped: (point, button) => {
            if (button === Qt.RightButton) {
                root.menuRequested(root.key)
                return
            }
            if (button === Qt.MiddleButton) {
                DockService.launch(root.modelData)
                return
            }
            DockService.activate(root.modelData)
        }
    }

    DragHandler {
        id: drag

        enabled: root.movable
        target: root

        // Constrained to the dock's axis.
        xAxis.enabled: !root.vertical
        yAxis.enabled: root.vertical
        xAxis.minimum: 0
        xAxis.maximum: Math.max(0, root.capsule.width - root.width)
        yAxis.minimum: 0
        yAxis.maximum: Math.max(0, root.capsule.height - root.height)

        onActiveChanged: {
            if (drag.active) {
                DockService.beginDrag(root.key, root.index)
                return
            }
            DockService.endDrag()
        }

    }

    // Tracked live while dragging, so the others make room. Uses the position
    // rather than the handler's translation, because the drop reads the
    // position. Saved only on drop.
    onXChanged: root.track()
    onYChanged: root.track()

    function track(): void {
        if (!drag.active)
            return
        DockService.dropAt = DockService.slotAt(
            (root.vertical ? root.y : root.x) + Theme.dockIcon / 2)
    }
}
