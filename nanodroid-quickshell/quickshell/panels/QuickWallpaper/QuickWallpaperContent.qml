import "../../core"
import "../../services"
import "../../widgets"
import "../../core/functions" as Functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property real screenWidth: 1200
    property real screenHeight: 800
    property real openProgress: 0
    property string localSearch: ""
    property bool liveMode: false
    property int selectedIndex: 0
    property real wheelAccumulator: 0
    readonly property real u: Appearance.effectiveScale

    signal closed()

    width: Math.min(1260 * u, screenWidth * 0.92)
    height: Math.min(680 * u, screenHeight * 0.78)
    focus: true
    scale: 0.965 + (0.035 * openProgress)
    opacity: openProgress

    Component.onCompleted: {
        forceActiveFocus()
        enterAnimation.restart()
        WallpaperEngineService.fetch()
    }

    Keys.onEscapePressed: close()
    Keys.onLeftPressed: moveSelection(-1)
    Keys.onRightPressed: moveSelection(1)
    Keys.onUpPressed: moveSelection(-1)
    Keys.onDownPressed: moveSelection(1)
    Keys.onReturnPressed: activateCurrent()
    Keys.onEnterPressed: activateCurrent()

    NumberAnimation {
        id: enterAnimation
        target: root
        property: "openProgress"
        from: 0
        to: 1
        duration: 180
        easing.type: Easing.OutCubic
    }

    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    function cleanPath(path) {
        let value = path ? path.toString() : ""
        if (value.startsWith("file://")) value = value.substring(7)
        return value
    }

    function close() {
        Wallpapers.searchQuery = ""
        WallpaperEngineService.searchQuery = ""
        localSearch = ""
        closed()
    }

    function itemCount() {
        return carousel.count || 0
    }

    function moveSelection(delta) {
        if (itemCount() <= 0) return
        const next = Math.max(0, Math.min(itemCount() - 1, carousel.currentIndex + delta))
        carousel.currentIndex = next
        selectedIndex = next
        carousel.positionViewAtIndex(next, ListView.Center)
    }

    function activateCurrent() {
        if (carousel.currentItem && carousel.currentItem.activated) carousel.currentItem.activated()
    }

    function applyWallpaper(path) {
        const wallpaperPath = cleanPath(path)
        if (wallpaperPath === "") return
        WallpaperEngineService.stop()
        Wallpapers.select("file://" + wallpaperPath)
        close()
    }

    function applyLiveWallpaper(path, preview) {
        const wallpaperPath = cleanPath(path)
        if (wallpaperPath === "") return
        WallpaperEngineService.apply(wallpaperPath, preview || "")
        close()
    }

    onLiveModeChanged: {
        selectedIndex = 0
        wheelAccumulator = 0
        localSearch = ""
        Wallpapers.searchQuery = ""
        WallpaperEngineService.searchQuery = ""
        if (liveMode) {
            WallpaperEngineService.refreshInstallState()
            WallpaperEngineService.fetch()
        }
        Qt.callLater(() => {
            carousel.currentIndex = 0
            if (carousel.count > 0) carousel.positionViewAtIndex(0, ListView.Center)
        })
    }

    Connections {
        target: GlobalStates
        function onQuickWallpaperOpenChanged() {
            if (GlobalStates.quickWallpaperOpen) {
                root.forceActiveFocus()
                if (root.liveMode) {
                    WallpaperEngineService.refreshInstallState()
                    WallpaperEngineService.fetch()
                }
                Qt.callLater(() => {
                    if (carousel.count > 0) carousel.positionViewAtIndex(carousel.currentIndex, ListView.Center)
                })
            }
        }
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        radius: 26 * u
        color: Functions.ColorUtils.applyAlpha(Appearance.colors.colLayer0, 0.72)
        border.width: Math.max(1, 1 * u)
        border.color: Functions.ColorUtils.applyAlpha(Appearance.colors.colOutlineVariant, 0.32)
        clip: true

        TapHandler {}

        Image {
            anchors.fill: parent
            source: {
                const path = Wallpapers.getWallpaperPath("desktop")
                return path ? (path.toString().startsWith("file://") ? path : "file://" + path) : ""
            }
            fillMode: Image.PreserveAspectCrop
            opacity: 0.20
            asynchronous: true
            cache: false
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Functions.ColorUtils.applyAlpha(Appearance.colors.colLayer0, 0.56) }
                GradientStop { position: 0.48; color: Functions.ColorUtils.applyAlpha(Appearance.colors.colLayer0, 0.34) }
                GradientStop { position: 1.0; color: Functions.ColorUtils.applyAlpha(Appearance.colors.colLayer0, 0.72) }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14 * u
            spacing: 10 * u

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 50 * u
                spacing: 12 * u

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44 * u
                    radius: 22 * u
                    color: Functions.ColorUtils.applyAlpha(Appearance.colors.colLayer1, 0.86)
                    border.width: Math.max(1, 1 * u)
                    border.color: searchField.activeFocus ? Appearance.colors.colPrimary : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16 * u
                        anchors.rightMargin: 12 * u
                        spacing: 10 * u

                        MaterialSymbol {
                            text: "search"
                            iconSize: 22 * u
                            color: searchField.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        }

                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: root.localSearch
                            placeholderText: root.liveMode ? "Search live videos" : "Search wallpapers"
                            color: Appearance.colors.colOnLayer1
                            placeholderTextColor: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.normal
                            selectByMouse: true
                            background: Item {}
                            onTextChanged: {
                                root.localSearch = text
                                if (root.liveMode) WallpaperEngineService.searchQuery = text
                                else Wallpapers.searchQuery = text
                                Qt.callLater(() => {
                                    carousel.currentIndex = 0
                                    root.selectedIndex = 0
                                    if (carousel.count > 0) carousel.positionViewAtIndex(0, ListView.Center)
                                })
                            }
                        }

                        MaterialSymbol {
                            visible: searchField.text !== ""
                            text: "close"
                            iconSize: 18 * u
                            color: Appearance.colors.colSubtext
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8 * u
                                cursorShape: Qt.PointingHandCursor
                                onClicked: searchField.text = ""
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 192 * u
                    Layout.preferredHeight: 44 * u
                    radius: 22 * u
                    color: Functions.ColorUtils.applyAlpha(Appearance.colors.colLayer1, 0.86)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4 * u
                        spacing: 4 * u

                        RippleButton {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            buttonRadius: 18 * u
                            toggled: !root.liveMode
                            buttonText: "Pictures"
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            colBackgroundToggled: Appearance.colors.colPrimary
                            colTextToggled: Appearance.colors.colOnPrimary
                            onClicked: root.liveMode = false
                        }

                        RippleButton {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            buttonRadius: 18 * u
                            toggled: root.liveMode
                            buttonText: "Live"
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            colBackgroundToggled: Appearance.colors.colPrimary
                            colTextToggled: Appearance.colors.colOnPrimary
                            onClicked: root.liveMode = true
                        }
                    }
                }

                RippleButton {
                    Layout.preferredWidth: 44 * u
                    Layout.preferredHeight: 44 * u
                    buttonRadius: 22 * u
                    visible: !root.liveMode
                    colBackground: Functions.ColorUtils.applyAlpha(Appearance.colors.colLayer1, 0.86)
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    onClicked: {
                        WallpaperEngineService.stop()
                        Wallpapers.selectRandomFromDirectory(Wallpapers.directory)
                        root.close()
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "shuffle"
                        iconSize: 22 * u
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledToolTip { text: "Random wallpaper" }
                }

                RippleButton {
                    Layout.preferredWidth: 44 * u
                    Layout.preferredHeight: 44 * u
                    buttonRadius: 22 * u
                    colBackground: Functions.ColorUtils.applyAlpha(Appearance.colors.colLayer1, 0.86)
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    onClicked: root.close()

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: 22 * u
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            Item {
                id: stage
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: false

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : (event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.x)
                        if (delta === 0) return
                        root.wheelAccumulator += delta
                        const threshold = 110
                        while (Math.abs(root.wheelAccumulator) >= threshold) {
                            root.moveSelection(root.wheelAccumulator > 0 ? -1 : 1)
                            root.wheelAccumulator += root.wheelAccumulator > 0 ? -threshold : threshold
                        }
                        event.accepted = true
                    }
                }

                ListView {
                    id: carousel
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 24 * u, 1100 * u)
                    height: Math.min(parent.height - 58 * u, 460 * u)
                    orientation: ListView.Horizontal
                    model: root.liveMode ? WallpaperEngineService.results : Wallpapers.folderModel
                    spacing: sliceSpacing
                    clip: false
                    cacheBuffer: Math.max(0, width * 2)
                    boundsBehavior: Flickable.DragAndOvershootBounds
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: width / 2 - expandedCardWidth / 2
                    preferredHighlightEnd: width / 2 + expandedCardWidth / 2
                    currentIndex: root.selectedIndex
                    snapMode: ListView.SnapOneItem

                    readonly property int visibleCount: Math.max(7, Math.min(10, Math.floor(width / (92 * u))))
                    readonly property real expandedCardWidth: Math.min(width * 0.56, 610 * u)
                    readonly property real sliceCardWidth: Math.max(88 * u, Math.min(130 * u, width * 0.12))
                    readonly property real sliceCardHeight: height
                    readonly property real skewOffset: 34 * u
                    readonly property real sliceSpacing: -30 * u

                    onCurrentIndexChanged: root.selectedIndex = Math.max(0, currentIndex)
                    onCountChanged: {
                        if (count <= 0) {
                            currentIndex = 0
                            root.selectedIndex = 0
                            return
                        }
                        if (currentIndex >= count) currentIndex = count - 1
                        Qt.callLater(() => positionViewAtIndex(currentIndex, ListView.Center))
                    }

                    delegate: QuickWallpaperSlice {
                        id: slice

                        readonly property int distance: Math.abs(index - carousel.currentIndex)
                        readonly property string currentFilePath: root.liveMode
                            ? ((typeof folder !== "undefined" && folder !== "") ? folder : ((typeof path !== "undefined" && path !== "") ? path : (model.folder || model.path || "")))
                            : (typeof filePath !== "undefined" ? filePath : (model.filePath || ""))
                        readonly property string currentFileName: root.liveMode
                            ? ((typeof title !== "undefined" && title !== "") ? title : ((typeof fileName !== "undefined" && fileName !== "") ? fileName : (model.title || model.fileName || "")))
                            : (typeof fileName !== "undefined" ? fileName : (model.fileName || ""))
                        readonly property string previewPath: root.liveMode
                            ? ((typeof preview !== "undefined" && preview !== "") ? preview : (model.preview || ""))
                            : (currentFilePath === "" ? "" : "file://" + currentFilePath)

                        itemIndex: index
                        current: ListView.isCurrentItem
                        selected: root.liveMode
                            ? (Config.ready && Config.options.appearance.background.liveWallpaperPath === currentFilePath)
                            : Wallpapers.getWallpaperPath("desktop") === "file://" + currentFilePath
                        title: currentFileName
                        path: currentFilePath
                        preview: previewPath
                        typeLabel: root.liveMode ? "VID" : "PIC"
                        expandedWidth: carousel.expandedCardWidth
                        sliceWidth: carousel.sliceCardWidth
                        sliceHeight: carousel.sliceCardHeight
                        skewOffset: carousel.skewOffset
                        accent: Appearance.colors.colPrimary
                        surface: Appearance.colors.colLayer1
                        dimmed: distance > Math.floor(carousel.visibleCount / 2)

                        y: current ? 0 : 22 * u + Math.min(distance, 3) * 5 * u
                        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        onSelectedRequested: {
                            carousel.currentIndex = index
                            root.selectedIndex = index
                            carousel.positionViewAtIndex(index, ListView.Center)
                        }

                        onActivated: {
                            if (root.liveMode) root.applyLiveWallpaper(currentFilePath, previewPath)
                            else root.applyWallpaper(currentFilePath)
                        }
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: Math.min(parent.width - 48 * u, 420 * u)
                    height: 36 * u
                    radius: 18 * u
                    color: Functions.ColorUtils.applyAlpha(Appearance.colors.colLayer0, 0.66)
                    border.width: Math.max(1, 1 * u)
                    border.color: Functions.ColorUtils.applyAlpha(Appearance.colors.colOutlineVariant, 0.34)

                    StyledText {
                        anchors.centerIn: parent
                        text: carousel.count > 0
                            ? ((carousel.currentIndex + 1) + " / " + carousel.count + "  " + (root.liveMode ? "local videos" : "pictures"))
                            : (root.liveMode && WallpaperEngineService.loading ? "Scanning local videos" : "No wallpapers found")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 340 * u
                    height: 92 * u
                    radius: 24 * u
                    color: Functions.ColorUtils.applyAlpha(Appearance.colors.colLayer1, 0.88)
                    visible: carousel.count === 0

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 12 * u

                        MaterialSymbol {
                            text: root.liveMode ? "movie_off" : "image_not_supported"
                            iconSize: 24 * u
                            color: Appearance.colors.colSubtext
                        }

                        StyledText {
                            text: root.liveMode && WallpaperEngineService.errorMessage !== ""
                                ? WallpaperEngineService.errorMessage
                                : (root.liveMode && WallpaperEngineService.loading
                                    ? "Scanning local videos"
                                    : (root.localSearch === "" ? "No wallpapers found" : "No search matches"))
                            color: root.liveMode && WallpaperEngineService.errorMessage !== "" ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.normal
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
