import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// One window in the dock's window overview (the card that opens over a running
// app's key, see Dock.qml): a live picture of the window (ScreencopyView, the
// same thing the Overview's tiles use), its title along the bottom, and the
// same navy outline / hard shadow as every other card in the shell. The window
// that has the focus has a cyan outline.
//
//   left click     jump to this window
//   middle click   close it
//   the x badge    close it (shows while the pointer is on the tile)
//
// The picture is only captured while the card is open (`capture`).
Item {
    id: root

    // The window: an entry of Dock.qml's runningMaps `wins`
    // ({ address, workspaceId, active, toplevel }), or null for the instant
    // between it closing and the card noticing.
    property var win: null
    property string address: ""
    // The app's icon, shown until the first frame arrives.
    property string iconName: ""
    property bool capture: false
    property real tileH: 150

    signal activated()
    signal closeRequested()
    signal minimizeRequested()

    // True for a window that is minimized (it is on a hidden workspace, so the
    // picture may be empty: the app's icon shows instead).
    readonly property bool minimized: root.win ? root.win.min === true : false
    readonly property var toplevel: root.win ? root.win.toplevel : null
    readonly property bool focusedWindow: root.win ? root.win.active === true : false
    readonly property string title: root.toplevel
        ? (root.toplevel.title || root.toplevel.lastIpcObject?.title || "") : ""

    // hyprctl uses "0x..." addresses; Quickshell's may or may not have the
    // prefix (same note as OverviewWindowTile.qml).
    readonly property string addrKey: root.address.startsWith("0x") ? root.address : "0x" + root.address
    readonly property var hyprData: HyprlandData.windowByAddress[root.addrKey] ?? null

    // The window's own shape, so the picture isn't stretched.
    readonly property real aspect: {
        const s = root.hyprData ? root.hyprData.size : null
        return (s && s[0] > 0 && s[1] > 0) ? Math.max(0.7, Math.min(2.4, s[0] / s[1])) : 1.6
    }

    width: Math.round(Math.max(160, Math.min(290, root.tileH * root.aspect)))
    height: root.tileH

    scale: area.containsMouse ? 1.04 : 1
    Behavior on scale {
        NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 2 }
    }

    // The hard shadow.
    Rectangle {
        x: 3
        y: 4
        width: root.width
        height: root.height
        radius: 12
        color: Theme.lineShadow
        antialiasing: true
    }

    // Behind the picture, so a window that hasn't sent a frame yet still reads
    // as a tile.
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.surfaceDivider
        antialiasing: true
    }

    // The picture, inset by the outline's width: the outline (drawn on top,
    // below) covers its square corners, so no mask is needed for rounded corners
    // (same trick as OverviewWindowTile.qml).
    ScreencopyView {
        id: preview
        anchors.fill: parent
        anchors.margins: Theme.borderWidth
        captureSource: (root.capture && root.toplevel) ? root.toplevel.wayland : null
        live: true
    }

    // Until the first frame arrives (or if this window can't be captured): the
    // app's icon.
    Image {
        anchors.centerIn: parent
        visible: !preview.hasContent
        width: Math.min(64, Math.min(root.width, root.height) * 0.45)
        height: width
        asynchronous: true
        smooth: true
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(width, height)
        source: IconCursorService.path(root.iconName, "application-x-executable")
    }

    // Pointer on the tile: a pale cyan wash over the picture.
    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.borderWidth
        color: Qt.rgba(Theme.accentCyan.r, Theme.accentCyan.g, Theme.accentCyan.b,
                       area.pressed ? 0.28 : (area.containsMouse ? 0.16 : 0))
        Behavior on color { ColorAnimation { duration: 90 } }
    }

    // The window's title.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        height: 24
        radius: 7
        color: Theme.surface
        opacity: 0.94
        visible: root.title !== ""

        Text {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: root.title
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }

    // The outline, on top: cyan for the window you are in, mint under the pointer.
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: root.focusedWindow ? Theme.accentCyan
            : (area.containsMouse ? Theme.accentMint : Theme.line)
        antialiasing: true
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton)
                root.closeRequested()
            else
                root.activated()
        }
    }

    // The close badge. Declared after the tile's own MouseArea so it takes its
    // own click.
    Rectangle {
        id: badge
        x: root.width - width - 8
        y: 8
        width: 26
        height: 26
        radius: 8
        color: Theme.surface
        border.width: 2
        border.color: closeArea.containsMouse ? Theme.accentMint : Theme.line
        opacity: area.containsMouse || closeArea.containsMouse ? 1 : 0
        visible: opacity > 0.01
        antialiasing: true

        Behavior on opacity {
            NumberAnimation { duration: 110 }
        }

        MaterialIcon {
            anchors.centerIn: parent
            name: "close"
            size: 17
            weight: 700
        }

        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeRequested()
        }
    }

    // Minimize (or, on a minimized window, bring it back). Left of the x.
    Rectangle {
        id: minBadge
        x: badge.x - width - 6
        y: 8
        width: 26
        height: 26
        radius: 8
        color: Theme.surface
        border.width: 2
        border.color: minArea.containsMouse ? Theme.accentMint : Theme.line
        opacity: area.containsMouse || closeArea.containsMouse || minArea.containsMouse ? 1 : 0
        visible: opacity > 0.01
        antialiasing: true

        Behavior on opacity {
            NumberAnimation { duration: 110 }
        }

        MaterialIcon {
            anchors.centerIn: parent
            name: root.minimized ? "open_in_full" : "remove"
            size: 17
            weight: 700
        }

        MouseArea {
            id: minArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: root.minimizeRequested()
        }
    }

    // Marks a minimized window.
    Rectangle {
        visible: root.minimized
        x: 8
        y: 8
        height: 22
        width: minText.implicitWidth + 16
        radius: 7
        color: Theme.accentCyan
        border.width: 2
        border.color: Theme.line
        antialiasing: true

        Text {
            id: minText
            anchors.centerIn: parent
            text: "minimized"
            color: Theme.colBorder
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.ExtraBold
        }
    }
}
