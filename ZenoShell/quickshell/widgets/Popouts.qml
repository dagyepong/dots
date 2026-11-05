import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.services
import qs.pages

// Panels of the "Vertical" style. Each one grows out of the bar: same color, with rounded joins
// (concave corners where it meets the bar), so bar and panel look like a single piece.
Item {
    id: root

    property string screenName: ""
    property real barW: 46
    property real edge: 8
    property real fillet: 22             // concave join with the bar
    property real corner: 22             // outer corners of the panel
    property real stageH: 800
    property bool railHovered: false

    property string current: ""
    property real anchorY: 0

    // Same interface as the other islands, so the bar can drive it (Esc)
    readonly property bool expanded: current !== ""
    readonly property bool needsKeyboard: expanded && current === "wifi" && wifiPage.needsKeyboard
    // Only launcher and power menu take the keyboard: the others open on hover and must not steal it
    readonly property bool wantsKeyboard: current === "launcher" || current === "power" || current === "capture" || current === "naming" || current === "theme"
    readonly property bool busy: needsKeyboard || current === "power" || current === "theme" || current === "capture" || current === "naming"
                                 || (current === "launcher" && launcherPanel.query !== "")
                                 || soundPage.dragging || displayPage.dragging || toolsPage.dragging
                                 || monitorsPage.dragging || quickPanel.dragging || calendarPanel.dragging
    readonly property bool hovered: panelHover.hovered
    property alias panel: panelBox

    function gotoPage(i) {}

    // name -> [content width, content height]
    readonly property var sizes: ({
        "calendar":  [340, 330],
        "media":     [300, 392],
        "notifs":    [340, 420],
        "quick":     [340, 344],
        "tools":     [360, 546],
        "wifi":      [360, 440],
        "bluetooth": [360, 440],
        "sound":     [360, 440],
        "display":   [360, 440],
        "monitors":  [360, 406],
        "launcher":  [480, 380],
        "power":     [470, 190],
        "theme":     [700, 184],
        "capture":   [470, 196],
        "record":    [360, Math.max(200, Math.round(recordPanel.implicitHeight))],
        "naming":    [380, Math.round(namingPanel.implicitHeight)]
    })

    property var lastSize: [340, 330]

    function open(name, cy) {
        anchorY = cy
        current = name
        closeTimer.stop()
    }

    // Mouse over a button: opens its panel (after a short pause, so passing by does not open anything),
    // or switches at once if another panel is already open
    property string pendingName: ""
    property real pendingY: 0

    // Click: opens the panel; a second click on the power button closes the menu
    function activate(name, cy) {
        if (current === name && (name === "power" || name === "theme")) close()
        else open(name, cy)
    }

    function hoverOpen(name, cy) {
        if (current === name) { closeTimer.stop(); return }
        // Someone typing in the launcher, or choosing in the power menu, is not interrupted by hovering the bar
        if (current === "power" || current === "theme" || current === "capture" || current === "naming" || (current === "launcher" && busy)) return
        if (current !== "") { open(name, cy); return }
        pendingName = name
        pendingY = cy
        hoverTimer.restart()
    }

    function hoverCancel() { hoverTimer.stop() }

    Timer {
        id: hoverTimer
        interval: 170
        onTriggered: root.open(root.pendingName, root.pendingY)
    }

    function close() { current = "" }

    // ---------- Launcher and power menu follow UiState (shortcuts, typing on an empty desktop, qs ipc) ----------
    function mine(name) { return name === "" || name === screenName }

    property string prev: ""

    onCurrentChanged: {
        const was = prev
        prev = current
        if (current !== "" && sizes[current]) lastSize = sizes[current]

        // Closing the name prompt in any way keeps the recording (with the date and time name)
        if (was === "naming" && current !== "naming" && Capture.naming) Capture.finishNaming("")

        if (current === "capture") {
            UiState.captureScreen = screenName
            UiState.launcherOpen = false
            UiState.powerOpen = false
            UiState.recMenuOpen = false
            UiState.captureOpen = true
            resetTimer.start()
        } else if (UiState.captureOpen && mine(UiState.captureScreen)) {
            UiState.captureOpen = false
        }

        if (current === "record") {
            UiState.recMenuScreen = screenName
            UiState.recMenuOpen = true
        } else if (UiState.recMenuOpen && mine(UiState.recMenuScreen)) {
            UiState.recMenuOpen = false
        }

        if (current === "naming") resetTimer.start()

        if (current === "theme" && root.visible) {
            Appearance.pickerScreen = screenName
            Appearance.pickerOpen = true
            resetTimer.start()
        } else if (Appearance.pickerOpen && mine(Appearance.pickerScreen)) {
            Appearance.pickerOpen = false
        }

        if (current === "launcher") {
            UiState.launcherScreen = screenName
            UiState.powerOpen = false
            UiState.launcherOpen = true
            resetTimer.start()
        } else if (current === "power") {
            UiState.powerScreen = screenName
            UiState.launcherOpen = false
            UiState.powerOpen = true
            resetTimer.start()
        } else {
            if (UiState.launcherOpen && mine(UiState.launcherScreen)) UiState.launcherOpen = false
            if (UiState.powerOpen && mine(UiState.powerScreen)) UiState.powerOpen = false
        }
    }

    // After the panel is visible: focus the search / pick the first action
    Timer {
        id: resetTimer
        interval: 60
        onTriggered: {
            if (root.current === "launcher") launcherPanel.reset()
            else if (root.current === "power") powerPanel.reset()
            else if (root.current === "theme") themePanel.reset()
            else if (root.current === "capture") capturePanel.reset()
            else if (root.current === "naming") namingPanel.reset()
        }
    }

    // The recording is over: the name prompt comes out of the bar
    Connections {
        target: Capture

        function onNamingChanged() {
            if (Capture.naming) {
                if (root.mine(Capture.pendingScreen)) root.open("naming", root.stageH / 2)
            } else if (root.current === "naming") {
                root.close()
            }
        }
    }

    Connections {
        target: Appearance

        function onPickerOpenChanged() {
            // in the other styles the pill shows the selector: this panel must stay closed
            if (!root.visible) return
            if (Appearance.pickerOpen) {
                if (root.mine(Appearance.pickerScreen) && root.current !== "theme")
                    root.open("theme", root.stageH / 2)
            } else if (root.current === "theme") {
                root.close()
            }
        }
    }

    Connections {
        target: UiState

        function onLauncherOpenChanged() {
            if (UiState.launcherOpen) {
                if (root.mine(UiState.launcherScreen) && root.current !== "launcher")
                    root.open("launcher", root.stageH / 2)
            } else if (root.current === "launcher") {
                root.close()
            }
        }

        function onCaptureOpenChanged() {
            if (UiState.captureOpen) {
                if (root.mine(UiState.captureScreen) && root.current !== "capture")
                    root.open("capture", root.stageH / 2)
            } else if (root.current === "capture") {
                root.close()
            }
        }

        function onRecMenuOpenChanged() {
            if (UiState.recMenuOpen) {
                if (root.mine(UiState.recMenuScreen) && root.current !== "record")
                    root.open("record", root.anchorY > 0 ? root.anchorY : root.stageH / 2)
            } else if (root.current === "record") {
                root.close()
            }
        }

        function onPowerOpenChanged() {
            if (UiState.powerOpen) {
                if (root.mine(UiState.powerScreen) && root.current !== "power")
                    root.open("power", root.stageH / 2)
            } else if (root.current === "power") {
                root.close()
            }
        }
    }

    // ---------- Size and position (elastic) ----------
    readonly property real inset: 2                       // the panel overlaps the bar a little: no seam
    readonly property real targetW: current !== "" ? lastSize[0] + inset : 0
    property real pw: targetW
    property real ph: lastSize[1]
    property real py: Math.max(edge + fillet * 2, Math.min(stageH - edge - fillet * 2 - ph, anchorY - ph / 2))

    Behavior on pw {
        NumberAnimation {
            duration: root.current !== "" ? 640 : 220
            easing.type: root.current !== "" ? Easing.OutElastic : Easing.OutCubic
            easing.amplitude: 1.0
            easing.period: 0.8
        }
    }
    Behavior on ph {
        NumberAnimation { duration: 520; easing.type: Easing.OutElastic; easing.amplitude: 1.0; easing.period: 0.8 }
    }
    Behavior on py {
        enabled: root.current !== ""
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }

    // ---------- Close when the mouse leaves ----------
    function check() {
        if (current !== "" && !hovered && !railHovered) closeTimer.restart()
        else closeTimer.stop()
    }
    onHoveredChanged: check()
    onRailHoveredChanged: check()

    Timer {
        id: closeTimer
        interval: 380
        onTriggered: {
            if (root.busy) restart()
            else root.close()
        }
    }

    // ---------- The panel ----------
    Item {
        id: panelBox

        x: root.barW - root.inset
        y: root.py
        width: root.pw
        height: root.ph
        visible: root.pw > 6

        HoverHandler { id: panelHover }

        // Round corners shrink with the width while it opens, so the shape is always valid
        readonly property real cf: Math.max(1, Math.min(root.fillet, (width - root.inset) / 2.5))
        readonly property real cr: Math.max(1, Math.min(root.corner, (width - root.inset - cf) / 2))

        Shape {
            x: 0
            y: -root.fillet
            width: panelBox.width
            height: panelBox.height + root.fillet * 2
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.island
                strokeWidth: -1

                // On the bar, above the panel
                startX: 0; startY: root.fillet - panelBox.cf
                PathLine { x: root.inset; y: root.fillet - panelBox.cf }
                // Concave corner up to the top edge of the panel
                PathArc {
                    x: root.inset + panelBox.cf; y: root.fillet
                    radiusX: panelBox.cf; radiusY: panelBox.cf
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: panelBox.width - panelBox.cr; y: root.fillet }
                PathArc {
                    x: panelBox.width; y: root.fillet + panelBox.cr
                    radiusX: panelBox.cr; radiusY: panelBox.cr
                    direction: PathArc.Clockwise
                }
                PathLine { x: panelBox.width; y: root.fillet + panelBox.height - panelBox.cr }
                PathArc {
                    x: panelBox.width - panelBox.cr; y: root.fillet + panelBox.height
                    radiusX: panelBox.cr; radiusY: panelBox.cr
                    direction: PathArc.Clockwise
                }
                PathLine { x: root.inset + panelBox.cf; y: root.fillet + panelBox.height }
                // Concave corner down to the bar
                PathArc {
                    x: root.inset; y: root.fillet + panelBox.height + panelBox.cf
                    radiusX: panelBox.cf; radiusY: panelBox.cf
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: 0; y: root.fillet + panelBox.height + panelBox.cf }
                PathLine { x: 0; y: root.fillet - panelBox.cf }
            }
        }

        // Content: fixed size, clipped by the growing shape
        Item {
            x: root.inset
            width: Math.max(0, panelBox.width - root.inset)
            height: panelBox.height
            clip: true

            CalendarPanel {
                id: calendarPanel
                opacity: root.current === "calendar" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }

            MusicPanel {
                opacity: root.current === "media" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }

            NotifPanel {
                opacity: root.current === "notifs" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }

            QuickPanel {
                id: quickPanel
                opacity: root.current === "quick" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                onOpenPanel: name => root.open(name, root.anchorY)
            }

            ToolsPage {
                id: toolsPage
                opacity: root.current === "tools" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                onBack: root.close()
                onPasted: root.close()
            }

            WifiPage {
                id: wifiPage
                opacity: root.current === "wifi" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                onBack: root.close()
            }

            BluetoothPage {
                id: btPage
                opacity: root.current === "bluetooth" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                onBack: root.close()
            }

            SoundPage {
                id: soundPage
                opacity: root.current === "sound" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                onBack: root.close()
            }

            DisplayPage {
                id: displayPage
                opacity: root.current === "display" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                onBack: root.close()
            }

            LauncherView {
                id: launcherPanel
                width: 480; height: 380
                opacity: root.current === "launcher" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                onCloseRequested: UiState.launcherOpen = false
            }

            PowerView {
                id: powerPanel
                width: 470; height: 190
                opacity: root.current === "power" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }

            ThemeView {
                id: themePanel
                width: 700; height: 184
                opacity: root.current === "theme" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }

            CaptureView {
                id: capturePanel
                width: 470; height: 196
                opacity: root.current === "capture" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }

            RecordView {
                id: recordPanel
                width: 360
                height: implicitHeight
                opacity: root.current === "record" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }

            NameView {
                id: namingPanel
                width: 380
                height: implicitHeight
                opacity: root.current === "naming" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }

            MonitorsPage {
                id: monitorsPage
                opacity: root.current === "monitors" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                onOpenPage: name => root.open(name, root.anchorY)
            }
        }
    }
}
