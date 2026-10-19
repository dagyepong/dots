import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.launcher
import qs.modules.sekai.phone

// The screen of the Wallpapers phone (WallpaperStage.qml): what is drawn inside
// the flat landscape PhoneBody. A gallery app, with everything the wallpaper
// board (the old WallpaperGallery.qml, now removed) had:
//
//   GALLERY  (camera)  <Wallpapers banner>                   clock   <x>
//            (cut-out) [Desktop|Lockscreen]  12 wallpapers   [search] [Newest] (o)(o)(o)
//                      ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
//                      │ pic  │ │ pic  │ │ pic  │ ...        a grid of thumbnails,
//                      └──────┘ └──────┘ └──────┘            scrolling
//
//   VIEWER   (camera)  <Wallpapers banner>        [Gallery]  clock   <x>
//            (cut-out) ┌──────────────────────┐   name
//                      │   the picture        │   [ Set as Desktop    ]
//                      └──────────────────────┘   [ Set as Lockscreen ]   < >
//
// The toolbar is the board's header: the Desktop | Lockscreen switch (only with
// Separate Lockscreen Wallpaper on; it chooses which side's applied picture the
// gallery marks, and the lockscreen side wears the lockscreen's own colours), a
// search field (or just start typing), the sort menu, "jump to applied",
// shuffle (jumps to a random one) and refresh (the dot says the folder changed
// since the list was made; sorting never reads the folder).
//
// Tap a picture to open it in the viewer. The viewer has the two actions:
// Set as Desktop (WallpaperService.setWallpaper) and Set as Lockscreen
// (WallpaperService.setLockWallpaper). With "One wallpaper per monitor" on they
// change this monitor only, and Shift+click changes every monitor. Set as
// Lockscreen turns "Separate Lockscreen Wallpaper" on if it is off (the
// lockscreen would otherwise just follow the desktop), keeping what the
// lockscreen shows now.
//
// The gallery has two looks, switched by the round button at the end of the
// toolbar: the WHEEL (WallpaperWheel.qml, the default: a Ferris wheel the
// pictures hang from; spin it, click the one in front to open it, or set it
// straight from the two keys under it) and the plain GRID above.
//
// Keys: arrows move (on the wheel Left / Right turn it), Enter opens, Escape
// steps back (sort menu, search, viewer, then the launcher phone), Tab flips
// Desktop / Lockscreen, Home / End.
// In the viewer: Left / Right = previous / next, Enter = Set as Desktop.
//
// The camera cut-out is on the left edge, so everything beside it keeps
// `safeLeft` clear. Pure UI apart from WallpaperService: the only thing it
// asks of the outside is `closeRequested()`.
Item {
    id: face

    // Keeps the classic (white) look in the first dark mode; see Theme.classicFor.
    readonly property bool classicPanel: true

    width: 1440
    height: 760

    // ===== given by WallpaperStage.qml =====
    property string screenName: ""
    property string clockText: "00:00AM"
    property string dateText: "Sun, 20  Sep"
    property real screenInset: 26
    property real cornerRadius: 92
    property real renderScale: 1

    // Back to the launcher phone.
    signal closeRequested()

    // ===== layout (design units) =====
    readonly property real safeLeft: 96
    readonly property real safeRight: 50
    readonly property real pageX: safeLeft
    readonly property real pageTop: 114
    readonly property real pageWidth: width - safeLeft - safeRight
    readonly property real pageHeight: 594

    // The toolbar sits on top of the page; the grid under it holds three rows.
    readonly property real toolbarH: 46
    readonly property real galleryTop: pageTop + 58
    readonly property real galleryHeight: pageHeight - 58

    readonly property int columns: 5
    readonly property real cellW: Math.floor(pageWidth / columns)
    readonly property real cellH: 178

    // ===== state =====
    // The picture open in the viewer: its place in `matched` (-1 = the gallery).
    property int viewIndex: -1
    property string viewPath: ""
    property string viewName: ""
    readonly property bool viewing: viewIndex >= 0

    property real viewP: viewing ? 1 : 0
    Behavior on viewP {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    // The gallery as a wheel (WallpaperWheel.qml) instead of the grid.
    property bool carousel: true
    property real carouselP: carousel ? 1 : 0
    Behavior on carouselP {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    // The pick comes from the arrow keys (not the mouse).
    property bool keyNav: false
    // "desktop" / "lock" for a moment after one was set.
    property string justSet: ""

    // Which side the gallery is choosing for / marking (the Desktop |
    // Lockscreen switch; only there with Separate Lockscreen Wallpaper on).
    property string target: "desktop"
    readonly property bool lockMode: WallpaperService.separateLock && face.target === "lock"

    // What is on this monitor right now.
    readonly property string desktopPath: WallpaperService.pathFor(face.screenName)
    readonly property string lockPath: WallpaperService.lockPathFor(face.screenName)
    readonly property string currentPath: face.lockMode ? face.lockPath : face.desktopPath
    readonly property string otherPath: !WallpaperService.separateLock ? ""
                                        : (face.lockMode ? face.desktopPath : face.lockPath)

    readonly property bool viewIsVideo: face.viewPath !== "" && WallpaperService.isVideo(face.viewPath)

    // ===== the list =====
    // Same idea as the wallpaper picker's: the folder is read into a snapshot
    // (`items`, in the chosen order) and the gallery shows what matches the
    // search. Sorting re-orders the snapshot without reading the folder, and a
    // file added later only lights the dot on Refresh until it is pressed.
    property var items: []
    property var matched: []
    property string searchText: ""
    property string sortMode: "date_desc"
    property bool sortOpen: false
    property bool hasNew: false
    property bool listed: false

    readonly property var sortOptions: [
        { mode: "date_desc", label: "Date added (newest first)", short: "Newest" },
        { mode: "date_asc",  label: "Date added (oldest first)", short: "Oldest" },
        { mode: "name_asc",  label: "Name (A to Z)",             short: "A\u2013Z" },
        { mode: "name_desc", label: "Name (Z to A)",             short: "Z\u2013A" },
        { mode: "size_desc", label: "Size (largest first)",      short: "Largest" },
        { mode: "size_asc",  label: "Size (smallest first)",     short: "Smallest" }
    ]

    readonly property string sortShort: {
        for (const o of face.sortOptions) {
            if (o.mode === face.sortMode)
                return o.short
        }
        return ""
    }

    readonly property string subtitle: (WallpaperService.separateLock ? (face.lockMode ? "Lockscreen only  \u00b7  " : "Desktop only  \u00b7  ") : "")
        + (face.searchText.trim() !== ""
            ? face.matched.length + " of " + face.items.length + " match"
            : face.items.length + (face.items.length === 1 ? " wallpaper" : " wallpapers"))
        + (WallpaperService.perMonitor && face.screenName !== "" ? "  \u00b7  for " + face.screenName : "")
        + (WallpaperService.customFolder ? "  \u00b7  " + WallpaperService.directoryShort : "")

    FolderListModel {
        id: files
        folder: WallpaperService.directoryUrl
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp",
                      "*.mp4", "*.webm", "*.mkv", "*.mov", "*.avi"]
        showDirs: false
        sortField: FolderListModel.Name

        onStatusChanged: {
            if (status === FolderListModel.Ready && !face.listed)
                face.refresh()
        }
        onCountChanged: {
            // Before the first listing the count is still filling in; after it,
            // a change only lights the dot on Refresh.
            if (!face.listed) {
                if (status === FolderListModel.Ready)
                    face.refresh()
            } else {
                face.hasNew = true
            }
        }
    }

    // A different wallpaper folder was chosen: read it from scratch (the first
    // listing of it refreshes the gallery by itself) instead of lighting the
    // dot on Refresh as if a file had been added to the old one.
    Connections {
        target: WallpaperService

        function onDirectoryChanged() {
            face.listed = false
            face.searchText = ""
            if (files.status === FolderListModel.Ready)
                Qt.callLater(face.refresh)
        }
    }

    Component.onCompleted: {
        if (files.status === FolderListModel.Ready)
            face.refresh()
    }

    function sortItems(list, mode) {
        const sorted = list.slice()
        if (mode === "name_asc")
            sorted.sort((a, b) => a.fileName.localeCompare(b.fileName, undefined, { numeric: true, sensitivity: "base" }))
        else if (mode === "name_desc")
            sorted.sort((a, b) => b.fileName.localeCompare(a.fileName, undefined, { numeric: true, sensitivity: "base" }))
        else if (mode === "size_desc")
            sorted.sort((a, b) => b.fileSize - a.fileSize)
        else if (mode === "size_asc")
            sorted.sort((a, b) => a.fileSize - b.fileSize)
        else if (mode === "date_asc")
            sorted.sort((a, b) => a.fileModified - b.fileModified)
        else
            sorted.sort((a, b) => b.fileModified - a.fileModified)
        return sorted
    }

    // Read the folder again.
    function refresh() {
        const list = []
        for (let i = 0; i < files.count; i++) {
            const mod = files.get(i, "fileModified")
            list.push({
                fileName: files.get(i, "fileName") || "",
                filePath: files.get(i, "filePath") || "",
                fileSize: files.get(i, "fileSize") || 0,
                fileModified: mod ? new Date(mod).getTime() : 0
            })
        }
        face.items = face.sortItems(list, face.sortMode)
        face.listed = true
        face.hasNew = false
        face.recompute()
    }

    // Re-order what is already listed (never reads the folder).
    function setSort(mode) {
        face.sortMode = mode
        face.items = face.sortItems(face.items, mode)
        face.recompute()
        grid.positionViewAtBeginning()
    }

    function recompute() {
        const q = face.searchText.trim().toLowerCase()
        face.matched = q === "" ? face.items
            : face.items.filter(it => it.fileName.toLowerCase().indexOf(q) !== -1)
    }

    onSearchTextChanged: {
        face.recompute()
        Qt.callLater(() => grid.positionViewAtBeginning())
    }

    function baseName(fileName) {
        const i = fileName.lastIndexOf(".")
        return i > 0 ? fileName.slice(0, i) : fileName
    }

    // ===== the toolbar's buttons =====
    function goTo(i) {
        if (i < 0 || i >= face.matched.length)
            return
        if (face.carousel) {
            wheelView.rotateTo(i)
            return
        }
        grid.currentIndex = i
        face.keyNav = true
        grid.positionViewAtIndex(i, GridView.Center)
    }

    function jumpToApplied() {
        face.sortOpen = false
        for (let i = 0; i < face.matched.length; i++) {
            if (face.matched[i].filePath === face.currentPath) {
                face.goTo(i)
                return
            }
        }
    }

    function shuffle() {
        face.sortOpen = false
        if (face.matched.length > 0)
            face.goTo(Math.floor(Math.random() * face.matched.length))
    }

    // ===== actions =====
    function showIndex(i) {
        const n = face.matched.length
        if (n <= 0)
            return
        const k = ((i % n) + n) % n
        face.sortOpen = false
        face.viewIndex = k
        face.viewPath = face.matched[k].filePath
        face.viewName = face.matched[k].fileName
        grid.currentIndex = k
        // the wheel follows the viewer's Left / Right, so Gallery lands on it
        wheelView.rotateTo(k)
        face.justSet = ""
    }

    // The round button at the toolbar's end: wheel <-> grid, keeping the place.
    function toggleLook() {
        face.sortOpen = false
        if (face.carousel) {
            const i = wheelView.centerIndex
            if (i >= 0) {
                grid.currentIndex = i
                grid.positionViewAtIndex(i, GridView.Center)
            }
        } else if (grid.currentIndex >= 0) {
            wheelView.rotateTo(grid.currentIndex)
        }
        face.carousel = !face.carousel
    }

    function closeViewer() {
        if (face.viewIndex >= 0)
            grid.positionViewAtIndex(face.viewIndex, GridView.Contain)
        face.viewIndex = -1
        face.justSet = ""
    }

    // Escape: one step back.
    function back() {
        if (face.sortOpen)
            face.sortOpen = false
        else if (face.viewing)
            face.closeViewer()
        else if (face.searchText !== "")
            search.clear()
        else
            face.closeRequested()
    }

    // `all`: every monitor (only means something with One wallpaper per monitor on).
    // `path`: the picture to set (the wheel passes the one in front); the
    // viewer's keys leave it out and mean the one it has open.
    function setDesktop(all, path) {
        const p = (path !== undefined && path !== "") ? path : face.viewPath
        if (p === "")
            return
        if (all)
            WallpaperService.setWallpaper(p)
        else
            WallpaperService.setWallpaper(p, face.screenName)
        face.flash("desktop")
    }

    function setLock(all, path) {
        const p = (path !== undefined && path !== "") ? path : face.viewPath
        if (p === "")
            return
        // Without a lockscreen of its own the lockscreen just follows the
        // desktop, so picking one here has to turn that on.
        if (!WallpaperService.separateLock)
            WallpaperService.setSeparateLock(true)
        if (all)
            WallpaperService.setLockWallpaper(p)
        else
            WallpaperService.setLockWallpaper(p, face.screenName)
        face.flash("lock")
    }

    function flash(which) {
        face.justSet = which
        flashTimer.restart()
    }

    // Spin the wheel in from the left again (the phone showing a gallery that was
    // built while it was out of sight; see SettingsStage.dealIfWarm).
    function replayDeal() {
        if (face.carousel)
            wheelView.deal()
    }

    Timer {
        id: flashTimer
        interval: 1500
        onTriggered: face.justSet = ""
    }

    focus: true

    Keys.onPressed: event => {
        const k = event.key
        if (k === Qt.Key_Escape) {
            face.back()
            event.accepted = true
            return
        }
        if (face.viewing) {
            if (k === Qt.Key_Left) {
                face.showIndex(face.viewIndex - 1)
                event.accepted = true
            } else if (k === Qt.Key_Right) {
                face.showIndex(face.viewIndex + 1)
                event.accepted = true
            } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                face.setDesktop((event.modifiers & Qt.ShiftModifier) !== 0)
                event.accepted = true
            }
            return
        }
        // Tab flips Desktop <-> Lockscreen (only there with Separate Lockscreen Wallpaper on).
        if (WallpaperService.separateLock && (k === Qt.Key_Tab || k === Qt.Key_Backtab)) {
            face.sortOpen = false
            face.target = face.lockMode ? "desktop" : "lock"
            event.accepted = true
            return
        }
        if (face.carousel) {
            if (k === Qt.Key_Left) {
                wheelView.stepBy(-1)
            } else if (k === Qt.Key_Right) {
                wheelView.stepBy(1)
            } else if (k === Qt.Key_Home) {
                wheelView.toStart()
            } else if (k === Qt.Key_End) {
                wheelView.toEnd()
            } else if ((k === Qt.Key_Return || k === Qt.Key_Enter) && wheelView.centerIndex >= 0) {
                face.showIndex(wheelView.centerIndex)
            } else if (k === Qt.Key_Up || k === Qt.Key_Down) {
                // nothing to move through on a wheel
            } else {
                // typing still searches, same as the grid
                if (!(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                    const tc = event.text
                    if (tc.length === 1 && tc.charCodeAt(0) > 32 && tc.charCodeAt(0) !== 127) {
                        face.sortOpen = false
                        search.begin(tc)
                        event.accepted = true
                    }
                }
                return
            }
            event.accepted = true
            return
        }
        if (k === Qt.Key_Home) {
            grid.positionViewAtBeginning()
            event.accepted = true
            return
        }
        if (k === Qt.Key_End) {
            grid.positionViewAtEnd()
            event.accepted = true
            return
        }
        if (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_Up || k === Qt.Key_Down) {
            if (face.matched.length > 0) {
                if (!face.keyNav || grid.currentIndex < 0) {
                    face.keyNav = true
                    if (grid.currentIndex < 0)
                        grid.currentIndex = 0
                } else if (k === Qt.Key_Left) {
                    grid.moveCurrentIndexLeft()
                } else if (k === Qt.Key_Right) {
                    grid.moveCurrentIndexRight()
                } else if (k === Qt.Key_Up) {
                    grid.moveCurrentIndexUp()
                } else {
                    grid.moveCurrentIndexDown()
                }
            }
            event.accepted = true
            return
        }
        if ((k === Qt.Key_Return || k === Qt.Key_Enter) && grid.currentIndex >= 0) {
            face.showIndex(grid.currentIndex)
            event.accepted = true
            return
        }
        // Just start typing to search.
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return
        const t = event.text
        if (t.length === 1 && t.charCodeAt(0) > 32 && t.charCodeAt(0) !== 127) {
            face.sortOpen = false
            search.begin(t)
            event.accepted = true
        }
    }

    // ===== backdrop, inside the glass =====
    Item {
        id: screenArea

        x: face.screenInset
        y: face.screenInset
        width: face.width - 2 * face.screenInset
        height: face.height - 2 * face.screenInset
        z: -10

        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(Math.ceil(width * face.renderScale * 2),
                                   Math.ceil(height * face.renderScale * 2))
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: screenMask
        }

        SekaiBackdrop {
            x: -face.screenInset
            y: -face.screenInset
            width: face.width
            height: face.height
        }
    }

    Item {
        id: screenMask
        width: screenArea.width
        height: screenArea.height
        visible: false
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(Math.ceil(width * face.renderScale * 2),
                                   Math.ceil(height * face.renderScale * 2))

        Rectangle {
            anchors.fill: parent
            color: "black"
            radius: Math.max(0, face.cornerRadius - face.screenInset)
            antialiasing: true
        }
    }

    // ===== header =====
    Item {
        id: banner

        x: face.safeLeft - 8
        y: 28
        height: 70
        width: bannerKey.capW + 8

        SekaiKey {
            id: bannerKey

            capW: 420
            capH: 66
            radius: 26
            lit: true
            litP: 1
            borderBase: 4
            borderLit: 4
            ringExtra: 5
            shadowBaseX: 5
            shadowBaseY: 4

            Rectangle {
                x: 54 - width / 2
                y: (bannerKey.capH - height) / 2
                width: 34
                height: 34
                radius: 10
                rotation: 45
                color: Theme.colBg
                border.width: 3
                border.color: Theme.colBorder
                antialiasing: true
            }

            MaterialIcon {
                x: 54 - width / 2
                y: (bannerKey.capH - height) / 2
                size: 24
                name: face.lockMode ? "lock" : "wallpaper"
                color: Theme.colBorder
            }

            Column {
                x: 92
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: "Wallpapers"
                    color: Theme.colBorder
                    font.family: Theme.fontFamily
                    font.pixelSize: 28
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                    lineHeight: 29
                    lineHeightMode: Text.FixedHeight
                }

                Text {
                    text: face.viewing ? "Preview" : (face.carousel ? "Spin the wheel" : "Pick a picture")
                    color: Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, 0.78)
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    lineHeight: 17
                    lineHeightMode: Text.FixedHeight
                }
            }

            MaterialIcon {
                x: bannerKey.capW - 52
                y: 8
                size: 24
                name: "star"
                rotation: 14
                color: Theme.colBg
            }
        }
    }

    SekaiKey {
        id: clockChip

        x: closeButton.x - 16 - capW - 6
        y: 34
        capW: Math.max(clockLabel.implicitWidth, dateLabel.implicitWidth) + 62
        capH: 56
        radius: 20

        Column {
            anchors.centerIn: parent

            Text {
                id: clockLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: face.clockText
                color: Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 21
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
                lineHeight: 24
                lineHeightMode: Text.FixedHeight
            }

            Text {
                id: dateLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: face.dateText
                color: Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                lineHeight: 16
                lineHeightMode: Text.FixedHeight
            }
        }
    }

    // The X turns the phone back into the launcher phone.
    SettingRoundButton {
        id: closeButton
        x: face.width - face.safeRight - width
        y: 33
        size: 58
        icon: "close"
        onClicked: face.closeRequested()
    }

    // Back to the gallery, while a picture is open.
    SekaiNavKey {
        x: clockChip.x - 24 - width
        y: 38
        icon: "arrow_back"
        label: "Gallery"
        opacity: face.viewP
        visible: opacity > 0.01
        enabled: face.viewing
        onClicked: face.closeViewer()
    }

    // ===== the gallery =====
    WheelScroll { scroller: grid }
    GridView {
        id: grid

        x: face.pageX
        y: face.galleryTop
        width: face.pageWidth
        height: face.galleryHeight
        clip: true
        cellWidth: face.cellW
        cellHeight: face.cellH
        model: face.matched
        currentIndex: -1
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: false
        maximumFlickVelocity: 3200

        opacity: (1 - face.viewP) * (1 - face.carouselP)
        scale: 0.97 + 0.03 * (1 - face.viewP)
        visible: opacity > 0.01
        enabled: !face.viewing && !face.carousel

        delegate: Item {
            id: cell

            required property int index
            required property var modelData

            width: grid.cellWidth
            height: grid.cellHeight

            readonly property string path: cell.modelData.filePath
            readonly property bool applied: cell.path === face.currentPath
            readonly property bool other: face.otherPath !== "" && cell.path === face.otherPath
            readonly property bool picked: face.keyNav && GridView.isCurrentItem
            readonly property bool hot: area.containsMouse || picked
            readonly property bool video: WallpaperService.isVideo(cell.path)
            readonly property real tw: cell.width - 22
            readonly property real th: cell.height - 22

            // The side being marked wears its own colour (the lockscreen's, on its tab).
            readonly property color markColor: face.lockMode ? LockPalette.pink : Theme.accentMint
            readonly property color otherColor: face.lockMode ? Theme.accentCyan : LockPalette.pink

            // pushes into its shadow while pressed, lifts a hair when hot
            readonly property real push: area.pressed ? 5 : (cell.hot ? -2 : 0)

            Rectangle {
                x: 9
                y: 9
                width: cell.tw
                height: cell.th
                radius: 16
                color: Theme.pLineShadow
            }

            Rectangle {
                id: body

                x: 4 + cell.push
                y: 4 + cell.push
                width: cell.tw
                height: cell.th
                radius: 16
                color: Theme.pSurface
                border.width: 4
                border.color: cell.hot ? Theme.accentCyan : Theme.pLine

                Behavior on x {
                    NumberAnimation {
                        duration: area.pressed ? 70 : 220
                        easing.type: area.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 2.0
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: area.pressed ? 70 : 220
                        easing.type: area.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 2.0
                    }
                }

                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 12
                    color: Theme.pSurfaceHover

                    Image {
                        id: thumb

                        anchors.fill: parent
                        source: WallpaperService.thumbUrl(cell.path)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        // Decoded as dense as the screen it lands in (the phone's
                        // screen layer is renderScale x 2 texels per design unit);
                        // a fixed 520 was too few once the picture is cropped to
                        // the cell and the phone is shown at full size or bigger.
                        sourceSize.width: Math.ceil(Math.max(cell.tw, cell.th * 1.8) * face.renderScale * 2)
                        opacity: status === Image.Ready ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 180 }
                        }
                    }

                    // a video with no thumbnail yet
                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: thumb.status !== Image.Ready
                        size: 40
                        name: cell.video ? "movie" : "image"
                        color: Theme.pInkSub
                    }

                    // a video wears a play badge
                    Rectangle {
                        visible: cell.video
                        x: parent.width - width - 10
                        y: parent.height - height - 10
                        width: 30
                        height: 30
                        radius: 15
                        color: Theme.pSurface
                        border.width: 3
                        border.color: Theme.pLine

                        MaterialIcon {
                            anchors.centerIn: parent
                            size: 18
                            name: "play_arrow"
                            color: Theme.colBorder
                        }
                    }
                }

                // the applied picture (of the side being marked): a ring ...
                Rectangle {
                    visible: cell.applied
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 12
                    color: "transparent"
                    border.width: 5
                    border.color: cell.markColor
                }

                // ... and a check
                Rectangle {
                    visible: cell.applied
                    x: parent.width - width - 8
                    y: 8
                    width: 34
                    height: 34
                    radius: 17
                    color: cell.markColor
                    border.width: 3
                    border.color: Theme.colBorder

                    MaterialIcon {
                        anchors.centerIn: parent
                        size: 20
                        name: "check"
                        weight: 700
                        color: Theme.colBorder
                    }
                }

                // also what the other side shows
                Rectangle {
                    visible: cell.other
                    x: 8
                    y: 8
                    width: 34
                    height: 34
                    radius: 17
                    color: cell.otherColor
                    border.width: 3
                    border.color: Theme.colBorder

                    MaterialIcon {
                        anchors.centerIn: parent
                        size: 19
                        name: face.lockMode ? "desktop_windows" : "lock"
                        color: Theme.colBorder
                    }
                }

                // the name, while hot
                Rectangle {
                    x: 10
                    y: parent.height - height - 10
                    width: Math.min(parent.width - 20 - (cell.video ? 40 : 0), nameText.implicitWidth + 22)
                    height: 28
                    radius: 14
                    color: Theme.pSurface
                    border.width: 3
                    border.color: Theme.pLine
                    opacity: cell.hot ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }

                    Text {
                        id: nameText
                        anchors.centerIn: parent
                        width: parent.width - 18
                        horizontalAlignment: Text.AlignHCenter
                        text: face.baseName(cell.modelData.fileName)
                        elide: Text.ElideMiddle
                        color: Theme.pInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }
            }

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: face.keyNav = false
                onClicked: face.showIndex(cell.index)
            }
        }
    }

    // scroll position
    Rectangle {
        visible: face.viewP < 0.5 && !face.carousel && grid.contentHeight > grid.height + 1
        x: grid.x + grid.width - 8
        y: grid.y + grid.visibleArea.yPosition * grid.height
        width: 6
        height: Math.max(40, grid.visibleArea.heightRatio * grid.height)
        radius: 3
        color: Theme.pSurfaceRing
        opacity: 1 - face.viewP
    }

    // ===== the wheel =====
    WallpaperWheel {
        id: wheelView

        x: face.pageX
        y: face.galleryTop
        width: face.pageWidth
        height: face.galleryHeight
        items: face.matched
        currentPath: face.currentPath
        otherPath: face.otherPath
        desktopPath: face.desktopPath
        lockPath: face.lockPath
        lockMode: face.lockMode
        justSet: face.justSet
        renderScale: face.renderScale
        active: face.carousel && !face.viewing

        opacity: face.carouselP * (1 - face.viewP)
        scale: 0.97 + 0.03 * (1 - face.viewP)
        visible: opacity > 0.01
        enabled: face.carousel && !face.viewing

        onOpened: index => face.showIndex(index)
        onSetDesktopRequested: (path, all) => face.setDesktop(all, path)
        onSetLockRequested: (path, all) => face.setLock(all, path)
    }

    // an empty folder, or nothing matches the search
    Column {
        x: face.pageX + (face.pageWidth - width) / 2
        y: face.galleryTop + (face.galleryHeight - height) / 2
        visible: face.listed && face.matched.length === 0 && face.viewP < 0.5
        spacing: 8

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            size: 54
            name: face.items.length === 0 ? "photo_library" : "search_off"
            color: Theme.pInkSub
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, Math.max(120, face.pageWidth - 120))
            elide: Text.ElideMiddle
            text: face.items.length === 0 ? "No wallpapers yet" : "No wallpapers match \u201c" + face.searchText + "\u201d"
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 26
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: face.items.length === 0
            width: Math.min(implicitWidth, Math.max(120, face.pageWidth - 120))
            elide: Text.ElideMiddle
            text: "Put pictures or videos in " + WallpaperService.directoryShort + ", or choose another folder"
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }
    }

    // ===== the toolbar =====
    // The wallpaper board's header, laid along the top of the gallery.
    Item {
        id: toolbar

        x: face.pageX
        y: face.pageTop
        width: face.pageWidth
        height: face.toolbarH
        z: 5
        opacity: 1 - face.viewP
        visible: opacity > 0.01
        enabled: !face.viewing

        // Desktop | Lockscreen (Separate Lockscreen Wallpaper on)
        WallpaperTargetSwitch {
            id: targetSwitch

            visible: WallpaperService.separateLock
            x: 2
            y: 2
            current: face.target
            onPicked: id => {
                face.sortOpen = false
                face.target = id
            }
        }

        Text {
            x: (targetSwitch.visible ? targetSwitch.x + targetSwitch.width + 18 : 4)
            y: 2
            height: 40
            width: Math.max(0, controls.x - x - 14)
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: face.subtitle
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Row {
            id: controls

            anchors.right: parent.right
            anchors.rightMargin: 8
            y: 2
            spacing: 12

            SearchPill {
                id: search

                placeholder: "Search wallpapers"
                onTextChanged: face.searchText = text
                onLeave: face.forceActiveFocus()
            }

            SortChip {
                id: sortChip

                label: face.sortShort
                active: face.sortOpen
                onClicked: face.sortOpen = !face.sortOpen
            }

            // Which folder the wallpapers come from. Lit while it is not the
            // default one. The phone steps aside while the chooser is open and comes
            // back on this same side (WallpaperService.pickFolder).
            MagnetButton {
                icon: "folder_open"
                label: "Wallpaper folder"
                active: WallpaperService.customFolder
                onClicked: {
                    face.sortOpen = false
                    WallpaperService.pickFolder(face.lockMode ? "lock" : "desktop")
                }
            }

            MagnetButton {
                icon: "my_location"
                label: "Jump to applied"
                onClicked: face.jumpToApplied()
            }

            MagnetButton {
                icon: "shuffle"
                label: "Shuffle"
                onClicked: face.shuffle()
            }

            MagnetButton {
                icon: "refresh"
                label: "Refresh"
                badge: face.hasNew
                onClicked: {
                    face.sortOpen = false
                    face.refresh()
                }
            }

            // wheel <-> grid
            MagnetButton {
                icon: face.carousel ? "grid_view" : "view_carousel"
                label: face.carousel ? "Grid" : "Wheel"
                onClicked: face.toggleLook()
            }
        }

        // The sort menu: click anywhere else on the screen to close it.
        GallerySortCard {
            x: controls.x + sortChip.x + sortChip.width - width
            y: face.toolbarH + 6
            shown: face.sortOpen
            sortMode: face.sortMode
            options: face.sortOptions
            onSelected: mode => {
                face.setSort(mode)
                face.sortOpen = false
            }
        }
    }

    // Catches the click that closes the sort menu.
    MouseArea {
        anchors.fill: parent
        z: 4
        enabled: face.sortOpen
        onClicked: face.sortOpen = false
    }

    // ===== the viewer =====
    Item {
        id: viewerArea

        x: face.pageX
        y: face.pageTop
        width: face.pageWidth
        height: face.pageHeight
        opacity: face.viewP
        scale: 0.96 + 0.04 * face.viewP
        visible: opacity > 0.01
        enabled: face.viewing

        readonly property real cardW: 830
        readonly property real cardH: Math.round(cardW / 1.6)
        readonly property real panelX: cardW + 42
        readonly property real panelW: width - panelX - 6

        // the picture
        Rectangle {
            x: 9
            y: 15
            width: viewerArea.cardW
            height: viewerArea.cardH
            radius: 24
            color: Theme.pLineShadow
        }

        Rectangle {
            x: 0
            y: 6
            width: viewerArea.cardW
            height: viewerArea.cardH
            radius: 24
            color: Theme.pSurface
            border.width: 5
            border.color: Theme.pLine

            ClippingRectangle {
                anchors.fill: parent
                anchors.margins: 5
                radius: 19
                color: Theme.pSurfaceHover

                Image {
                    id: bigPicture

                    anchors.fill: parent
                    source: face.viewPath === "" ? ""
                            : (face.viewIsVideo ? WallpaperService.thumbUrl(face.viewPath) : "file://" + face.viewPath)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    // As dense as the screen it lands in (was a fixed 1680 x 1050,
                    // which is short of it above about 100% scale).
                    sourceSize: Qt.size(Math.min(3840, Math.ceil(viewerArea.cardW * face.renderScale * 2)),
                                        Math.min(2400, Math.ceil(viewerArea.cardH * face.renderScale * 2)))
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: bigPicture.status !== Image.Ready
                    size: 64
                    name: face.viewIsVideo ? "movie" : "image"
                    color: Theme.pInkSub
                }
            }
        }

        // the name and what it is
        Column {
            x: viewerArea.panelX
            y: 6
            width: viewerArea.panelW
            spacing: 8

            Text {
                width: parent.width
                text: face.viewName
                color: Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 28
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                text: face.viewIsVideo ? "Video wallpaper" : "Picture"
                color: Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            Row {
                spacing: 10

                Rectangle {
                    visible: face.viewPath !== "" && face.viewPath === face.desktopPath
                    width: onDesk.implicitWidth + 28
                    height: 32
                    radius: 16
                    color: Theme.accentMint
                    border.width: 3
                    border.color: Theme.colBorder

                    Text {
                        id: onDesk
                        anchors.centerIn: parent
                        text: "On your desktop"
                        color: Theme.colBorder
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                }

                Rectangle {
                    visible: face.viewPath !== "" && face.viewPath === face.lockPath
                    width: onLock.implicitWidth + 28
                    height: 32
                    radius: 16
                    color: LockPalette.pink
                    border.width: 3
                    border.color: Theme.colBorder

                    Text {
                        id: onLock
                        anchors.centerIn: parent
                        text: "On your lockscreen"
                        color: Theme.colBorder
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                }
            }
        }

        // the two actions
        WallpaperActionKey {
            x: viewerArea.panelX
            y: 214
            capW: viewerArea.panelW - 8
            icon: "desktop_windows"
            label: "Set as Desktop"
            done: face.justSet === "desktop"
            onClicked: all => face.setDesktop(all)
        }

        WallpaperActionKey {
            x: viewerArea.panelX
            y: 312
            capW: viewerArea.panelW - 8
            icon: "lock"
            label: "Set as Lockscreen"
            done: face.justSet === "lock"
            onClicked: all => face.setLock(all)
        }

        Text {
            x: viewerArea.panelX
            y: 410
            width: viewerArea.panelW
            wrapMode: Text.WordWrap
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
            text: {
                const lines = []
                if (WallpaperService.perMonitor && face.screenName !== "")
                    lines.push("Changes this monitor (" + face.screenName + ") only. Shift+click: every monitor.")
                if (!WallpaperService.separateLock)
                    lines.push("Set as Lockscreen turns on a separate lockscreen wallpaper.")
                return lines.join("\n")
            }
        }

        // previous / next (through what the search and sort show)
        Row {
            x: viewerArea.panelX
            y: viewerArea.cardH - 40
            spacing: 14

            SekaiNavKey {
                icon: "chevron_left"
                label: "Previous"
                onClicked: face.showIndex(face.viewIndex - 1)
            }

            SekaiNavKey {
                icon: "chevron_right"
                label: "Next"
                onClicked: face.showIndex(face.viewIndex + 1)
            }
        }
    }
}
