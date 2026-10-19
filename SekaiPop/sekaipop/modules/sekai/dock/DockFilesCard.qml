import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The Files key's folder stack (Dock.qml): the card that opens over the key and shows
// what is in a real folder (Downloads to begin with). A folder you click opens in
// place (the arrow in the header goes back), a file opens in its default application
// and the card closes; clicking the key again, clicking outside it or Esc closes it.
//
// A row of places sits under the header (Downloads, Documents, Pictures, Videos, Music and
// the Trash): one click jumps there. In the Trash a row can be put back (Restore) and the
// header has an Empty button (it asks twice, the first click only arms it).
//
// The tune key in the footer: Folders first (off by default, so folders and files are
// sorted together) and a modified filter (any time, today, 7 or 30 days, a year).
//
// Two views (grid / list), sorted by name, modified date or type, hidden files on or off, all
// kept in Settings (FilesStackService.qml). Right-click a row for Open / Show in file
// manager / Copy path / Copy file / Add to Shelf, drag a row into another window to
// hand it the file.
//
// === cost ===
// The listing is a FolderListModel (a thread of its own, watching the folder) that
// lives inside the Loader below. The Loader is only on while the card is on screen,
// plus 20 s after it closes (so opening it again a moment later has the list ready),
// then the model, its watcher and the views are gone: nothing runs in the background.
DockCard {
    id: root

    signal closeRequested()

    // ===== where it is =====
    property string rootPath: ""
    property string path: ""
    // The folders left behind on the way in, for the back arrow.
    property var trail: []
    readonly property bool atRoot: root.trail.length === 0

    function enter(p) {
        root.trail = root.trail.concat([root.path])
        root.path = p
    }

    function back() {
        if (root.trail.length === 0)
            return
        root.path = root.trail[root.trail.length - 1]
        root.trail = root.trail.slice(0, -1)
    }

    // One of the row's places: it becomes the new start, as if the card had opened there.
    function goPlace(key) {
        const p = FilesStackService.placePath(key)
        root.rootPath = p
        root.path = p
        root.trail = []
    }

    readonly property string activePlace: FilesStackService.placeKeyOf(root.path)
    readonly property bool inTrash: FilesStackService.inTrash(root.path)
    readonly property bool atTrashRoot: root.path === FilesStackService.trashPath

    onOpenChanged: {
        if (root.open) {
            const o = FilesStackService.takeOverride()
            root.rootPath = o !== "" ? o : FilesStackService.configuredRoot
            root.path = root.rootPath
            root.trail = []
            Qt.callLater(root.focusStack)
        }
    }

    function focusStack() {
        if (body.item)
            body.item.forceActiveFocus()
    }

    // ===== size =====
    readonly property string viewMode: FilesStackService.view
    readonly property real tileW: 100
    readonly property real tileH: 114
    readonly property real cellGap: 6
    readonly property real rowH: 46
    readonly property real headH: 42
    readonly property real footH: 42
    readonly property real sec: 10
    // The row of places sits under the header: 8 above, 32 high, 8 below; the listing starts after it.
    readonly property real placesH: 40
    readonly property real placesTop: root.headH + 8
    readonly property real bodyTop: root.placesTop + root.placesH + 8

    // Five tiles across while the screen has room for them.
    readonly property real availW: root.hostW - 2 * root.edge - 2 * (root.ringWidth + root.pad) - root.shadowDx
    readonly property int cols: Math.max(4, Math.min(5, Math.floor((root.availW + root.cellGap) / (root.tileW + root.cellGap))))

    // The room above the dock (beside it, for a standing dock) is the most the card may take.
    readonly property real availH: root.vertical ? root.hostH - 2 * root.edge
                                                 : root.py - root.gap - root.clearance - root.edge
    readonly property real chromeH: root.bodyTop + root.sec + root.footH
                                    + 2 * (root.ringWidth + root.pad) + root.shadowDy
    readonly property real maxBodyH: Math.max(140, Math.min(500, root.availH - root.chromeH))

    readonly property int n: body.item ? body.item.count : 0
    readonly property real bodyTarget: {
        if (root.n <= 0)
            return 132
        const grid = root.viewMode === "grid"
        const natural = grid ? Math.ceil(root.n / root.cols) * (root.tileH + root.cellGap)
                             : root.n * (root.rowH + 2)
        return Math.min(root.maxBodyH, Math.max(grid ? root.tileH + root.cellGap : 96, natural))
    }
    property real bodyH: root.bodyTarget
    Behavior on bodyH {
        enabled: root.open
        NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
    }

    contentWidth: root.cols * (root.tileW + root.cellGap) - root.cellGap
    contentHeight: root.bodyTop + root.bodyH + root.sec + root.footH

    // ===== the listing only exists while it is wanted =====
    Timer {
        id: keep
        interval: 20000
    }

    onVisibleChanged: {
        if (!root.visible)
            keep.restart()
    }

    Loader {
        id: body
        x: root.pad
        y: root.pad
        width: root.contentWidth
        height: root.contentHeight
        active: root.visible || keep.running
        sourceComponent: stackComp
        onLoaded: {
            if (root.open)
                item.forceActiveFocus()
        }
    }

    Component {
        id: stackComp

        FocusScope {
            id: stack

            // What the views show (after the "modified" filter) and what the folder holds.
            readonly property int count: root.viewMode === "grid" ? shownGrid.count : shownList.count
            readonly property int rawCount: files.count
            readonly property bool filtering: FilesStackService.modified !== "any"
            property int cutoffTick: 0
            readonly property real cutoff: {
                stack.cutoffTick
                return FilesStackService.cutoffFor(FilesStackService.modified, stack.cutoffTick)
            }
            readonly property bool ready: files.status === FolderListModel.Ready

            // "" until asked: missing | notdir | denied | ok. Only asked when the list
            // is empty (an empty folder, one that is gone, one that can't be read all
            // look the same to the model).
            property string health: ""
            property bool probeAgain: false
            property bool hold: false

            readonly property string shownState: {
                if (stack.count > 0)
                    return "items"
                if (stack.filtering && stack.ready && stack.rawCount > 0)
                    return "filtered"
                if (stack.health === "missing" || stack.health === "notdir" || stack.health === "denied")
                    return stack.health
                return stack.ready ? "empty" : "loading"
            }

            property string hoverKey: ""
            property string hoverInfo: ""

            // The Trash with nothing in it (it may not even exist yet) is not an error.
            readonly property bool trashGone: root.inTrash && (stack.shownState === "missing" || stack.shownState === "empty")

            // Empty Trash is asked for in a bar over the footer (Cancel / Empty Trash): nothing
            // is deleted before the second press. Every way in (the header's Empty, the folder's
            // menu, the Trash key's menu) comes here; from elsewhere it opens the Trash first.
            property bool confirmEmpty: false

            function askEmptyTrash() {
                if (!root.atTrashRoot)
                    root.goPlace("TRASH")
                stack.confirmEmpty = true
            }

            function doEmptyTrash() {
                stack.confirmEmpty = false
                FilesStackService.emptyTrash()
            }

            // ===== the listing =====
            FolderListModel {
                id: files
                folder: stack.hold || root.path === "" ? "" : FilesStackService.fileUrl(root.path)
                showDirs: true
                showFiles: true
                showDirsFirst: FilesStackService.foldersFirst
                showDotAndDotDot: false
                showHidden: FilesStackService.showHidden
                sortCaseSensitive: false
                sortField: FilesStackService.sortBy === "date" ? FolderListModel.Time
                           : (FilesStackService.sortBy === "type" ? FolderListModel.Type : FolderListModel.Name)
                // Dates start with the newest; the reverse switch flips whichever order it is.
                sortReversed: (FilesStackService.sortBy === "date") !== FilesStackService.reverse
                onStatusChanged: stack.maybeProbe()
                onCountChanged: stack.maybeProbe()
            }

            // A fresh read of the folder (the model already follows changes by itself).
            function reload() {
                stack.hold = true
                Qt.callLater(() => stack.hold = false)
            }

            function maybeProbe() {
                if (root.path !== "" && stack.count === 0 && stack.ready)
                    stack.probe()
                else if (stack.count > 0)
                    stack.health = ""
            }

            function probe() {
                if (check.running) {
                    stack.probeAgain = true
                    return
                }
                check.exec(["sh", "-c",
                    "if [ ! -e \"$1\" ]; then echo missing; elif [ ! -d \"$1\" ]; then echo notdir; "
                    + "elif [ ! -r \"$1\" ] || [ ! -x \"$1\" ]; then echo denied; else echo ok; fi",
                    "sh", root.path])
            }

            Process {
                id: check
                stdout: StdioCollector {
                    onStreamFinished: stack.health = text.trim()
                }
                onExited: {
                    if (stack.probeAgain) {
                        stack.probeAgain = false
                        stack.probe()
                    }
                }
            }

            // A folder that never says it is ready is asked about as well.
            Timer {
                interval: 1200
                running: stack.shownState === "loading" && root.path !== ""
                onTriggered: stack.probe()
            }

            Connections {
                target: root
                function onOpenChanged() {
                    stack.confirmEmpty = false
                    stack.cutoffTick++
                }

                function onPathChanged() {
                    stack.confirmEmpty = false
                    stack.health = ""
                    stack.menuOpen = false
                    stack.hoverKey = ""
                    stack.hoverInfo = ""
                    if (gridLoader.item)
                        gridLoader.item.toStart()
                    if (listLoader.item)
                        listLoader.item.toStart()
                }
            }

            // ===== doing things =====
            function activate(path, isDir) {
                if (isDir) {
                    root.enter(path)
                } else {
                    FilesStackService.open(path)
                    root.closeRequested()
                }
            }

            function describe(name, isDir, size, modified) {
                let t = FilesStackService.oneLine(name) + "  ·  " + FilesStackService.typeLabel(isDir, FilesStackService.suffixOf(name))
                if (!isDir)
                    t += ", " + FilesStackService.sizeText(size)
                const d = FilesStackService.dateText(modified)
                return d !== "" ? t + "  ·  " + d : t
            }

            function hover(on, path, text) {
                if (on) {
                    stack.hoverKey = path
                    stack.hoverInfo = text
                } else if (stack.hoverKey === path) {
                    stack.hoverKey = ""
                    stack.hoverInfo = ""
                }
            }

            // Starts dragging a row out of the card: the file goes to whatever window the
            // pointer is released over. `item` is the tile or row being dragged (its own picture
            // is the drag image).
            function startDrag(item) {
                item.grabToImage(r => {
                    if (!item.dragWanted)
                        return
                    item.Drag.imageSource = r.url
                    item.Drag.active = true
                })
            }

            Keys.onEscapePressed: {
                if (stack.menuOpen)
                    stack.menuOpen = false
                else if (stack.confirmEmpty)
                    stack.confirmEmpty = false
                else
                    root.closeRequested()
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Backspace || (event.key === Qt.Key_Left && (event.modifiers & Qt.AltModifier))) {
                    root.back()
                    event.accepted = true
                } else if (event.key === Qt.Key_F5) {
                    stack.reload()
                    event.accepted = true
                }
            }

            // ===== right-click menu =====
            property bool menuOpen: false
            property var menuRows: []
            property var menuTarget: null
            property real menuX: 0
            property real menuY: 0

            // target: { path, isDir } of a row, or null for the folder itself.
            function openMenu(target, mx, my) {
                const rows = []
                if (target) {
                    if (FilesStackService.isTrashItem(target.path)) {
                        rows.push({ id: "restore", label: "Restore", icon: "restore_from_trash" })
                        rows.push({ sep: true })
                    }
                    if (target.isDir) {
                        rows.push({ id: "enter", label: "Open", icon: "folder_open" })
                        rows.push({ id: "manager", label: "Open in file manager", icon: "open_in_new" })
                    } else {
                        rows.push({ id: "open", label: "Open", icon: "open_in_new" })
                        rows.push({ id: "reveal", label: "Show in file manager", icon: "folder_open" })
                    }
                    rows.push({ sep: true })
                    rows.push({ id: "copypath", label: "Copy path", icon: "content_copy" })
                    if (!target.isDir)
                        rows.push({ id: "copyfile", label: "Copy file", icon: "file_copy" })
                    rows.push({ id: "shelf", label: "Add to Shelf", icon: "inventory_2" })
                    if (target.isDir)
                        rows.push({ id: "usefolder", label: "Use as the stack's folder", icon: "push_pin" })
                } else {
                    if (root.atTrashRoot && stack.count > 0) {
                        rows.push({ id: "emptytrash", label: "Empty Trash", icon: "delete_sweep" })
                        rows.push({ sep: true })
                    }
                    rows.push({ id: "managerhere", label: "Open this folder in file manager", icon: "open_in_new" })
                    rows.push({ id: "copyhere", label: "Copy folder path", icon: "content_copy" })
                    rows.push({ id: "refresh", label: "Refresh", icon: "refresh" })
                }
                stack.menuRows = rows
                stack.menuTarget = target
                stack.menuX = mx
                stack.menuY = my
                stack.menuOpen = true
            }

            // Folders first (on / off) and the modified filter; it stays open while you change them.
            function openViewMenu(mx, my) {
                const rows = [
                    { id: "foldersfirst", label: "Folders first",
                      icon: FilesStackService.foldersFirst ? "check_box" : "check_box_outline_blank" },
                    { sep: true }
                ]
                for (const o of FilesStackService.modifiedOptions)
                    rows.push({ id: "mod:" + o.id, label: "Modified: " + o.label,
                                icon: FilesStackService.modified === o.id ? "radio_button_checked" : "radio_button_unchecked" })
                stack.menuRows = rows
                stack.menuTarget = null
                stack.menuX = mx
                stack.menuY = my
                stack.menuOpen = true
            }

            // A key of the row of places: Open, Open in file manager (and Empty Trash on the Trash).
            function openPlaceMenu(key, mx, my) {
                const rows = [
                    { id: "goplace", label: "Open", icon: "folder_open" },
                    { id: "placemanager", label: "Open in file manager", icon: "open_in_new" }
                ]
                if (key === "TRASH") {
                    rows.push({ sep: true })
                    rows.push({ id: "emptytrash", label: "Empty Trash", icon: "delete_sweep" })
                }
                stack.menuRows = rows
                stack.menuTarget = { place: key }
                stack.menuX = mx
                stack.menuY = my
                stack.menuOpen = true
            }

            function runMenu(id) {
                if (id === "foldersfirst" || id.startsWith("mod:")) {
                    if (id === "foldersfirst")
                        SettingsService.toggle("dock.files.foldersFirst")
                    else
                        SettingsService.set("dock.files.modified", id.substring(4))
                    stack.openViewMenu(stack.menuX, stack.menuY)
                    return
                }
                const t = stack.menuTarget
                stack.menuOpen = false
                if (id === "restore") {
                    FilesStackService.restore(t.path)
                } else if (id === "emptytrash") {
                    stack.askEmptyTrash()
                } else if (id === "goplace") {
                    root.goPlace(t.place)
                } else if (id === "placemanager") {
                    if (t.place === "TRASH")
                        FilesStackService.openTrashInManager()
                    else
                        FilesStackService.openInManager(FilesStackService.placePath(t.place))
                    root.closeRequested()
                } else if (id === "enter") {
                    root.enter(t.path)
                } else if (id === "open") {
                    FilesStackService.open(t.path)
                    root.closeRequested()
                } else if (id === "manager") {
                    FilesStackService.openInManager(t.path)
                    root.closeRequested()
                } else if (id === "reveal") {
                    FilesStackService.reveal(t.path)
                    root.closeRequested()
                } else if (id === "copypath") {
                    FilesStackService.copyPath(t.path)
                } else if (id === "copyfile") {
                    FilesStackService.copyFile(t.path)
                } else if (id === "shelf") {
                    FilesStackService.addToShelf(t.path)
                } else if (id === "usefolder") {
                    FilesStackService.useAsStackFolder(t.path)
                } else if (id === "managerhere") {
                    if (root.atTrashRoot)
                        FilesStackService.openTrashInManager()
                    else
                        FilesStackService.openInManager(root.path)
                    root.closeRequested()
                } else if (id === "copyhere") {
                    FilesStackService.copyPath(root.path)
                } else if (id === "refresh") {
                    stack.reload()
                }
            }

            // ===== header =====
            Item {
                id: header
                width: parent.width
                height: root.headH

                Row {
                    id: leftRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9

                    DockButton {
                        visible: !root.atRoot
                        anchors.verticalCenter: parent.verticalCenter
                        height: 34
                        icon: "arrow_back"
                        iconSize: 20
                        onClicked: root.back()
                    }

                    Rectangle {
                        visible: root.atRoot
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13
                        height: 13
                        radius: 4
                        rotation: 45
                        color: Theme.accentMint
                        border.width: 2
                        border.color: Theme.line
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            id: titleText
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, Math.max(60, header.width - leftRow.x - (root.atRoot ? 22 : 53)
                                                                    - rightRow.width - 14 - countText.implicitWidth - 8))
                            elide: Text.ElideMiddle
                            textFormat: Text.PlainText
                            text: FilesStackService.oneLine(FilesStackService.titleFor(root.path))
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 20
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                        }

                        Text {
                            id: countText
                            anchors.verticalCenter: parent.verticalCenter
                            visible: stack.count > 0
                            text: stack.filtering ? stack.count + " of " + stack.rawCount : stack.count + (stack.count === 1 ? " item" : " items")
                            color: Theme.inkSub
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                        }
                    }
                }

                Row {
                    id: rightRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    DockButton {
                        visible: root.atTrashRoot && stack.count > 0
                        height: 34
                        icon: "delete_sweep"
                        iconSize: 20
                        label: "Empty"
                        fontSize: 14
                        selected: stack.confirmEmpty
                        onClicked: stack.askEmptyTrash()
                    }

                    DockButton {
                        height: 34
                        icon: "grid_view"
                        iconSize: 20
                        selected: root.viewMode === "grid"
                        onClicked: SettingsService.set("dock.files.view", "grid")
                    }

                    DockButton {
                        height: 34
                        icon: "view_list"
                        iconSize: 20
                        selected: root.viewMode === "list"
                        onClicked: SettingsService.set("dock.files.view", "list")
                    }

                    DockButton {
                        height: 34
                        icon: "open_in_new"
                        iconSize: 20
                        onClicked: {
                            if (root.atTrashRoot)
                                FilesStackService.openTrashInManager()
                            else
                                FilesStackService.openInManager(root.path)
                            root.closeRequested()
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 2
                    radius: 1
                    color: Theme.surfaceDivider
                }
            }

            // ===== the places =====
            Item {
                id: placesRow
                y: root.placesTop
                width: parent.width
                height: root.placesH

                readonly property int n: FilesStackService.places.length
                readonly property real keyW: 52
                readonly property real gap: placesRow.n > 1 ? Math.max(2, (placesRow.width - placesRow.n * placesRow.keyW) / (placesRow.n - 1)) : 0

                Repeater {
                    model: FilesStackService.places

                    delegate: Item {
                        id: pl

                        required property var modelData
                        required property int index

                        x: pl.index * (placesRow.keyW + placesRow.gap)
                        width: placesRow.keyW
                        height: placesRow.height

                        HoverHandler {
                            onHoveredChanged: stack.hover(hovered, "place:" + pl.modelData.key,
                                                          pl.modelData.key === "TRASH" ? "Trash  ·  right-click for Empty Trash" : pl.modelData.label)
                        }

                        DockButton {
                            anchors.fill: parent
                            icon: pl.modelData.icon
                            iconSize: 24
                            selected: root.activePlace === pl.modelData.key
                            onClicked: root.goPlace(pl.modelData.key)
                        }

                        // Right-click: Open / Open in file manager (and Empty Trash on the Trash).
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            onClicked: mouse => {
                                const p = mapToItem(stack, mouse.x, mouse.y)
                                stack.openPlaceMenu(pl.modelData.key, p.x, p.y)
                            }
                        }
                    }
                }
            }

            // ===== the listing =====
            Item {
                id: bodyArea
                y: root.bodyTop
                width: parent.width
                height: root.bodyH

                // The folder's own menu (right-click on the empty part). The rows sit above this.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: mouse => {
                        const p = mapToItem(stack, mouse.x, mouse.y)
                        stack.openMenu(null, p.x, p.y)
                    }
                }

                Loader {
                    id: gridLoader
                    x: -root.cellGap / 2
                    width: root.cols * (root.tileW + root.cellGap)
                    height: parent.height
                    active: root.viewMode === "grid" && stack.count > 0
                    sourceComponent: gridComp
                }

                Loader {
                    id: listLoader
                    width: parent.width
                    height: parent.height
                    active: root.viewMode === "list" && stack.count > 0
                    sourceComponent: listComp
                }

                // Nothing to show: empty, gone, or not allowed.
                Column {
                    anchors.centerIn: parent
                    width: parent.width - 32
                    visible: stack.count === 0 && stack.shownState !== "loading"
                    spacing: 6

                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: stack.shownState === "filtered" ? "filter_alt_off"
                              : stack.trashGone ? "delete"
                              : stack.shownState === "missing" ? "folder_off"
                              : (stack.shownState === "denied" ? "lock"
                              : (stack.shownState === "notdir" ? "block" : "folder_open"))
                        size: 44
                        color: Theme.inkSub
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: stack.shownState === "filtered" ? "Nothing modified here"
                              : stack.trashGone ? "Trash is empty"
                              : stack.shownState === "missing" ? "Folder not found"
                              : (stack.shownState === "denied" ? "Can't open this folder"
                              : (stack.shownState === "notdir" ? "Not a folder" : "Nothing here"))
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideMiddle
                        textFormat: Text.PlainText
                        text: stack.shownState === "filtered" ? FilesStackService.modifiedLabel(FilesStackService.modified)
                              : stack.shownState === "denied" ? "You don't have permission to read it"
                              : (stack.trashGone ? "What you delete waits here" : root.path)
                        color: Theme.inkSub
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }

                    // The filter hides everything: a way back.
                    DockButton {
                        visible: stack.shownState === "filtered"
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 34
                        icon: "all_inclusive"
                        label: "Show everything"
                        fontSize: 14
                        iconSize: 20
                        onClicked: SettingsService.set("dock.files.modified", "any")
                    }

                    // The stack's own folder is gone or unreadable: a way out.
                    DockButton {
                        visible: root.atRoot && stack.shownState !== "empty" && stack.shownState !== "filtered" && !stack.trashGone && root.path !== FilesStackService.home
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 34
                        icon: "home"
                        label: "Go to Home"
                        fontSize: 14
                        iconSize: 20
                        onClicked: root.enter(FilesStackService.home)
                    }
                }
            }

            // ===== footer =====
            Item {
                id: footer
                y: root.bodyTop + root.bodyH + root.sec
                width: parent.width
                height: root.footH

                Rectangle {
                    width: parent.width
                    height: 2
                    radius: 1
                    color: Theme.surfaceDivider
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1
                    width: footer.width - footRow.width - 12
                    elide: Text.ElideMiddle
                    textFormat: Text.PlainText
                    text: stack.hoverInfo !== "" ? stack.hoverInfo
                          : (stack.filtering ? FilesStackService.modifiedLabel(FilesStackService.modified) + "  ·  " : "") + stack.sortText
                    color: Theme.inkSub
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }

                Row {
                    id: footRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1
                    spacing: 6

                    // Folders first, and the modified filter.
                    DockButton {
                        height: 32
                        icon: "tune"
                        iconSize: 19
                        selected: stack.filtering || FilesStackService.foldersFirst
                        onClicked: {
                            const p = mapToItem(stack, width / 2, 0)
                            stack.openViewMenu(p.x, p.y)
                        }
                    }

                    DockButton {
                        height: 32
                        icon: "sort"
                        iconSize: 19
                        label: FilesStackService.sortBy === "date" ? "Modified" : (FilesStackService.sortBy === "type" ? "Type" : "Name")
                        fontSize: 14
                        onClicked: SettingsService.set("dock.files.sort",
                            FilesStackService.sortBy === "name" ? "date" : (FilesStackService.sortBy === "date" ? "type" : "name"))
                    }

                    DockButton {
                        height: 32
                        icon: stack.sortDescending ? "arrow_downward" : "arrow_upward"
                        iconSize: 19
                        onClicked: SettingsService.toggle("dock.files.reverse")
                    }

                    DockButton {
                        height: 32
                        icon: FilesStackService.showHidden ? "visibility" : "visibility_off"
                        iconSize: 19
                        selected: FilesStackService.showHidden
                        onClicked: SettingsService.toggle("dock.files.hidden")
                    }

                    DockButton {
                        height: 32
                        icon: "refresh"
                        iconSize: 19
                        onClicked: stack.reload()
                    }
                }

                // Over the whole footer while Empty Trash waits for a yes.
                Rectangle {
                    visible: stack.confirmEmpty
                    anchors.fill: parent
                    anchors.topMargin: 3
                    z: 5
                    radius: 12
                    color: Theme.surface
                    border.width: 2.5
                    border.color: Theme.line
                    antialiasing: true

                    MouseArea {
                        anchors.fill: parent
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - confirmRow.width - 36
                        elide: Text.ElideRight
                        text: "Empty the Trash for good?"
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }

                    Row {
                        id: confirmRow
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        DockButton {
                            height: 32
                            label: "Cancel"
                            fontSize: 14
                            onClicked: stack.confirmEmpty = false
                        }

                        DockButton {
                            height: 32
                            icon: "delete_forever"
                            iconSize: 19
                            label: "Empty"
                            fontSize: 14
                            accent: true
                            onClicked: stack.doEmptyTrash()
                        }
                    }
                }
            }

            readonly property bool sortDescending: (FilesStackService.sortBy === "date") !== FilesStackService.reverse
            readonly property string sortText: {
                const by = FilesStackService.sortBy
                if (by === "date")
                    return "Modified, " + (stack.sortDescending ? "newest first" : "oldest first")
                return (by === "type" ? "Type" : "Name") + (stack.sortDescending ? ", Z to A" : ", A to Z")
            }

            // ===== the menu, above everything =====
            MouseArea {
                anchors.fill: parent
                z: 55
                visible: stack.menuOpen
                acceptedButtons: Qt.AllButtons
                onPressed: stack.menuOpen = false
            }

            Rectangle {
                x: menuBox.x + 3
                y: menuBox.y + 4
                z: 59
                width: menuBox.width
                height: menuBox.height
                radius: menuBox.radius
                color: Theme.lineShadow
                visible: stack.menuOpen
            }

            Rectangle {
                id: menuBox
                z: 60
                visible: stack.menuOpen
                width: 252
                height: menuCol.implicitHeight + 12
                x: Math.max(0, Math.min(stack.menuX, stack.width - width - 4))
                y: Math.max(0, Math.min(stack.menuY, stack.height - height - 4))
                radius: 12
                color: Theme.surface
                border.width: 2.5
                border.color: Theme.line
                antialiasing: true

                Column {
                    id: menuCol
                    x: 6
                    y: 6
                    width: parent.width - 12
                    spacing: 1

                    Repeater {
                        model: stack.menuRows

                        delegate: Item {
                            id: mrow
                            required property var modelData

                            readonly property bool isSep: mrow.modelData.sep === true

                            width: menuCol.width
                            height: mrow.isSep ? 9 : 36

                            Rectangle {
                                visible: mrow.isSep
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 2
                                radius: 1
                                color: Theme.surfaceDivider
                            }

                            Rectangle {
                                visible: !mrow.isSep
                                anchors.fill: parent
                                radius: 9
                                color: mArea.containsMouse
                                    ? Qt.rgba(Theme.accentCyan.r, Theme.accentCyan.g, Theme.accentCyan.b, mArea.pressed ? 0.34 : 0.2)
                                    : "transparent"
                                antialiasing: true

                                MaterialIcon {
                                    x: 9
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: mrow.modelData.icon ?? ""
                                    size: 21
                                }

                                Text {
                                    x: 37
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 46
                                    elide: Text.ElideRight
                                    text: mrow.modelData.label ?? ""
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                }
                            }

                            MouseArea {
                                id: mArea
                                enabled: !mrow.isSep
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: stack.runMenu(mrow.modelData.id)
                            }
                        }
                    }
                }
            }

            // ===== what a tile / a row is (the filter model below hands these to the views) =====
            Component {
                id: gridDelegate

                Item {
                            id: cell

                            required property string fileName
                            required property string filePath
                            required property url fileUrl
                            required property bool fileIsDir
                            required property var fileSize
                            required property var fileModified

                            width: root.tileW + root.cellGap
                            height: root.tileH + root.cellGap

                            Item {
                                id: tile
                                x: root.cellGap / 2
                                width: root.tileW
                                height: root.tileH

                                // A row being dragged out of the card.
                                property bool dragWanted: dh.active
                                Drag.dragType: Drag.Automatic
                                Drag.supportedActions: Qt.CopyAction
                                Drag.hotSpot.x: tile.width / 2
                                Drag.hotSpot.y: tile.height / 2
                                Drag.mimeData: ({ "text/uri-list": cell.fileUrl.toString() + "\r\n" })

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 13
                                    antialiasing: true
                                    color: area.containsMouse
                                        ? Qt.rgba(Theme.accentCyan.r, Theme.accentCyan.g, Theme.accentCyan.b, area.pressed ? 0.34 : 0.2)
                                        : (cell.fileIsDir
                                            ? Qt.rgba(Theme.accentMint.r, Theme.accentMint.g, Theme.accentMint.b, 0.13)
                                            : "transparent")

                                    Behavior on color {
                                        ColorAnimation { duration: 90 }
                                    }
                                }

                                DockFilesIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 10
                                    iconSize: 52
                                    name: cell.fileName
                                    source: cell.fileUrl
                                    path: cell.filePath
                                    modified: cell.fileModified
                                    isDir: cell.fileIsDir
                                    bytes: Number(cell.fileSize)
                                    scale: area.containsMouse ? 1.07 : 1
                                    Behavior on scale {
                                        NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 2 }
                                    }
                                }

                                Text {
                                    x: 4
                                    y: 66
                                    width: tile.width - 8
                                    height: 42
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignTop
                                    wrapMode: Text.WrapAnywhere
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    text: FilesStackService.oneLine(cell.fileName)
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.weight: cell.fileIsDir ? Font.ExtraBold : Font.Bold
                                }

                                MouseArea {
                                    id: area
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onContainsMouseChanged: stack.hover(containsMouse, cell.filePath,
                                        stack.describe(cell.fileName, cell.fileIsDir, cell.fileSize, cell.fileModified))
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            const p = mapToItem(stack, mouse.x, mouse.y)
                                            stack.openMenu({ path: cell.filePath, isDir: cell.fileIsDir }, p.x, p.y)
                                        } else {
                                            stack.activate(cell.filePath, cell.fileIsDir)
                                        }
                                    }
                                }

                                DragHandler {
                                    id: dh
                                    target: null
                                    acceptedButtons: Qt.LeftButton
                                    onActiveChanged: {
                                        if (active)
                                            stack.startDrag(tile)
                                        else
                                            tile.Drag.active = false
                                    }
                                }
                            }
                        }
            }

            Component {
                id: listDelegate

                Item {
                            id: row

                            required property string fileName
                            required property string filePath
                            required property url fileUrl
                            required property bool fileIsDir
                            required property var fileSize
                            required property var fileModified

                            width: bodyArea.width
                            height: root.rowH

                            property bool dragWanted: rdh.active
                            Drag.dragType: Drag.Automatic
                            Drag.supportedActions: Qt.CopyAction
                            Drag.hotSpot.x: 24
                            Drag.hotSpot.y: row.height / 2
                            Drag.mimeData: ({ "text/uri-list": row.fileUrl.toString() + "\r\n" })

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                antialiasing: true
                                color: rarea.containsMouse
                                    ? Qt.rgba(Theme.accentCyan.r, Theme.accentCyan.g, Theme.accentCyan.b, rarea.pressed ? 0.34 : 0.2)
                                    : (row.fileIsDir
                                        ? Qt.rgba(Theme.accentMint.r, Theme.accentMint.g, Theme.accentMint.b, 0.13)
                                        : "transparent")

                                Behavior on color {
                                    ColorAnimation { duration: 90 }
                                }
                            }

                            DockFilesIcon {
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                iconSize: 32
                                name: row.fileName
                                source: row.fileUrl
                                path: row.filePath
                                modified: row.fileModified
                                isDir: row.fileIsDir
                                bytes: Number(row.fileSize)
                            }

                            Text {
                                x: 52
                                anchors.verticalCenter: parent.verticalCenter
                                width: row.width - 52 - (row.fileIsDir ? 106 : 192)
                                elide: Text.ElideMiddle
                                maximumLineCount: 1
                                textFormat: Text.PlainText
                                text: FilesStackService.oneLine(row.fileName)
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                font.weight: row.fileIsDir ? Font.ExtraBold : Font.Bold
                            }

                            // Size, then when it was last changed.
                            Text {
                                visible: !row.fileIsDir
                                x: row.width - 190
                                anchors.verticalCenter: parent.verticalCenter
                                width: 80
                                horizontalAlignment: Text.AlignRight
                                text: FilesStackService.sizeText(row.fileSize)
                                color: Theme.inkSub
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }

                            Text {
                                x: row.width - 104
                                anchors.verticalCenter: parent.verticalCenter
                                width: 96
                                horizontalAlignment: Text.AlignRight
                                text: FilesStackService.dateText(row.fileModified)
                                color: Theme.inkSub
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                id: rarea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: stack.hover(containsMouse, row.filePath,
                                    stack.describe(row.fileName, row.fileIsDir, row.fileSize, row.fileModified))
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        const p = mapToItem(stack, mouse.x, mouse.y)
                                        stack.openMenu({ path: row.filePath, isDir: row.fileIsDir }, p.x, p.y)
                                    } else {
                                        stack.activate(row.filePath, row.fileIsDir)
                                    }
                                }
                            }

                            DragHandler {
                                id: rdh
                                target: null
                                acceptedButtons: Qt.LeftButton
                                onActiveChanged: {
                                    if (active)
                                        stack.startDrag(row)
                                    else
                                        row.Drag.active = false
                                }
                            }
                        }
            }

            FilesFilterModel {
                id: shownGrid
                source: files
                active: stack.filtering
                cutoff: stack.cutoff
                delegate: gridDelegate
            }

            FilesFilterModel {
                id: shownList
                source: files
                active: stack.filtering
                cutoff: stack.cutoff
                delegate: listDelegate
            }

            // ===== the two views =====
            Component {
                id: gridComp

                Item {
                    function toStart() {
                        grid.positionViewAtBeginning()
                    }

                    GridView {
                        id: grid
                        anchors.fill: parent
                        clip: true
                        model: shownGrid
                        cellWidth: root.tileW + root.cellGap
                        cellHeight: root.tileH + root.cellGap
                        cacheBuffer: 120
                        boundsBehavior: Flickable.StopAtBounds



                        SekaiScrollBar {}
                    }

                    // A notch moves 340 px here (the shell's usual is Theme.wheelStep, 110): about three rows of tiles.
                    WheelScroll {
                        scroller: grid
                        step: 340
                    }
                }
            }

            Component {
                id: listComp

                Item {
                    function toStart() {
                        list.positionViewAtBeginning()
                    }

                    ListView {
                        id: list
                        anchors.fill: parent
                        clip: true
                        model: shownList
                        spacing: 2
                        cacheBuffer: 120
                        boundsBehavior: Flickable.StopAtBounds



                        SekaiScrollBar {}
                    }

                    // 340 px a notch (the shell's usual is Theme.wheelStep, 110): about eight rows.
                    WheelScroll {
                        scroller: list
                        step: 340
                    }
                }
            }
        }
    }
}
