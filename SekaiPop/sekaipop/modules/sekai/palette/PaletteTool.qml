import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/PaletteMath.js" as PM

// The Palette tool: look at colours, keep the ones you like, and put them on the shell
// only when you say so.
//
//   - Wallpaper / Music: five colours read from the wallpaper on screen, or from the
//     cover of the playing track (PaletteExtractor.qml)
//   - Random: five colours from a colour-wheel harmony (analogous, complementary,
//     split, triadic, tetradic, mono); Space or Shuffle makes a new set, and a locked
//     swatch (padlock, or right-click) keeps its colour through every shuffle
//   - click a swatch to copy its HEX (wl-copy)
//   - the heart saves the palette to the favourites; click a saved one to bring it back
//   - the live preview shows the palette on a mock-up of the shell, in the current
//     light / dark / darker mode
//
// LOOKING NEVER CHANGES THE THEME. The strip, the preview, the shuffle, the favourites
// and the copy buttons only touch PaletteService's own state. The shell changes colour
// only when you press "Apply to theme" (PaletteService.apply(): the palette becomes the
// "Custom palette" theme, in Settings -> Quick -> Colours and the Edit Desktop theme
// row). "Undo" puts the previous theme back.
//
// Ways to open it:
//   qs -c sekaipop ipc call palette toggle       (also show / hide)
//   qs -c sekaipop ipc call palette shuffle      (a new random strip; the theme is untouched)
//   Settings -> Quick -> Colours -> "Palette tool"
//   e.g. in hyprland.lua:  bind = SUPER, P, exec, qs -c sekaipop ipc call palette toggle
// Ways to close it: Escape, the cross, click outside the card, or the keybind again.
//
// Like the cheatsheet, it opens on the focused monitor, drawn inside a ScaleHost so it
// follows the per-monitor UI scale.
Scope {
    id: root

    property bool open: false
    property bool closing: false
    property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    // the palette as the shell would wear it (for the "how it maps" list)
    readonly property var shell: PM.toShell(PaletteService.colors)

    // the little "copied" tick lives on the swatch; this counts copies for nothing but
    // to let "Copy all" say it did something
    property bool copiedAll: false

    function focusedScreen() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        for (const s of Quickshell.screens) {
            if (s.name === name)
                return s
        }
        return Quickshell.screens[0]
    }

    function openOn(screen) {
        if (screen)
            targetScreen = screen
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

    // (`ipc call palette toggle | show | hide | shuffle` and PaletteService.requestOpen()
    // are answered in shell.qml, by the entry point that builds this tool on demand.)

    // Tells the desktop widget (PaletteWidget.qml) the tool is open, so only one of them
    // reads the picture for the same colours.
    Binding {
        target: PaletteService
        property: "toolOpen"
        value: root.open
    }

    // Where the music cover comes from (the bar, the dock and the lockscreen each have
    // their own MediaSource too).
    MediaSource {
        id: media
    }

    PaletteExtractor {
        id: extractor
        kind: PaletteService.source
        active: root.open
        media: media
    }

    // Same enter / exit shape as the cheatsheet and the Overview.
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
        } else {
            enterAnim.stop()
            root.closing = true
            exitAnim.restart()
        }
    }

    Timer {
        id: copiedAllTimer
        interval: 1000
        onTriggered: root.copiedAll = false
    }

    // ===== The window =====
    PanelWindow {
        id: win

        screen: root.targetScreen
        visible: root.open || root.closing
        color: "transparent"

        // Full-screen overlay so a click outside the card reaches us and closes it.
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.keyboardFocus: win.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sekaipop-palette"

        ScaleHost {
            anchors.fill: parent
            factor: ShellScale.forScreen(root.targetScreen)

            Item {
                id: overlayRoot
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: root.close()
                Keys.onSpacePressed: PaletteService.shuffle()

                // Click outside the card closes it. Bottom of the stack so everything
                // with its own MouseArea takes the click instead.
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }

                // All-but-invisible layer, same as the cheatsheet: the surface is still
                // drawn and catches clicks, the desktop stays put.
                Rectangle {
                    anchors.fill: parent
                    color: Theme.colDeep
                    opacity: 0.001
                }

                Item {
                    id: content

                    readonly property real pad: 24

                    width: 720
                    height: column.implicitHeight + 2 * content.pad
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.max(16, Math.round((overlayRoot.height - content.height) / 2))

                    opacity: Math.min(1, root.openT) * (1 - root.closeT)
                    transform: Translate { y: (1 - Math.min(1, root.openT)) * 20 - 12 * root.closeT }

                    // the card: hard shadow straight down, outline, fill
                    Rectangle {
                        y: Theme.shadowOffset + 2
                        width: parent.width
                        height: parent.height
                        radius: 22
                        color: Theme.lineShadow
                        antialiasing: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 22
                        color: Theme.surface
                        border.width: Theme.borderWidth
                        border.color: Theme.line
                        antialiasing: true

                        // a click on the card is not a click outside it
                        MouseArea {
                            anchors.fill: parent
                        }
                    }

                    Column {
                        id: column
                        x: content.pad
                        y: content.pad
                        width: content.width - 2 * content.pad
                        spacing: 16

                        // ===== header =====
                        Item {
                            width: parent.width
                            height: 34

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                MaterialIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "palette"
                                    size: 28
                                    color: Theme.ink
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Palette"
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 24
                                    font.weight: Font.ExtraBold
                                    font.styleName: Theme.fontStyleBold
                                }
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                // says out loud whether the theme is being touched
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 28
                                    width: statusRow.implicitWidth + 20
                                    radius: 14
                                    antialiasing: true
                                    color: PaletteService.applied ? Theme.accentMint : Theme.surfaceHover
                                    border.width: 2
                                    border.color: Theme.line

                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    Row {
                                        id: statusRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        MaterialIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            name: PaletteService.applied ? "check_circle" : "visibility"
                                            size: 16
                                            color: PaletteService.applied ? Theme.colBorder : Theme.ink
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: PaletteService.applied ? "Applied to the theme" : "Preview only, theme unchanged"
                                            color: PaletteService.applied ? Theme.colBorder : Theme.ink
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.ExtraBold
                                            font.styleName: Theme.fontStyleBold
                                        }
                                    }
                                }

                                Rectangle {
                                    id: closeBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 30
                                    height: 30
                                    radius: 15
                                    antialiasing: true
                                    color: closeMouse.containsMouse ? Theme.surfaceTint : Theme.surfaceHover
                                    border.width: 2
                                    border.color: Theme.line

                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        name: "close"
                                        size: 18
                                        color: Theme.ink
                                    }

                                    MouseArea {
                                        id: closeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.close()
                                    }
                                }
                            }
                        }

                        // ===== where the colours come from =====
                        Item {
                            width: parent.width
                            height: 34

                            SegmentSwitch {
                                id: tabs
                                width: 330
                                height: 34
                                options: [
                                    { id: "wallpaper", label: "Wallpaper" },
                                    { id: "music", label: "Music" },
                                    { id: "random", label: "Random" }
                                ]
                                current: PaletteService.source
                                onPicked: id => {
                                    if (id === "random") {
                                        PaletteService.shuffle()
                                    } else if (id === PaletteService.source) {
                                        extractor.push()
                                    } else {
                                        PaletteService.setSource(id)
                                    }
                                }
                            }

                            Text {
                                anchors.left: tabs.right
                                anchors.leftMargin: 16
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                color: Theme.inkSub
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                text: {
                                    if (PaletteService.source === "random")
                                        return PaletteService.scheme !== "" ? ("Harmony: " + PaletteService.scheme + ", Space shuffles") : "Space shuffles"
                                    if (extractor.problem !== "")
                                        return extractor.problem
                                    return PaletteService.source === "music" ? "From the cover of the playing track" : "From the wallpaper on screen"
                                }
                            }
                        }

                        // ===== the swatches =====
                        Row {
                            id: swatches
                            width: parent.width
                            spacing: (width - 5 * 124) / 4

                            Repeater {
                                id: swatchRepeater
                                model: 5

                                delegate: PaletteSwatch {
                                    required property int index

                                    width: 124
                                    hex: PaletteService.colors[index] ?? "#000000"
                                    locked: PaletteService.locks[index] === true
                                    onCopyRequested: {
                                        if (PaletteService.copy(hex))
                                            flashCopied()
                                    }
                                    onLockToggled: PaletteService.toggleLock(index)
                                }
                            }
                        }

                        // ===== actions =====
                        Item {
                            width: parent.width
                            height: 37

                            Row {
                                spacing: 10

                                PaletteButton {
                                    icon: "casino"
                                    label: "Shuffle"
                                    onClicked: PaletteService.shuffle()
                                }

                                PaletteButton {
                                    icon: "favorite"
                                    label: PaletteService.isFavorite ? "Saved" : "Save"
                                    lit: PaletteService.isFavorite
                                    onClicked: PaletteService.toggleFavorite()
                                }

                                PaletteButton {
                                    icon: root.copiedAll ? "check" : "content_copy"
                                    label: root.copiedAll ? "Copied" : "Copy all"
                                    onClicked: {
                                        PaletteService.copyAll()
                                        root.copiedAll = true
                                        copiedAllTimer.restart()
                                    }
                                }
                            }

                            Row {
                                anchors.right: parent.right
                                spacing: 10

                                PaletteButton {
                                    visible: PaletteService.canUndo
                                    icon: "undo"
                                    label: "Undo"
                                    onClicked: PaletteService.undo()
                                }

                                // the ONE button that changes the theme
                                PaletteButton {
                                    primary: true
                                    enabled: !PaletteService.applied
                                    icon: PaletteService.applied ? "check" : "format_paint"
                                    label: PaletteService.applied ? "Applied" : "Apply to theme"
                                    onClicked: PaletteService.apply()
                                }
                            }
                        }

                        // ===== live preview + how it maps =====
                        Item {
                            width: parent.width
                            height: preview.height

                            PalettePreview {
                                id: preview
                                width: 440
                                height: 200
                                colors: PaletteService.colors
                            }

                            Column {
                                anchors.left: preview.right
                                anchors.leftMargin: 16
                                anchors.right: parent.right
                                anchors.top: parent.top
                                spacing: 9

                                Text {
                                    text: "WHAT THE SHELL WOULD WEAR"
                                    color: Theme.inkSub
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.ExtraBold
                                    font.letterSpacing: 0.8
                                }

                                Repeater {
                                    model: [
                                        { label: "Outline and text", key: "border" },
                                        { label: "Accent", key: "A" },
                                        { label: "Second accent", key: "B" },
                                        { label: "Dark tone", key: "deep" },
                                        { label: "Hover wash", key: "hoverTint" }
                                    ]

                                    delegate: Row {
                                        required property var modelData
                                        spacing: 8

                                        Rectangle {
                                            width: 22
                                            height: 22
                                            radius: 7
                                            antialiasing: true
                                            color: root.shell[modelData.key]
                                            border.width: 2
                                            border.color: Theme.line
                                            Behavior on color { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                text: modelData.label
                                                color: Theme.ink
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.ExtraBold
                                            }

                                            Text {
                                                text: String(root.shell[modelData.key]).toUpperCase()
                                                color: Theme.inkSub
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ===== favourites =====
                        Column {
                            width: parent.width
                            spacing: 8

                            Text {
                                text: "FAVOURITES" + (PaletteService.favorites.length > 0 ? " (" + PaletteService.favorites.length + ")" : "")
                                color: Theme.inkSub
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.ExtraBold
                                font.letterSpacing: 0.8
                            }

                            Text {
                                visible: PaletteService.favorites.length === 0
                                width: parent.width
                                text: "Press Save to keep a palette here. Clicking one brings it back onto the strip; your theme stays as it is until you Apply."
                                wrapMode: Text.WordWrap
                                color: Theme.inkSub
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }

                            Flickable {
                                id: favFlick
                                visible: PaletteService.favorites.length > 0
                                width: parent.width
                                height: 44
                                contentWidth: favRow.width
                                contentHeight: height
                                flickableDirection: Flickable.HorizontalFlick
                                boundsBehavior: Flickable.StopAtBounds
                                clip: contentWidth > width

                                // a plain wheel scrolls the row sideways
                                WheelHandler {
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                    onWheel: event => {
                                        const d = Theme.wheelPx(event, true)
                                        favFlick.contentX = Math.max(0, Math.min(Math.max(0, favFlick.contentWidth - favFlick.width), favFlick.contentX - d))
                                    }
                                }

                                Row {
                                    id: favRow
                                    y: 4
                                    spacing: 10

                                    Repeater {
                                        model: PaletteService.favorites

                                        delegate: PaletteFavorite {
                                            required property var modelData

                                            colors: modelData.colors
                                            current: PM.sameColors(modelData.colors, PaletteService.colors)
                                            onPicked: PaletteService.useFavorite(modelData.colors)
                                            onRemoved: PaletteService.removeFavorite(modelData.colors)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
