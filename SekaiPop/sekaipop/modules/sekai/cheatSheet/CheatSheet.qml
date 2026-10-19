import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.services
import "CheatBinds.js" as CB
import qs.modules.common
import qs.modules.common.widgets

// The keybind cheatsheet: every Hyprland bind, pinned to a cork board as
// paper notes (CheatNote.qml), grouped by what they do: Shell, Utilities,
// Windows, Workspaces, Session, Screen, Media and Apps (like Illogical Impulse).
//
// It reads `hyprctl -j binds` each time it opens, so a config reload is
// picked up without restarting the shell. CheatBinds.js does all the
// thinking (labelling, grouping, folding SUPER+1..5 into one row, sizing);
// this file is the window, the search + modifier filters, and the scroll.
//
// Files:
//   CheatSheet.qml   this one - window, header (search + chips), board, scroll
//   CheatNote.qml    one paper note (keycaps + labels)
//   CheatBinds.js    hyprctl JSON -> notes, masonry layout, search matching
//   CorkBoard.qml    the wood frame + cork behind the notes (shared with Overview)
//
// Ways to open it:
//   qs -c sekaipop ipc call cheatsheet toggle       (also show / hide)
//   e.g. in hyprland.lua / hyprland.conf:
//     bind = SUPER, F1, exec, qs -c sekaipop ipc call cheatsheet toggle
// Ways to close it: Escape (clears the modifier chips first), click outside
// the board, or the keybind again.
//
// Using it:
//   - just start typing: every word must appear in the bind's keys, its
//     label or its category ("super term", "vol", "workspace 3")
//   - the Super / Ctrl / Alt / Shift chips keep only binds that use
//     ALL the chips that are on
//   - like Illogical Impulse it lists only what you should know: hardware
//     keys, alternate keys ("(more)" binds) and repeats are left out. The last
//     chip ("+12 more") brings them back; tap it again for the short list
//   - notes with no match fade back; rows that don't match dim
//   - mouse wheel, Up / Down, PgUp / PgDn, Home / End scroll the board;
//     so does dragging it with the left mouse button (it keeps gliding when
//     you let go of a quick flick), or dragging the scrollbar on the right
//     (Enter or Down from the search box hands the keyboard to the board)
//
// It opens on whichever monitor was focused when it fired, drawn inside a
// ScaleHost like the Overview so it follows the per-monitor UI scale.
Scope {
    id: root

    property bool open: false
    property bool closing: false
    // The phone (QuickPanel.qml), when the shell hands it over. While it is up
    // the board steps down a layer so the phone is drawn over it, not under it.
    property var quickPanel: null
    readonly property bool shown: root.open || root.closing
    property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    // ===== data =====
    property var notes: []          // CB.build() output
    property bool loaded: false     // hyprctl answered at least once
    property bool shellOnly: false  // true = only binds that drive this shell
    property bool showAll: false    // false = only the essentials, true = every bind
    property int hiddenCount: 0     // binds the essentials view left out
    // The modifier chips, plus one last chip (mask 0) for showAll.
    readonly property var chipModel: CB.MODS.concat([["", 0]])
    property int modFilter: 0       // OR of the active chips' hyprland mask bits
    readonly property string query: search.text

    // ===== layout =====
    readonly property real gap: 30              // between notes
    readonly property real boardPadX: 44        // board edge -> notes
    readonly property real frameInset: 18       // board edge -> scroll area (inside the wood)
    readonly property real notesTop: 30         // room above the first row for pins / tape
    readonly property real notesBottom: 26
    readonly property real headerH: 40
    readonly property real headerGap: 18

    readonly property real stageW: overlayRoot.width
    readonly property real stageH: overlayRoot.height

    readonly property int cols: Math.max(1, Math.min(5, root.notes.length,
        Math.floor((root.stageW * 0.94 - root.boardPadX * 2 + root.gap) / (CB.NOTE_W + root.gap))))
    readonly property var layout: CB.place(root.notes, root.cols, root.gap)
    readonly property real gridW: root.cols * CB.NOTE_W + (root.cols - 1) * root.gap
    readonly property real boardW: root.gridW + root.boardPadX * 2
    readonly property real contentH: root.layout.height + root.notesTop + root.notesBottom
    readonly property real topY: Math.round(root.stageH * 0.05)
    readonly property real boardMaxH: Math.max(240, root.stageH - root.topY - root.headerH - root.headerGap - 36)
    readonly property real boardH: Math.min(root.contentH + root.frameInset * 2, root.boardMaxH)

    // ===== counts for the little tag in the header =====
    readonly property int totalRows: {
        let n = 0
        for (const note of root.notes)
            n += note.rows.length
        return n
    }
    readonly property int hitRows: {
        let n = 0
        for (const note of root.notes)
            for (const row of note.rows)
                if (CB.matches(row, root.query, root.modFilter))
                    n++
        return n
    }

    // ===== open / close =====
    function focusedScreen() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        for (const s of Quickshell.screens) {
            if (s.name === name)
                return s
        }
        return Quickshell.screens[0]
    }

    function rebuild() {
        root.notes = CB.build(bindsOut.text, root.shellOnly, root.showAll)
        root.hiddenCount = CB.lastHidden()
    }

    onShowAllChanged: {
        if (root.loaded)
            root.rebuild()
    }

    function openOn(screen) {
        if (screen)
            targetScreen = screen
        search.clear()
        modFilter = 0
        root.scrollTo(0)
        open = true
    }

    function close() {
        open = false
    }

    function toggleOn(screen) {
        if (open && (!screen || screen === targetScreen))
            close()
        else
            openOn(screen)
    }

    // Scroll the board by `dy` design pixels (positive = further down), gliding
    // there in `ms` (default 140). A notch that arrives while it is still gliding
    // adds to where it is heading, not to where it is right now, so a fast spin
    // of the wheel travels the whole distance instead of losing most of it.
    function scrollBy(dy, ms) {
        const max = Math.max(0, flick.contentHeight - flick.height)
        const from = scrollAnim.running ? scrollAnim.to : flick.contentY
        const to = Math.max(0, Math.min(max, from + dy))
        scrollAnim.stop()
        scrollAnim.duration = ms || 140
        scrollAnim.from = flick.contentY
        scrollAnim.to = to
        scrollAnim.start()
    }

    // Jump straight to `y` (dragging the board or the scrollbar follows the
    // pointer one to one, no gliding).
    function scrollTo(y) {
        const max = Math.max(0, flick.contentHeight - flick.height)
        scrollAnim.stop()
        flick.contentY = Math.max(0, Math.min(max, y))
    }

    function reload() {
        if (!getBinds.running)
            getBinds.running = true
    }

    // (`ipc call cheatsheet toggle | show | hide` is answered in shell.qml, by the entry
    // point that builds this screen on demand: a handler in here would vanish with it.)

    // Binds only change on a config reload, so one read per open is enough.
    Process {
        id: getBinds
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector {
            id: bindsOut
            onStreamFinished: {
                root.rebuild()
                root.loaded = true
            }
        }
    }

    // Same enter / exit shape as the Overview: a short rise-and-fade in,
    // and a quicker fade + drift on the way out.
    property real openT: 0
    property real closeT: 0

    NumberAnimation {
        id: enterAnim
        target: root
        property: "openT"
        to: 1
        duration: 240
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: exitAnim
        target: root
        property: "closeT"
        from: 0
        to: 1
        duration: 150
        easing.type: Easing.OutQuad
        onStopped: {
            root.closing = false
            root.closeT = 0
            root.openT = 0
        }
    }

    onOpenChanged: {
        if (open) {
            exitAnim.stop()
            root.closing = false
            enterAnim.restart()
            root.reload()
        } else {
            enterAnim.stop()
            root.closing = true
            exitAnim.restart()
        }
    }

    // ===== The window =====
    PanelWindow {
        id: win

        screen: root.targetScreen
        visible: root.open || root.closing
        color: "transparent"

        // Full-screen overlay so clicks outside the board reach us (and
        // close it) instead of falling through - same reasoning as
        // Overview.qml's window.
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.keyboardFocus: win.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        // Overlay normally; one layer down while the phone is on screen, its
        // slide-out included (the phone is on Overlay for as long as the board is
        // shown, see QuickPanel).
        WlrLayershell.layer: (root.quickPanel && (root.quickPanel.up || root.quickPanel.onScreen)) ? WlrLayer.Top : WlrLayer.Overlay
        WlrLayershell.namespace: "sekaipop-cheatsheet"

        onVisibleChanged: {
            if (visible)
                Qt.callLater(() => search.begin(""))
        }

        ScaleHost {
            anchors.fill: parent
            factor: ShellScale.forScreen(root.targetScreen)

            Item {
                id: overlayRoot
                anchors.fill: parent
                focus: true

                // Escape from anywhere (the search box hands it up once it
                // is empty): clear the modifier chips first, then close.
                Keys.onEscapePressed: {
                    if (root.modFilter !== 0)
                        root.modFilter = 0
                    else
                        root.close()
                }

                // Wheel anywhere over the overlay scrolls the board. Lives on
                // the root (not inside the board) so no child item or the
                // Flickable can swallow the event before it gets here.
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        root.scrollBy(-Theme.wheelPx(event))
                    }
                }

                // Click outside the board closes it. Bottom of the stack so
                // everything with its own MouseArea takes the click instead.
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }

                // All-but-invisible layer, same as the Overview: the surface
                // is still drawn and catches clicks, the desktop stays put.
                Rectangle {
                    anchors.fill: parent
                    color: Theme.colDeep
                    opacity: 0.001
                }

                Item {
                    id: content
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.topY
                    width: root.boardW
                    height: root.headerH + root.headerGap + root.boardH

                    opacity: Math.min(1, root.openT) * (1 - root.closeT)
                    transform: Translate { y: (1 - Math.min(1, root.openT)) * 20 - 12 * root.closeT }

                    // ===== header =====
                    MouseArea {
                        anchors.fill: header
                    }

                    Row {
                        id: header
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: root.headerH
                        spacing: 16

                        SearchPill {
                            id: search
                            anchors.verticalCenter: parent.verticalCenter
                            width: 300
                            placeholder: "Search keybinds"
                            onLeave: flick.forceActiveFocus()
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Repeater {
                                model: root.chipModel
                                delegate: Item {
                                    id: chip
                                    required property var modelData

                                    // the last chip: "+12 more" <-> "Essentials only"
                                    readonly property bool isAll: chip.modelData[1] === 0
                                    readonly property bool on: chip.isAll ? root.showAll
                                        : (root.modFilter & chip.modelData[1]) !== 0
                                    visible: !chip.isAll || root.showAll || root.hiddenCount > 0
                                    readonly property bool hot: chipArea.containsMouse
                                    readonly property real press: chipArea.pressed ? 2 : 0

                                    width: Math.max(58, chipText.implicitWidth + 30)
                                    height: 32

                                    // hard shadow
                                    Rectangle {
                                        x: Theme.shadowOffset - 1 - chip.press
                                        y: Theme.shadowOffset - 1 - chip.press
                                        width: chip.width
                                        height: chip.height
                                        radius: height / 2
                                        color: Theme.lineShadow
                                        antialiasing: true
                                    }

                                    Rectangle {
                                        x: chip.press
                                        y: chip.press
                                        width: chip.width
                                        height: chip.height
                                        radius: height / 2
                                        color: chip.hot && !chip.on ? Theme.colHoverTint : "#ffffff"
                                        border.width: Theme.borderWidth
                                        border.color: Theme.line
                                        antialiasing: true

                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        // "on" fill - same cyan-to-mint as the sort chip
                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: 3
                                            radius: height / 2
                                            visible: chip.on
                                            antialiasing: true
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0.0; color: Theme.accentCyan }
                                                GradientStop { position: 1.0; color: Theme.accentMint }
                                            }
                                        }

                                        Text {
                                            id: chipText
                                            anchors.centerIn: parent
                                            text: chip.isAll
                                                ? (root.showAll ? "Essentials only" : "+" + root.hiddenCount + " more")
                                                : chip.modelData[0]
                                            color: Theme.colBorder
                                            font.family: Theme.fontFamily
                                            font.styleName: Theme.fontStyleBold
                                            font.weight: Font.ExtraBold
                                            font.pixelSize: 14
                                        }
                                    }

                                    MouseArea {
                                        id: chipArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (chip.isAll)
                                                root.showAll = !root.showAll
                                            else
                                                root.modFilter = root.modFilter ^ chip.modelData[1]
                                        }
                                    }
                                }
                            }
                        }

                        // "12 of 48 binds" on a little name tag
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: countText.implicitWidth + 26
                            height: 28
                            radius: 4
                            rotation: -2
                            color: ScrapbookTheme.labelPaper
                            border.width: 1.5
                            border.color: "#664a4536"

                            Text {
                                id: countText
                                anchors.centerIn: parent
                                text: root.hitRows + " of " + root.totalRows + " binds"
                                color: ScrapbookTheme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }

                    // ===== the board =====
                    CorkBoard {
                        id: board
                        x: 0
                        y: root.headerH + root.headerGap
                        width: root.boardW
                        height: root.boardH

                        // Eats clicks on the board so a click between two
                        // notes doesn't close it, and pans it: hold the left
                        // button anywhere on the board and drag. (The notes
                        // and the Flickable above it pass presses through.)
                        MouseArea {
                            id: pan
                            anchors.fill: parent
                            cursorShape: pan.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                            property real pressY: 0
                            property real pressScroll: 0
                            property real lastY: 0
                            property real lastT: 0
                            property real vel: 0        // content px per ms, positive = down

                            onPressed: mouse => {
                                scrollAnim.stop()
                                pan.pressY = mouse.y
                                pan.pressScroll = flick.contentY
                                pan.lastY = mouse.y
                                pan.lastT = Date.now()
                                pan.vel = 0
                            }
                            onPositionChanged: mouse => {
                                if (!pan.pressed)
                                    return
                                const now = Date.now()
                                root.scrollTo(pan.pressScroll - (mouse.y - pan.pressY))
                                const dt = Math.max(1, now - pan.lastT)
                                pan.vel = pan.vel * 0.6 + ((pan.lastY - mouse.y) / dt) * 0.4
                                pan.lastY = mouse.y
                                pan.lastT = now
                            }
                            onReleased: {
                                // a quick flick keeps gliding for a moment
                                if (Date.now() - pan.lastT < 80 && Math.abs(pan.vel) > 0.25)
                                    root.scrollBy(pan.vel * 280, 520)
                                pan.vel = 0
                            }
                        }

                        Flickable {
                            id: flick
                            x: root.frameInset
                            y: root.frameInset
                            width: board.width - root.frameInset * 2
                            height: board.height - root.frameInset * 2
                            clip: true
                            interactive: false          // wheel / keys / the pan area under it scroll; notes stay put under the cursor
                            contentWidth: width
                            contentHeight: root.contentH
                            boundsBehavior: Flickable.StopAtBounds

                            NumberAnimation {
                                id: scrollAnim
                                target: flick
                                property: "contentY"
                                duration: 140
                                easing.type: Easing.OutCubic
                            }

                            // One key handler for the board:
                            //   - "just start typing" jumps into the search box
                            //     (same convention as the wallpaper gallery)
                            //   - Up / Down / PgUp / PgDn / Home / End scroll
                            Keys.onPressed: event => {
                                if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                                    return
                                if (event.key === Qt.Key_Up) {
                                    root.scrollBy(-90)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Down) {
                                    root.scrollBy(90)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_PageUp) {
                                    root.scrollBy(-flick.height * 0.85)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_PageDown) {
                                    root.scrollBy(flick.height * 0.85)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Home) {
                                    root.scrollBy(-flick.contentHeight)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_End) {
                                    root.scrollBy(flick.contentHeight)
                                    event.accepted = true
                                } else if (event.text.length === 1 && event.text >= " " && event.text !== "\u007f") {
                                    search.begin(event.text)
                                    event.accepted = true
                                }
                            }

                            Item {
                                id: notesLayer
                                x: Math.round((flick.width - root.gridW) / 2)
                                y: root.notesTop
                                width: root.gridW
                                height: root.layout.height

                                Repeater {
                                    model: root.layout.items
                                    delegate: CheatNote {
                                        required property var modelData
                                        required property int index

                                        x: modelData.x
                                        y: modelData.y
                                        note: modelData.note
                                        slot: index
                                        query: root.query
                                        modFilter: root.modFilter
                                    }
                                }
                            }
                        }

                        // little scrollbar, only when there's more than fits
                        Rectangle {
                            id: bar
                            readonly property real maxScroll: Math.max(0, flick.contentHeight - flick.height)
                            readonly property real trackH: flick.height - 12
                            readonly property real thumbH: Math.max(36, trackH * flick.height / Math.max(1, flick.contentHeight))

                            visible: maxScroll > 1
                            x: board.width - root.frameInset - 14
                            y: root.frameInset + 6 + (maxScroll > 0 ? (flick.contentY / maxScroll) * (trackH - thumbH) : 0)
                            width: 6
                            height: thumbH
                            radius: 3
                            color: ScrapbookTheme.frameShade
                            opacity: barArea.pressed ? 0.9 : 0.55
                        }

                        // a wider strip over the scrollbar (inside the board's side
                        // margin, clear of the notes): press to jump, drag to scroll
                        MouseArea {
                            id: barArea
                            visible: bar.visible
                            x: board.width - root.frameInset - 24
                            y: root.frameInset
                            width: 24
                            height: flick.height
                            preventStealing: true
                            cursorShape: Qt.PointingHandCursor

                            function seek(my) {
                                const room = Math.max(1, bar.trackH - bar.thumbH)
                                root.scrollTo(((my - 6 - bar.thumbH / 2) / room) * bar.maxScroll)
                            }
                            onPressed: mouse => barArea.seek(mouse.y)
                            onPositionChanged: mouse => {
                                if (barArea.pressed)
                                    barArea.seek(mouse.y)
                            }
                        }

                        // nothing to show: still loading, no binds, or no match
                        Rectangle {
                            visible: root.hitRows === 0
                            anchors.centerIn: parent
                            width: emptyText.implicitWidth + 48
                            height: emptyText.implicitHeight + 32
                            radius: 6
                            rotation: -1.5
                            color: ScrapbookTheme.tag
                            border.width: 1.5
                            border.color: "#664a4536"

                            Text {
                                id: emptyText
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: !root.loaded ? "Reading your keybinds..."
                                    : root.totalRows === 0 ? (root.shellOnly
                                        ? "No shell keybinds found.\nBind something to `qs -c sekaipop ipc call ...`"
                                        : root.hiddenCount > 0
                                            ? "Only minor keybinds found.\nTap \"+" + root.hiddenCount + " more\" above."
                                            : "No keybinds found.\nAdd some to your Hyprland config.")
                                    : "Nothing matches that."
                                color: ScrapbookTheme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }
    }
}
