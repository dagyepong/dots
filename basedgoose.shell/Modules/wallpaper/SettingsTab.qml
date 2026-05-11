import QtQuick 6.10
import QtQuick.Layouts 6.10
import "../../Widgets" as Widgets
import "../../Services" as Services
import "../../Commons" as Commons
import "." as Wallpaper

ColumnLayout {
    id: root
    
    property alias directoryText: directoryInput.text
    
    signal directoryChanged(string newDirectory)
    signal directoryDialogRequested()
    signal downloadDirectoryChanged(string newDirectory)
    signal downloadDirectoryDialogRequested()
    signal resizeModeChanged(string mode)
    
    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 12
    
    // Directory setting
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: Commons.Theme.radius
        color: Wallpaper.WallpaperColors.surfaceContainer
        
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8
            
            Text {
                text: "Saved:"
                font.family: Commons.Theme.fontUI
                font.pixelSize: 12
                color: Wallpaper.WallpaperColors.text
            }
            
            TextInput {
                id: directoryInput
                Layout.fillWidth: true
                text: Services.ConfigService.wallpaperDirectory
                font.family: Commons.Theme.fontUI
                font.pixelSize: 11
                color: Wallpaper.WallpaperColors.text
                selectByMouse: true
                
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: Commons.Theme.radiusSm
                    color: directoryInput.activeFocus ? Qt.rgba(Wallpaper.WallpaperColors.primary.r, Wallpaper.WallpaperColors.primary.g, Wallpaper.WallpaperColors.primary.b, 0.1) : "transparent"
                    border.width: directoryInput.activeFocus ? 1 : 0
                    border.color: Wallpaper.WallpaperColors.primary
                    z: -1
                }
                
                Keys.onReturnPressed: root.directoryChanged(text)
                Keys.onEscapePressed: {
                    text = Services.ConfigService.wallpaperDirectory
                    focus = false
                }
                
                Connections {
                    target: Services.ConfigService
                    function onWallpaperDirectoryChanged() {
                        directoryInput.text = Services.ConfigService.wallpaperDirectory
                    }
                }
            }
            
            Widgets.IconButton {
                width: 32
                height: 32
                Layout.alignment: Qt.AlignVCenter
                icon: "\uf4d3"
                iconSize: 14
                iconColor: Wallpaper.WallpaperColors.subText
                hoverIconColor: Wallpaper.WallpaperColors.primary
                baseColor: "transparent"
                hoverColor: Qt.rgba(Wallpaper.WallpaperColors.primary.r, Wallpaper.WallpaperColors.primary.g, Wallpaper.WallpaperColors.primary.b, 0.15)
                onClicked: {
                    console.log("[SettingsTab] Directory button clicked")
                    root.directoryDialogRequested()
                }
            }
            
            Widgets.IconButton {
                width: 32
                height: 32
                visible: directoryInput.text !== Services.ConfigService.wallpaperDirectory
                icon: "󰄬"
                iconSize: 14
                iconColor: Wallpaper.WallpaperColors.primary
                hoverIconColor: Wallpaper.WallpaperColors.primary
                baseColor: "transparent"
                hoverColor: Qt.rgba(Wallpaper.WallpaperColors.primary.r, Wallpaper.WallpaperColors.primary.g, Wallpaper.WallpaperColors.primary.b, 0.15)
                onClicked: root.directoryChanged(directoryInput.text)
            }
        }
    }

    // Download directory setting
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: Commons.Theme.radius
        color: Wallpaper.WallpaperColors.surfaceContainer

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            Text {
                text: "Download:"
                font.family: Commons.Theme.fontUI
                font.pixelSize: 12
                color: Wallpaper.WallpaperColors.text
            }

            TextInput {
                id: downloadDirInput
                Layout.fillWidth: true
                text: Services.ConfigService.wallpaperDownloadDirectory
                font.family: Commons.Theme.fontUI
                font.pixelSize: 11
                color: Wallpaper.WallpaperColors.text
                selectByMouse: true

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: Commons.Theme.radiusSm
                    color: downloadDirInput.activeFocus ? Qt.rgba(Wallpaper.WallpaperColors.primary.r, Wallpaper.WallpaperColors.primary.g, Wallpaper.WallpaperColors.primary.b, 0.1) : "transparent"
                    border.width: downloadDirInput.activeFocus ? 1 : 0
                    border.color: Wallpaper.WallpaperColors.primary
                    z: -1
                }

                Keys.onReturnPressed: root.downloadDirectoryChanged(text)
                Keys.onEscapePressed: {
                    text = Services.ConfigService.wallpaperDownloadDirectory
                    focus = false
                }

                Connections {
                    target: Services.ConfigService
                    function onWallpaperDownloadDirectoryChanged() {
                        downloadDirInput.text = Services.ConfigService.wallpaperDownloadDirectory
                    }
                }
            }

            Widgets.IconButton {
                width: 32
                height: 32
                Layout.alignment: Qt.AlignVCenter
                icon: "\uf4d3"
                iconSize: 14
                iconColor: Wallpaper.WallpaperColors.subText
                hoverIconColor: Wallpaper.WallpaperColors.primary
                baseColor: "transparent"
                hoverColor: Qt.rgba(Wallpaper.WallpaperColors.primary.r, Wallpaper.WallpaperColors.primary.g, Wallpaper.WallpaperColors.primary.b, 0.15)
                onClicked: root.downloadDirectoryDialogRequested()
            }

            Widgets.IconButton {
                width: 32
                height: 32
                visible: downloadDirInput.text !== Services.ConfigService.wallpaperDownloadDirectory
                icon: "󰄬"
                iconSize: 14
                iconColor: Wallpaper.WallpaperColors.primary
                hoverIconColor: Wallpaper.WallpaperColors.primary
                baseColor: "transparent"
                hoverColor: Qt.rgba(Wallpaper.WallpaperColors.primary.r, Wallpaper.WallpaperColors.primary.g, Wallpaper.WallpaperColors.primary.b, 0.15)
                onClicked: root.downloadDirectoryChanged(downloadDirInput.text)
            }
        }
    }
    
    // Resize mode setting
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        spacing: 6
        
        Text {
            text: "Resize:"
            font.family: Commons.Theme.fontUI
            font.pixelSize: 12
            color: Wallpaper.WallpaperColors.text
            Layout.alignment: Qt.AlignVCenter
        }
        
        Repeater {
            model: [
                { key: "no", label: "No" },
                { key: "crop", label: "Crop" },
                { key: "fit", label: "Fit" },
                { key: "stretch", label: "Stretch" }
            ]
            
            Widgets.FilterButton {
                Layout.preferredWidth: 64
                Layout.preferredHeight: 28
                text: modelData.label
                value: modelData.key
                currentValue: Services.ConfigService.wallpaperResizeMode
                onClicked: function(value) {
                    root.resizeModeChanged(value)
                }
            }
        }
    }
    
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        Layout.topMargin: 8
        radius: Commons.Theme.radius
        color: Wallpaper.WallpaperColors.surfaceContainer
        
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12
            
            Text {
                text: "Image Cache:"
                font.family: Commons.Theme.fontUI
                font.pixelSize: 12
                color: Wallpaper.WallpaperColors.text
                Layout.alignment: Qt.AlignVCenter
            }
            
            Item {
                Layout.fillWidth: true
            }
            
            Widgets.TextButton {
                Layout.preferredHeight: 28
                text: clearingCache ? "Clearing..." : "Clear Cache"
                textColor: Commons.Theme.foreground
                enabled: !clearingCache
                onClicked: {
                    clearingCache = true
                    Services.ImageCacheService.clearCache(function(success) {
                        clearingCache = false
                    })
                }
            }
        }
    }
    
    property bool clearingCache: false
    
    Item {
        Layout.fillHeight: true
    }
}