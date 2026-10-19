import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common

// One open window in the Overview: a live picture of the window
// (ScreencopyView — the same thing illogical-impulse's Overview uses),
// drawn at the window's real position and size on its workspace card,
// scaled down. Overview.qml owns the layout maths (`grid.rectFor`) and
// what a click / drop actually does; this file is the picture and the
// gestures.
//
// The tile lives in Overview.qml's `windowSpace`, a layer that sits
// *above* every workspace card, not inside one. That is what lets a
// tile be dragged from one card to another without being clipped by
// the card it started on, and it's why the workspace cards carry the
// DropAreas (see OverviewWorkspaceCard.qml) rather than the tiles.
//
// Gestures:
//   left click     focus this window (Overview closes)
//   middle click   close this window
//   left drag      pick it up. Drop it on another workspace card to move
//                  it there; drop a *floating* window on its own card to
//                  move it to that spot; anywhere else it springs back.
//
// The drag is done by hand in the MouseArea (press point, then offset
// from it) rather than `drag.target`, so `x`/`y` stay bindings to the
// window's real position forever. Dragging just adds `dragDX`/`dragDY`
// on top, and letting go zeroes them and the Behavior eases it home.
// With `drag.target` the first drag would overwrite the binding and the
// tile would be stuck at a stale position the next time the window
// moved while the Overview was closed.
Item {
    id: root

    // The Hyprland toplevel this tile shows, and the Overview.qml
    // Scope (rectFor(), captureActive, overviewMonitorId). Named
    // `grid` rather than something that could collide with an id.
    required property var toplevel
    required property var grid

    signal activated(var data)
    signal closeRequested(var data)
    signal dragBegan(var data)
    signal dragEnded(var data, real dx, real dy)

    // hyprctl uses "0x…" addresses; Quickshell's own may or may not
    // carry the prefix, so normalise before looking one up.
    readonly property string addrKey: {
        const a = root.toplevel ? (root.toplevel.address ?? "") : ""
        return a.startsWith("0x") ? a : "0x" + a
    }

    // Fresh hyprctl data first; Quickshell's own cached copy only as a
    // fallback for the instant between a window opening and the first
    // refresh landing.
    readonly property var windowData: {
        const d = HyprlandData.windowByAddress[root.addrKey]
        if (d)
            return d
        const l = root.toplevel ? root.toplevel.lastIpcObject : null
        return (l && l.at) ? l : null
    }

    readonly property var rect: root.grid.rectFor(root.windowData)

    readonly property string windowClass: {
        const d = root.windowData
        if (d && d.class)
            return d.class
        if (d && d.initialClass)
            return d.initialClass
        return (root.toplevel && root.toplevel.wayland) ? (root.toplevel.wayland.appId ?? "") : ""
    }

    readonly property string windowTitle: root.windowData ? (root.windowData.title ?? "") : ""

    readonly property bool focusedWindow: root.toplevel ? root.toplevel.activated === true : false

    // Same heuristic guess Dock.qml makes from a window's class; when it
    // can't resolve, iconName stays "" and the generic fallback shows.
    readonly property var desktopEntry: {
        if (root.windowClass === "")
            return null
        try {
            return DesktopEntries.heuristicLookup(root.windowClass)
        } catch (e) {
            return null
        }
    }
    readonly property string iconName: root.desktopEntry ? root.desktopEntry.icon : ""
    readonly property string iconSource: IconCursorService.path(root.iconName, "application-x-executable")

    // ===== position =====
    property real dragDX: 0
    property real dragDY: 0
    property real pressX: 0
    property real pressY: 0
    readonly property bool dragging: area.dragging

    readonly property real baseX: root.rect ? root.rect.x : 0
    readonly property real baseY: root.rect ? root.rect.y : 0

    x: root.baseX + root.dragDX
    y: root.baseY + root.dragDY
    width: root.rect ? root.rect.w : 0
    height: root.rect ? root.rect.h : 0
    visible: root.rect !== null && width > 1 && height > 1

    // Windows that live on another monitor are shown, but faded (same
    // call ii makes) so it's clear they aren't on this screen.
    opacity: (root.rect && root.grid.overviewMonitorId >= 0 && root.rect.monitorId != root.grid.overviewMonitorId) ? 0.45 : 1

    // Floating above tiled, fullscreen above that, whatever's being
    // dragged above everything.
    z: root.dragging ? 100000 : (1 + (root.rect && root.rect.floating ? 1 : 0) + (root.rect && root.rect.fullscreen > 0 ? 2 : 0))

    scale: root.dragging ? 1.05 : 1

    Behavior on x {
        enabled: !area.dragging
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        enabled: !area.dragging
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on width {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Drag.active: area.dragging
    Drag.hotSpot.x: root.pressX
    Drag.hotSpot.y: root.pressY
    Drag.dragType: Drag.Internal

    // Hard offset shadow, only while it's picked up — the same
    // offset-rectangle trick Pill.qml's cap and every dialog card use.
    Rectangle {
        x: 3
        y: 4
        width: root.width
        height: root.height
        radius: 7
        color: ScrapbookTheme.noteShadow
        opacity: root.dragging ? 0.75 : 0
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    // Backing colour, so a window that hasn't delivered a frame yet
    // still reads as a tile.
    Rectangle {
        anchors.fill: parent
        radius: 6
        color: Theme.paperEdge
    }

    // The picture. Inset by the border width so the outline (drawn on
    // top, below) covers the picture's square corners: with border 2 and
    // radius 6 the inset corner sits inside the rounded ring, so no mask
    // or layer effect is needed to get rounded corners.
    //
    // Only captures while the Overview is actually showing it (see
    // captureActive in Overview.qml): while you're typing a search, or
    // once it has closed, nothing is being captured.
    ScreencopyView {
        id: preview
        anchors.fill: parent
        anchors.margins: 2
        captureSource: (root.grid.captureActive && root.visible && root.toplevel) ? root.toplevel.wayland : null
        live: true
    }

    // Fallback: until the first frame arrives (or if this window can't
    // be captured), show its app icon large in the middle.
    Image {
        anchors.centerIn: parent
        visible: !preview.hasContent
        width: Math.max(14, Math.min(48, Math.min(root.width, root.height) * 0.5))
        height: width
        asynchronous: true
        smooth: true
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(width, height)
        source: root.iconSource
    }

    // Once the picture is showing, the icon shrinks to a small badge in
    // the corner so you can still tell what it is at a glance.
    Rectangle {
        id: badge
        readonly property real size: Math.max(12, Math.min(22, Math.min(root.width, root.height) * 0.28))
        x: 5
        y: 5
        width: size + 4
        height: size + 4
        radius: 5
        color: "#e6ffffff"
        visible: preview.hasContent && Math.min(root.width, root.height) > 36

        Image {
            anchors.centerIn: parent
            width: badge.size
            height: badge.size
            asynchronous: true
            smooth: true
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(width, height)
            source: root.iconSource
        }
    }

    // Hover / pressed tint.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        color: area.pressed ? "#333fa7c4" : (area.containsMouse ? "#223fa7c4" : "transparent")
        Behavior on color { ColorAnimation { duration: 90 } }
    }

    // Window title, on hover or while dragging.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 4
        height: titleText.implicitHeight + 6
        radius: 5
        color: "#e6ffffff"
        visible: (area.containsMouse || root.dragging) && root.width > 56 && root.height > 40 && root.windowTitle !== ""

        Text {
            id: titleText
            anchors.fill: parent
            anchors.leftMargin: 5
            anchors.rightMargin: 5
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: root.windowTitle
            color: ScrapbookTheme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.weight: Font.DemiBold
        }
    }

    // Outline on top of everything, focused window in cyan.
    Rectangle {
        anchors.fill: parent
        radius: 6
        color: "transparent"
        border.width: 2
        border.color: root.focusedWindow ? ScrapbookTheme.accentCurrent : ScrapbookTheme.ink
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        property bool dragging: false
        property point pressScene: Qt.point(0, 0)

        onPressed: mouse => {
            if (mouse.button !== Qt.LeftButton)
                return
            // The cursor's position in the shared layer, not in this
            // tile — this tile is about to move under the cursor, so
            // anything measured in its own coordinates would drift.
            area.pressScene = area.mapToItem(root.parent, mouse.x, mouse.y)
            root.pressX = mouse.x
            root.pressY = mouse.y
        }

        onPositionChanged: mouse => {
            if (!area.pressed || !(mouse.buttons & Qt.LeftButton))
                return
            const p = area.mapToItem(root.parent, mouse.x, mouse.y)
            const dx = p.x - area.pressScene.x
            const dy = p.y - area.pressScene.y
            if (!area.dragging) {
                // A few pixels of slack so a slightly wobbly click
                // still counts as a click.
                if (Math.abs(dx) + Math.abs(dy) < 8)
                    return
                area.dragging = true
                root.dragBegan(root.windowData)
            }
            root.dragDX = dx
            root.dragDY = dy
        }

        onReleased: mouse => {
            if (area.dragging) {
                // Report the drop *before* Drag.active goes false:
                // ending the drag is what clears the DropArea's idea of
                // which card it's over, and Overview.qml reads that.
                const dx = root.dragDX
                const dy = root.dragDY
                root.dragEnded(root.windowData, dx, dy)
                area.dragging = false
                root.dragDX = 0
                root.dragDY = 0
                return
            }
            if (mouse.button === Qt.LeftButton && area.containsMouse)
                root.activated(root.windowData)
            else if (mouse.button === Qt.MiddleButton && area.containsMouse)
                root.closeRequested(root.windowData)
        }

        onCanceled: {
            if (area.dragging) {
                area.dragging = false
                root.dragDX = 0
                root.dragDY = 0
                root.dragEnded(null, 0, 0)
            }
        }
    }
}
