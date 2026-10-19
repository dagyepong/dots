import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Edit Desktop's shelf: a long card that slides up from the bottom edge while
// the desktop shrinks into its frame above it. It replaces the old side
// drawer's ON / OFF tiles with the widgets themselves: each one is drawn as it
// really looks (EditTraySlot.qml, from the picture the widget's own window
// takes of its card, EditPreview.qml).
//
//   left of the shelf    the title and a three-line "how to" (L add / edit,
//                        R remove, drag to move), which also says which widget
//                        is being edited
//   the shelf            one slot per widget: left click adds it (or edits it,
//                        if it is on the desktop already), right click removes
//   right of the shelf   Lock all (it can only be changed here) and Done
//
// Esc stops editing the selected widget first, and leaves the mode the next
// time. Done leaves at once.
//
// It is a full-width Overlay window along the bottom edge, only while a
// monitor is being edited, and its click region is just the card itself, so
// everything beside and above it keeps working as normal. It takes the
// keyboard (Esc) while the mode is on, but NOT with Exclusive for the whole
// time: a layer surface that holds Exclusive keyboard focus also holds the
// pointer, so the widgets above could not be clicked or dragged (p3dro's
// EditMode hit the same thing). Exclusive is held for a beat when the mode
// opens, to seed keyboard focus, then dropped to OnDemand, which keeps the
// focus but frees the pointer. `qs -c sekaipop ipc call desktopedit close`
// still ends the mode if anything ever goes wrong.
//
// The layer namespace is still "sekaipop-edit-drawer": a layerrule written for
// the old drawer keeps working.
//
// To put another widget on the shelf, add it to EditMode.widgetList (and to
// widgetOn / addWidget / removeWidget there). Nothing changes in this file.
//
// Six tabs, on the left of the shelf: WIDGETS (the slots above), BAR (the
// bar's style and edge, then its left / center / right arrangement, EditBarLayout.qml),
// DOCK (its edge, hiding and pin, EditDockBoard.qml), VIEWS (the Quick Panel
// phone's 2.5D / 2D, the overview's style, side and size, and how many workspace
// pills the bar shows, EditViewsBoard.qml),
// THEME (the colour groups as little previews, EditThemeBoard.qml; Ctrl+Shift+T and
// `ipc call theme toggle` open Edit Desktop straight on it) and PRESETS (the
// whole look saved under a name, EditPresetBoard.qml; `ipc call presets
// toggle` opens Edit Desktop straight on it).
PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === EditMode.screenName) ?? Quickshell.screens[0]

    readonly property real uiScale: ShellScale.forScreen(win.screen)

    visible: EditMode.screenName !== ""

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sekaipop-edit-drawer"
    // Exclusive only for the first moments of the mode (see the header).
    property bool focusSeed: false

    Timer {
        id: focusSeedTimer
        interval: 150
        onTriggered: win.focusSeed = false
    }

    // Which tab the shelf shows: "widgets", "bar", "dock", "views", "theme" or "presets".
    property string tab: "widgets"

    // The tabs made of little pick keys (DOCK, VIEWS): a click changes it, and it applies at once.
    readonly property bool pickTab: win.tab === "dock" || win.tab === "views"

    // EditMode asks for a tab when it opens (or while it is open), and wants
    // to know which one is showing (Ctrl+Shift+T closes it from the THEME tab).
    onTabChanged: EditMode.currentTab = win.tab

    function seedFocus() {
        if (!EditMode.active)
            return
        win.focusSeed = true
        focusSeedTimer.restart()
    }

    Connections {
        target: EditMode

        function onActiveChanged() {
            if (EditMode.active) {
                win.tab = EditMode.requestedTab
                win.seedFocus()
            } else {
                win.focusSeed = false
                focusSeedTimer.stop()
            }
        }
    }

    Connections {
        target: EditMode

        function onTabSerialChanged() {
            if (!EditMode.active)
                return
            if (EditMode.requestedTab !== "widgets")
                EditMode.select("")
            win.tab = EditMode.requestedTab
        }
    }

    onVisibleChanged: {
        if (win.visible)
            win.seedFocus()
    }

    WlrLayershell.keyboardFocus: win.focusSeed ? WlrKeyboardFocus.Exclusive
        : (EditMode.active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    implicitHeight: Math.round(EditMode.trayHeight * win.uiScale)

    anchors {
        left: true
        right: true
        bottom: true
    }

    // Only the card takes clicks (plus what pokes out above it: the tape, the
    // slots' corner badges). In real window pixels, so the design rectangle
    // times the scale; it follows the slide-in.
    Item {
        id: hit
        x: Math.max(0, Math.round(tray.x * win.uiScale))
        y: Math.max(0, Math.round((tray.y - 14) * win.uiScale))
        width: Math.max(1, Math.round(tray.width * win.uiScale))
        height: Math.max(1, Math.round((tray.height + 14) * win.uiScale))
    }

    mask: Region {
        item: hit
    }

    // Esc: stop editing the selected widget; with none selected, leave.
    Item {
        id: escKeys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            if (EditMode.editTarget !== "")
                EditMode.select("")
            else
                EditMode.close()
        }
    }

    function titleOf(id) {
        for (const w of EditMode.widgetList) {
            if (w.id === id)
                return w.title
        }
        // One of the pictures on the desktop (ImageWidget.qml): "image:<id>".
        if (id.indexOf("image:") === 0)
            return "Image"
        return id
    }

    // One line of the how-to: a keycap, then what it does.
    component HintRow: Item {
        id: hr

        property string keyText: ""
        property string keyIcon: ""
        property string label: ""

        width: 214
        height: 26

        Pill {
            width: 34
            height: 26
            cornerRadius: 8
            ringWidth: 3
            shadowDy: 3
            fillColor: Theme.chipFill

            Text {
                anchors.centerIn: parent
                visible: hr.keyIcon === ""
                text: hr.keyText
                color: Theme.chipInk
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: hr.keyIcon !== ""
                name: hr.keyIcon
                size: 13
                weight: 700
                color: Theme.chipInk
            }
        }

        Text {
            x: 44
            anchors.verticalCenter: parent.verticalCenter
            text: hr.label
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }

    // One of the six tabs on the left of the shelf: a big key (icon over name) in the
    // same look as Lock all / Done on the right (ring 4, shadow 4, corner 15).
    component TabKey: Item {
        id: tk

        property string icon: ""
        property string label: ""
        property bool on: false

        signal activated()

        width: 84
        height: 62

        Gradient {
            id: tkFill
            GradientStop { position: 0.0; color: Theme.accentMint }
            GradientStop { position: 1.0; color: Theme.accentCyan }
        }

        Pill {
            anchors.fill: parent
            cornerRadius: 15
            ringWidth: 7
            shadowDy: 4
            pressed: tkArea.pressed
            fillColor: tkArea.containsMouse && !tk.on ? Theme.pSurfaceHover : Theme.pSurface
            fillGradient: tk.on ? tkFill : null

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -2
                spacing: 1

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: tk.icon
                    size: 26
                    weight: 600
                    color: tk.on ? Theme.colBorder : Theme.pInk
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tk.label
                    color: tk.on ? Theme.colBorder : Theme.pInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                    font.letterSpacing: 0.8
                }
            }
        }

        MouseArea {
            id: tkArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: tk.activated()
        }
    }

    ScaleHost {
        id: host
        anchors.fill: parent
        factor: win.uiScale

        // ===== the card =====
        Pill {
            id: tray

            // Keeps the classic (white) look in the first dark mode; see Theme.classicFor.
            readonly property bool classicPanel: true

            // Comes up from the bottom edge along the same progress the desktop
            // shrinks with, so it overshoots and settles with it (never past
            // its resting place: the window ends right above it).
            readonly property real slide: Math.max(0, 1 - EditMode.progress) * (tray.height + 60)

            x: 22
            width: parent.width - 44
            height: 192
            y: parent.height - 14 - tray.height + tray.slide

            cornerRadius: Theme.radiusOuter
            ringWidth: Theme.borderWidth + Theme.outerRingWidth
            ringColorTop: Theme.pSurfaceRing
            ringColorBottom: ringColorTop
            fillColor: Theme.pSurface

            // ===== left =====
            Column {
                id: info
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 214
                spacing: 6

                Item {
                    width: info.width
                    height: 38

                    Rectangle {
                        id: headDiamond
                        x: 4
                        y: 4
                        width: 16
                        height: 16
                        radius: 4
                        rotation: 45
                        color: Theme.accentMint
                        border.width: 2
                        border.color: Theme.pLine
                        antialiasing: true
                    }

                    Text {
                        anchors.left: headDiamond.right
                        anchors.leftMargin: 12
                        anchors.verticalCenter: headDiamond.verticalCenter
                        text: "EDIT DESKTOP"
                        color: Theme.pInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }

                    // What is going on, in a few words.
                    Text {
                        y: 25
                        width: parent.width
                        elide: Text.ElideRight
                        text: win.tab === "theme"
                            ? "Pick the colours the shell wears."
                            : win.tab === "presets"
                            ? "Save the whole look, wear it again."
                            : win.tab === "bar"
                            ? "Its look, its edge, and what sits on it."
                            : win.tab === "dock"
                            ? "Its look, where it sits, when it hides."
                            : win.tab === "views"
                            ? "The phone, the overview, and the bar's workspaces."
                            : (EditMode.editTarget !== ""
                            ? "Editing " + win.titleOf(EditMode.editTarget) + " \u2014 click the card to let go"
                            : "Pick it, place it, tweak it.")
                        color: win.tab === "widgets" && EditMode.editTarget !== "" ? Theme.pInk : Theme.pInkSub
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }

                HintRow {
                    keyText: win.tab === "bar" ? "" : "L"
                    keyIcon: win.tab === "bar" ? "open_with" : ""
                    label: win.tab === "bar" ? "Drag: move, or into OFF"
                        : (win.tab === "theme" ? "Click: wear this theme"
                        : (win.tab === "presets" ? "Click: wear this look"
                        : (win.pickTab ? "Click: change it" : "Left click: add / edit")))
                }

                HintRow {
                    keyText: win.tab === "bar" ? "L" : (win.tab === "theme" || win.pickTab ? "" : "R")
                    keyIcon: win.tab === "theme" || win.pickTab ? "mouse" : ""
                    label: win.tab === "bar" ? "Click: next zone / back on"
                        : (win.tab === "theme" ? "Wheel: more themes"
                        : (win.tab === "presets" ? "Right click twice: delete"
                        : (win.pickTab ? "Hover: see its name" : "Right click: remove")))
                }

                HintRow {
                    keyText: win.tab === "bar" ? "R" : ""
                    keyIcon: win.tab === "bar" ? ""
                        : (win.tab === "theme" ? "wallpaper" : (win.tab === "presets" ? "sync" : (win.pickTab ? "check" : "open_with")))
                    label: win.tab === "bar" ? "Right click: remove"
                        : (win.tab === "theme" ? "Matugen: from wallpaper"
                        : (win.tab === "presets" ? "Hover: save over it" : (win.pickTab ? "Applies at once" : "Drag: move")))
                }
            }

            Rectangle {
                id: dividerLeft
                x: 16 + 214 + 14
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 132
                radius: 1
                color: Theme.pSurfaceDivider
            }

            // ===== right: Lock all and Done =====
            Column {
                id: actions
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 170
                spacing: 12

                // Locks every widget at once. Locked widgets can't be moved on the
                // normal desktop; here, while editing, they can always be dragged,
                // and the lock applies again after Done.
                Item {
                    id: lockTile
                    width: actions.width
                    height: 54

                    Gradient {
                        id: lockFill
                        GradientStop { position: 0.0; color: Theme.accentMint }
                        GradientStop { position: 1.0; color: Theme.accentCyan }
                    }

                    Pill {
                        anchors.fill: parent
                        cornerRadius: 15
                        ringWidth: 4
                        shadowDx: 0
                        shadowDy: 4
                        pressed: lockArea.pressed
                        fillColor: lockArea.containsMouse ? Theme.pSurfaceHover : Theme.pSurface
                        fillGradient: EditMode.widgetsLocked ? lockFill : null

                        MaterialIcon {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            name: EditMode.widgetsLocked ? "lock" : "lock_open"
                            size: 22
                            weight: 600
                            color: EditMode.widgetsLocked ? Theme.colBorder : Theme.pInk
                        }

                        Column {
                            x: 44
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            Text {
                                text: "LOCK ALL"
                                color: EditMode.widgetsLocked ? Theme.colBorder : Theme.pInk
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.ExtraBold
                                font.styleName: Theme.fontStyleBold
                                font.letterSpacing: 0.8
                            }

                            Text {
                                text: EditMode.widgetsLocked ? "stay put after Done" : "free on the desktop"
                                color: EditMode.widgetsLocked ? Theme.colBorder : Theme.pInkSub
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    MouseArea {
                        id: lockArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: EditMode.toggleWidgetsLocked()
                    }
                }

                Item {
                    id: doneTile
                    width: actions.width
                    height: 54

                    Pill {
                        anchors.fill: parent
                        cornerRadius: 15
                        ringWidth: 4
                        shadowDx: 0
                        shadowDy: 4
                        pressed: doneArea.pressed
                        fillGradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.accentMint }
                            GradientStop { position: 1.0; color: Theme.accentCyan }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "check"
                                size: 22
                                weight: 700
                                color: Theme.colBorder
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "DONE"
                                color: Theme.colBorder
                                font.family: Theme.fontFamily
                                font.pixelSize: 17
                                font.weight: Font.ExtraBold
                                font.styleName: Theme.fontStyleBold
                                font.letterSpacing: 1
                            }
                        }
                    }

                    MouseArea {
                        id: doneArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: EditMode.close()
                    }
                }
            }

            Rectangle {
                id: dividerRight
                anchors.right: actions.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 132
                radius: 1
                color: Theme.pSurfaceDivider
            }

            // ===== the tabs =====
            // A 3 x 2 block of big keys: the shelf is only 192 tall, so six in a column
            // could not be any bigger than they were.
            Grid {
                id: tabs
                anchors.left: dividerLeft.right
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                columns: 3
                spacing: 8

                TabKey {
                    icon: "widgets"
                    label: "WIDGETS"
                    on: win.tab === "widgets"
                    onActivated: win.tab = "widgets"
                }

                TabKey {
                    icon: "dock_to_bottom"
                    label: "BAR"
                    on: win.tab === "bar"
                    onActivated: {
                        EditMode.select("")
                        win.tab = "bar"
                    }
                }

                TabKey {
                    icon: "bottom_navigation"
                    label: "DOCK"
                    on: win.tab === "dock"
                    onActivated: {
                        EditMode.select("")
                        win.tab = "dock"
                    }
                }

                TabKey {
                    icon: "smartphone"
                    label: "VIEWS"
                    on: win.tab === "views"
                    onActivated: {
                        EditMode.select("")
                        win.tab = "views"
                    }
                }

                TabKey {
                    icon: "palette"
                    label: "THEME"
                    on: win.tab === "theme"
                    onActivated: {
                        EditMode.select("")
                        win.tab = "theme"
                    }
                }

                TabKey {
                    icon: "bookmarks"
                    label: "PRESETS"
                    on: win.tab === "presets"
                    onActivated: {
                        EditMode.select("")
                        win.tab = "presets"
                    }
                }
            }

            // ===== the bar tab =====
            EditBarLayout {
                id: barEditor
                visible: win.tab === "bar"
                anchors.left: tabs.right
                anchors.leftMargin: 14
                anchors.right: dividerRight.left
                anchors.rightMargin: 14
                anchors.top: parent.top
                anchors.topMargin: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
            }

            // ===== the dock tab =====
            EditDockBoard {
                visible: win.tab === "dock"
                anchors.left: tabs.right
                anchors.leftMargin: 14
                anchors.right: dividerRight.left
                anchors.rightMargin: 14
                anchors.top: parent.top
                anchors.topMargin: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
            }

            // ===== the views tab =====
            EditViewsBoard {
                visible: win.tab === "views"
                anchors.left: tabs.right
                anchors.leftMargin: 14
                anchors.right: dividerRight.left
                anchors.rightMargin: 14
                anchors.top: parent.top
                anchors.topMargin: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
            }

            // ===== the theme tab =====
            EditThemeBoard {
                visible: win.tab === "theme"
                anchors.left: tabs.right
                anchors.leftMargin: 14
                anchors.right: dividerRight.left
                anchors.rightMargin: 14
                anchors.top: parent.top
                anchors.bottom: parent.bottom
            }

            // ===== the presets tab =====
            EditPresetBoard {
                visible: win.tab === "presets"
                anchors.left: tabs.right
                anchors.leftMargin: 14
                anchors.right: dividerRight.left
                anchors.rightMargin: 14
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                // The name field took the keyboard; give it back so Esc
                // still leaves Edit Desktop.
                onFinished: escKeys.forceActiveFocus()
            }

            // ===== the shelf =====
            Flickable {
                id: shelf
                visible: win.tab === "widgets"
                anchors.left: tabs.right
                anchors.leftMargin: 14
                anchors.right: dividerRight.left
                anchors.rightMargin: 14
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                // Room around the row: a slot's tilt, hover lift, corner badge
                // and name tag all poke out past its frame, so the row sits
                // inside padding instead of touching the shelf's clip edge.
                readonly property real padX: 22
                readonly property real padTop: 20
                readonly property real padBottom: 18

                contentWidth: Math.max(shelf.width, shelfRow.width + shelf.padX * 2)
                contentHeight: shelf.height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                // Not clipped while everything fits, so a slot's corner badge and
                // its lift can poke out above the shelf.
                clip: shelf.contentWidth > shelf.width + 1

                // The wheel scrolls the shelf sideways (a notch moves Theme.wheelStep px,
                // a touchpad follows the fingers). Dragging still works as before.
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const hi = Math.max(0, shelf.contentWidth - shelf.width)
                        if (hi <= 0)
                            return
                        const raw = Theme.wheelPx(event, true)
                        shelf.cancelFlick()
                        shelf.contentX = Math.max(0, Math.min(hi, shelf.contentX - raw))
                    }
                }

                Row {
                    id: shelfRow
                    x: Math.max(shelf.padX, (shelf.width - shelfRow.width) / 2)
                    y: shelf.padTop
                    spacing: 32

                    Repeater {
                        model: EditMode.widgetList

                        EditTraySlot {
                            required property var modelData
                            required property int index

                            widgetId: modelData.id
                            title: modelData.title
                            icon: modelData.icon
                            slotIndex: index
                        }
                    }
                }
            }

            // A thin marker under the shelf while it has more than fits: where you are.
            Rectangle {
                readonly property real span: Math.max(1, shelf.contentWidth)
                readonly property bool needed: win.tab === "widgets" && shelf.contentWidth > shelf.width + 1

                visible: needed
                height: 4
                radius: 2
                y: parent.height - 12
                width: Math.max(36, shelf.width * shelf.width / span)
                x: shelf.x + (shelf.width - width) * (shelf.contentWidth > shelf.width
                    ? shelf.contentX / (shelf.contentWidth - shelf.width) : 0)
                color: Theme.pInkSub
                opacity: 0.55
            }
        }

        // ===== tape across the top corners =====
        WashiTape {
            x: tray.x + 56
            y: tray.y - 12
            width: 92
            height: 24
            rotation: -5
            color: ScrapbookTheme.tapeMint
        }

        WashiTape {
            x: tray.x + tray.width - 150
            y: tray.y - 12
            width: 92
            height: 24
            rotation: 4
            color: ScrapbookTheme.tapePink
        }
    }
}
