import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.theme
import qs.services

Scope {
    id: root

    // <Pictures>/Wallpapers (Pictures / Immagini / ... depending on the system language)
    property string dir: ""

    Process {
        running: true
        command: ["sh", Quickshell.shellPath("scripts/wallpaper-dir.sh")]
        stdout: StdioCollector { onStreamFinished: { const d = text.trim(); if (d !== "") root.dir = d } }
    }

    property int index: 0
    property string currentPath: ""
    property var palettes: ({})          // percorso -> [5 colori]

    readonly property int count: folder.count
    readonly property url currentUrl: folder.count > 0 ? folder.get(index, "fileUrl") : ""
    readonly property string currentName: folder.count > 0 ? folder.get(index, "fileName") : ""

    // ---------- Images in the folder ----------
    FolderListModel {
        id: folder
        folder: root.dir !== "" ? "file://" + root.dir : ""
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        caseSensitive: false
        showDirs: false
        sortField: FolderListModel.Name
        onCountChanged: if (root.index >= count) root.index = Math.max(0, count - 1)
    }

    // Current wallpaper (written by apply-wallpaper.sh)
    FileView {
        id: cur
        path: Quickshell.env("HOME") + "/.cache/quickshell-wallpaper-current"
        blockLoading: true
    }

    // ---------- Palette of each wallpaper (row by row, as they arrive) ----------
    Process {
        id: palProc
        command: ["sh", Quickshell.shellPath("scripts/palettes.sh"), root.dir]

        stdout: SplitParser {
            onRead: line => {
                const t = line.indexOf("\t")
                if (t < 0) return
                try {
                    const path = line.slice(0, t)
                    const d = JSON.parse(line.slice(t + 1))
                    const c = d.colors
                    const p = Object.assign({}, root.palettes)
                    p[path] = [d.special.background, c.color1, c.color2, c.color4, c.color5]
                    root.palettes = p
                } catch (e) {}
            }
        }
    }

    // ---------- Logica ----------
    function prepare() {
        cur.reload()
        const c = (cur.text() || "").trim()
        currentPath = c

        let idx = 0
        for (let i = 0; i < folder.count; i++) {
            if (folder.get(i, "filePath") === c) { idx = i; break }
        }
        index = idx

        if (!palProc.running) palProc.running = true
    }

    function open() {
        UiState.wallpaperScreen = Compositor.focusedMonitor
        UiState.launcherOpen = false
        UiState.powerOpen = false
        prepare()
        UiState.wallpaperOpen = true
    }

    function move(d) {
        if (folder.count === 0) return
        index = (index + d + folder.count) % folder.count
    }

    function applyIndex(i) {
        if (i < 0 || i >= folder.count) return
        const path = folder.get(i, "filePath")
        currentPath = path
        Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/apply-wallpaper.sh"), path])
        UiState.wallpaperOpen = false
    }

    // ---------- Comando IPC: qs ipc call wallpaper toggle ----------
    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            if (UiState.wallpaperOpen) UiState.wallpaperOpen = false
            else root.open()
        }

        function open(): void { root.open() }

        function close(): void { UiState.wallpaperOpen = false }
    }

    // ---------- Full-screen overlay ----------
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            readonly property bool here: UiState.wallpaperOpen
                && (UiState.wallpaperScreen === "" || UiState.wallpaperScreen === modelData.name)

            visible: here || content.opacity > 0
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "shell-wallpaper"
            WlrLayershell.keyboardFocus: win.here ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onHereChanged: {
                if (here) {
                    previewCard.show(root.currentUrl)
                    content.forceActiveFocus()
                }
            }

            Item {
                id: content

                anchors.fill: parent
                opacity: win.here ? 1 : 0
                focus: true
                Behavior on opacity { NumberAnimation { duration: 220 } }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Right) {
                        root.move(1); event.accepted = true
                    } else if (event.key === Qt.Key_Left) {
                        root.move(-1); event.accepted = true
                    } else if (event.key === Qt.Key_Home) {
                        root.index = 0; event.accepted = true
                    } else if (event.key === Qt.Key_End) {
                        root.index = Math.max(0, root.count - 1); event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.applyIndex(root.index); event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        UiState.wallpaperOpen = false; event.accepted = true
                    }
                }

                // ----- Darkened background (the blur is added by the Hyprland rule) -----
                Rectangle {
                    anchors.fill: parent
                    color: Theme.scrim
                }

                Timer { id: wheelCool; interval: 90 }

                MouseArea {
                    anchors.fill: parent
                    onClicked: UiState.wallpaperOpen = false
                    onWheel: wheel => {
                        if (wheelCool.running) return
                        root.move(wheel.angleDelta.y > 0 ? -1 : 1)
                        wheelCool.start()
                    }
                }

                // ----- Large preview (same proportions as the screen) -----
                ClippingRectangle {
                    id: previewCard

                    readonly property real pw: content.width * 0.60

                    x: (content.width - width) / 2
                    y: content.height * 0.06
                    width: pw
                    height: pw * content.height / content.width
                    radius: 28
                    color: Theme.island
                    border.width: 1
                    border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.18)
                    scale: win.here ? 1 : 0.94
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                    property url shown: ""

                    // Crossfade between one wallpaper and the next
                    function show(url) {
                        if (url === shown) return
                        shown = url
                        back.source = front.source
                        front.opacity = 0
                        front.source = url
                    }

                    Image {
                        id: back
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(1600, 1000)
                    }

                    Image {
                        id: front
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(1600, 1000)
                        opacity: 0
                        onStatusChanged: if (status === Image.Ready) fadeIn.restart()
                    }

                    NumberAnimation {
                        id: fadeIn
                        target: front
                        property: "opacity"
                        from: 0; to: 1
                        duration: 200
                    }

                    Connections {
                        target: root
                        function onCurrentUrlChanged() { previewCard.show(root.currentUrl) }
                    }

                    // No images in the folder
                    Text {
                        anchors.centerIn: parent
                        visible: root.count === 0
                        text: "No wallpapers in " + root.dir
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }
                }

                // ----- Name and shortcuts under the preview -----
                Text {
                    x: previewCard.x + 6
                    y: previewCard.y + previewCard.height + 14
                    text: root.currentName
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    anchors.right: previewCard.right
                    anchors.rightMargin: 6
                    y: previewCard.y + previewCard.height + 16
                    text: (root.count > 0 ? (root.index + 1) + "/" + root.count + "  ·  " : "")
                          + "← → browse  ·  Enter apply  ·  Esc close"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                // ----- Carosello: quadrato + badge colori attaccato -----
                ListView {
                    id: strip

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: content.height * 0.06
                    width: content.width
                    height: 130
                    orientation: ListView.Horizontal
                    spacing: 18
                    interactive: false
                    model: folder
                    currentIndex: root.index

                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: width / 2 - 67
                    preferredHighlightEnd: width / 2 + 67
                    highlightMoveDuration: 240

                    delegate: Item {
                        id: card

                        required property int index
                        required property string filePath
                        required property url fileUrl

                        readonly property bool sel: ListView.isCurrentItem
                        readonly property bool isCurrent: filePath === root.currentPath
                        readonly property var pal: root.palettes[filePath]

                        width: 134
                        height: 130

                        Item {
                            anchors.centerIn: parent
                            width: 134
                            height: 100
                            scale: card.sel ? 1.12 : 1
                            opacity: card.sel ? 1 : 0.7
                            Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            ClippingRectangle {
                                anchors.fill: parent
                                radius: 18
                                color: Theme.island
                                border.width: card.sel ? 2 : 1
                                border.color: card.sel ? Theme.accent : Theme.border

                                // Square: thumbnail
                                Image {
                                    x: 0; y: 0
                                    width: 100; height: 100
                                    source: card.fileUrl
                                    sourceSize: Qt.size(240, 240)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                // Rettangolo adiacente: palette
                                Rectangle {
                                    x: 100; y: 0
                                    width: 34; height: 100
                                    color: Theme.island

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 3

                                        Repeater {
                                            model: 5

                                            Rectangle {
                                                width: 22
                                                height: 14
                                                radius: 5
                                                color: card.pal ? card.pal[modelData] : Qt.rgba(1, 1, 1, 0.10)
                                                border.width: 1
                                                border.color: Qt.rgba(1, 1, 1, 0.15)
                                                Behavior on color { ColorAnimation { duration: 250 } }
                                            }
                                        }
                                    }
                                }
                            }

                            // Dot on the currently applied wallpaper
                            Rectangle {
                                x: 100 - 18
                                y: 8
                                width: 10; height: 10
                                radius: 5
                                color: Theme.accent
                                border.width: 2
                                border.color: Theme.island
                                visible: card.isCurrent
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.applyIndex(card.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
