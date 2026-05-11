import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Controls 6.10
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../Commons" as Commons
import "../../Widgets" as Widgets
import "../../Services" as Services
import "." as Wallpaper

Widgets.PopupWindow {
    id: popupWindow

    ipcTarget: "wallpaper"
    Component.onCompleted: {
        if (Services.ConfigService.initialized)
            Services.WallpaperService.refresh()
    }
    initialScale: 0.94
    transformOriginX: 0.5
    transformOriginY: 0.5
    closeOnClickOutside: false

    anchors {
        top: true
        left: true
    }

    margins {
        top: Quickshell.screens[0] ? (Quickshell.screens[0].height - implicitHeight) / 2 : 100
        left: Quickshell.screens[0] ? (Quickshell.screens[0].width - implicitWidth) / 2 : 100
    }

    property var previewOverlay: null

    property int currentTab: 0  // 0 = Local, 1 = Wallhaven, 2 = Settings
    property string wallhavenSorting: "date_added"
    property string wallhavenTopRange: "1M"
    property int wallhavenPage: 1
    property string wallhavenQuery: ""

    implicitWidth: 600
    implicitHeight: 540

    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        color: Commons.Theme.background
        radius: Commons.Theme.radiusPanel
        border.color: Wallpaper.WallpaperColors.border
        border.width: 1

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.35)
            shadowBlur: 1.0
            shadowVerticalOffset: 6
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header
            Widgets.HeaderWithIcon {
                Layout.fillWidth: true
                icon: "\uf03e"
                title: "Wallpaper Selector"
                subtitle: getSubtitleText()
                iconColor: Wallpaper.WallpaperColors.primary
                titleColor: Wallpaper.WallpaperColors.text
                subtitleColor: Wallpaper.WallpaperColors.subText
            }

            // Tab buttons
            Row {
                Layout.fillWidth: true
                spacing: 4
                
                Widgets.TabButton {
                    text: "Local"
                    active: currentTab === 0
                    onClicked: currentTab = 0
                }
                
                Widgets.TabButton {
                    text: "Wallhaven"
                    active: currentTab === 1
                    onClicked: {
                        currentTab = 1
                        if (Services.WallhavenAPIService.wallhavenList.count === 0 && !Services.WallhavenAPIService.running)
                            refreshWallhaven()
                    }
                }
                
                Widgets.TabButton {
                    text: "Settings"
                    active: currentTab === 2
                    onClicked: currentTab = 2
                }
            }

            // Tab content
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: currentTab

                // Local tab
                Wallpaper.LocalWallpaperTab {
                    onWallpaperSelected: function(filePath) {
                        Services.WallpaperService.setWallpaper(filePath)
                    }
                    onCopyRequested: function(filePath) {
                        copyToClipboard(filePath)
                    }
                    onOpenRequested: function(filePath) {
                        openFile(filePath)
                    }
                    onDeleteRequested: function(filePath, fileName) {
                        deleteFile(filePath, fileName)
                    }
                    onPreviewRequested: function(imageSource, tooltipText, filePath, fileName, isFromDownloaded) {
                        showPreview(imageSource, tooltipText, filePath, fileName, isFromDownloaded, "", "")
                    }
                    onSaveToSavedRequested: function(filePath) {
                        Services.WallpaperService.copyToSaved(filePath)
                    }
                }

                // Wallhaven tab
                Wallpaper.WallhavenTab {
                    sorting: wallhavenSorting
                    topRange: wallhavenTopRange
                    currentPage: wallhavenPage
                    searchQuery: wallhavenQuery
                    
                    onSortingRequested: function(newSorting) {
                        wallhavenSorting = newSorting
                        wallhavenPage = 1
                        refreshWallhaven()
                    }
                    onTopRangeRequested: function(newRange) {
                        wallhavenTopRange = newRange
                        wallhavenPage = 1
                        refreshWallhaven()
                    }
                    onPageRequested: function(newPage) {
                        wallhavenPage = newPage
                        refreshWallhaven()
                    }
                    onRefreshRequested: refreshWallhaven
                    onWallpaperSelected: function(id, fullUrl) {
                        Services.WallhavenAPIService.downloadAndSet(id, fullUrl)
                    }
                    onSearchRequested: function(query) {
                        wallhavenQuery = query
                        wallhavenPage = 1
                        refreshWallhaven()
                    }
                    onPreviewRequested: function(imageSource, tooltipText, wallhavenId, wallhavenFullUrl) {
                        showPreview(imageSource, tooltipText, "", "", false, wallhavenId, wallhavenFullUrl)
                    }
                    onSaveToSavedRequested: function(id, fullUrl) {
                        Services.WallhavenAPIService.downloadToSaved(id, fullUrl)
                    }
                }

                // Settings tab
                Wallpaper.SettingsTab {
                    onDirectoryChanged: function(newDirectory) {
                        saveDirectory(newDirectory)
                    }
                    onDownloadDirectoryChanged: function(newDirectory) {
                        saveDownloadDirectory(newDirectory)
                    }
                    onDirectoryDialogRequested: {
                        console.log("[WallpaperSelector] Directory dialog requested")
                        openDirectoryDialog()
                    }
                    onDownloadDirectoryDialogRequested: {
                        openDownloadDirectoryDialog()
                    }
                    onResizeModeChanged: function(mode) {
                        Services.ConfigService.setWallpaperResizeMode(mode)
                    }
                }
            }
        }

        Connections {
            target: previewOverlay
            enabled: !!previewOverlay
            function onSetRequested() {
                if (!previewOverlay) return
                var o = previewOverlay
                if (o.filePath.length > 0) {
                    Services.WallpaperService.setWallpaper(o.filePath)
                } else if (o.wallhavenId.length > 0 && o.wallhavenFullUrl.length > 0) {
                    Services.WallhavenAPIService.downloadAndSet(o.wallhavenId, o.wallhavenFullUrl)
                }
            }
            function onSaveRequested() {
                if (!previewOverlay) return
                var o = previewOverlay
                if (o.filePath.length > 0) {
                    Services.WallpaperService.copyToSaved(o.filePath)
                } else if (o.wallhavenId.length > 0 && o.wallhavenFullUrl.length > 0) {
                    Services.WallhavenAPIService.downloadToSaved(o.wallhavenId, o.wallhavenFullUrl)
                }
            }
            function onDeleteRequested() {
                if (!previewOverlay) return
                var o = previewOverlay
                if (o.filePath.length > 0) {
                    deleteFile(o.filePath, o.fileName)
                }
            }
        }

        // Service connections
        Connections {
            target: Services.ConfigService
            function onWallpaperDirectoryChanged() {
                Services.WallpaperService.refreshSaved()
            }
            function onWallpaperDownloadDirectoryChanged() {
                Services.WallpaperService.refreshDownloaded()
            }
            function onInitializedChanged() {
                if (Services.ConfigService.initialized) {
                    Services.WallpaperService.refresh()
                }
            }
        }
    }

    // Helper functions
    function getSubtitleText() {
        if (currentTab === 0) {
            var savedCount = Services.WallpaperService.savedList.count
            var downloadedCount = Services.WallpaperService.downloadedList.count
            if (Services.WallpaperService.savedLoading || Services.WallpaperService.downloadedLoading)
                return "Loading..."
            return savedCount + " saved, " + downloadedCount + " downloaded"
        } else if (currentTab === 1) {
            return Services.WallhavenAPIService.running 
                ? "Loading..." 
                : "Page " + wallhavenPage + " of " + Services.WallhavenAPIService.lastPage
        } else {
            return "Directory and resize mode"
        }
    }

    function saveDirectory(newDir) {
        var trimmedDir = newDir.trim()
        if (trimmedDir.length > 0) {
            Services.ConfigService.setWallpaperDirectory(trimmedDir)
            Services.WallpaperService.refreshSaved()
        }
    }

    function saveDownloadDirectory(newDir) {
        var trimmedDir = newDir.trim()
        if (trimmedDir.length > 0) {
            Services.ConfigService.setWallpaperDownloadDirectory(trimmedDir)
            Services.WallpaperService.refreshDownloaded()
        }
    }

        function openDirectoryDialog() {
        console.log("[WallpaperSelector] openDirectoryDialog called")
        popupWindow.shouldShow = false
        Services.WallpaperService.popupWindow = popupWindow
        Services.WallpaperService.openDirectoryDialog(0)
    }

    function openDownloadDirectoryDialog() {
        popupWindow.shouldShow = false
        Services.WallpaperService.popupWindow = popupWindow
        Services.WallpaperService.openDirectoryDialog(1)
    }

    function copyToClipboard(text) {
        Services.WallpaperService.copyToClipboard(text)
    }

    function openFile(path) {
        Services.WallpaperService.openFile(path)
    }

    function deleteFile(path, name) {
        popupWindow.shouldShow = false
        Services.WallpaperService.popupWindow = popupWindow
        Services.WallpaperService.deleteFile(path, name)
    }

    function refreshWallhaven() {
        Services.WallhavenAPIService.refresh(wallhavenSorting, wallhavenPage, wallhavenTopRange, Services.WallhavenAPIService.seed, wallhavenQuery)
    }

    function showPreview(imageSource, tooltipText, filePath, fileName, isFromDownloaded, wallhavenId, wallhavenFullUrl) {
        if (previewOverlay) {
            previewOverlay.imageSource = imageSource || ""
            previewOverlay.tooltipText = tooltipText || ""
            previewOverlay.filePath = filePath || ""
            previewOverlay.fileName = fileName || ""
            previewOverlay.isFromDownloaded = isFromDownloaded || false
            previewOverlay.wallhavenId = wallhavenId || ""
            previewOverlay.wallhavenFullUrl = wallhavenFullUrl || ""
            previewOverlay.shouldShow = true
        }
    }
}