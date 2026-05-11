import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Controls 6.10
import "../../Widgets" as Widgets
import "../../Services" as Services
import "." as Wallpaper

ColumnLayout {
    id: root

    property int currentSubTab: 0  // 0 = Saved, 1 = Downloaded

    signal wallpaperSelected(string filePath)
    signal copyRequested(string filePath)
    signal openRequested(string filePath)
    signal deleteRequested(string filePath, string fileName)
    signal previewRequested(string imageSource, string tooltipText, string filePath, string fileName, bool isFromDownloaded)
    signal saveToSavedRequested(string filePath)

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 12

    readonly property var currentModel: currentSubTab === 0 ? Services.WallpaperService.savedList : Services.WallpaperService.downloadedList
    readonly property bool currentLoading: currentSubTab === 0 ? Services.WallpaperService.savedLoading : Services.WallpaperService.downloadedLoading
    readonly property string currentDirHint: currentSubTab === 0 ? Services.ConfigService.wallpaperDirectory : Services.ConfigService.wallpaperDownloadDirectory

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Widgets.TabButton {
            text: "Saved"
            active: root.currentSubTab === 0
            onClicked: root.currentSubTab = 0
        }
        Widgets.TabButton {
            text: "Downloaded"
            active: root.currentSubTab === 1
            onClicked: {
                root.currentSubTab = 1
                Services.WallpaperService.refreshDownloaded()
            }
        }
        Item {
            Layout.fillWidth: true
        }
        Widgets.IconButton {
            width: 28
            height: 28
            icon: "\uf01e"
            iconSize: 12
            iconColor: Wallpaper.WallpaperColors.subText
            hoverIconColor: Wallpaper.WallpaperColors.primary
            baseColor: "transparent"
            hoverColor: Qt.rgba(Wallpaper.WallpaperColors.primary.r, Wallpaper.WallpaperColors.primary.g, Wallpaper.WallpaperColors.primary.b, 0.15)
            onClicked: currentSubTab === 0 ? Services.WallpaperService.refreshSaved() : Services.WallpaperService.refreshDownloaded()
        }
    }

    Widgets.ImageGrid {
        Layout.fillWidth: true
        Layout.fillHeight: true
        model: root.currentModel
        backgroundColor: Wallpaper.WallpaperColors.surfaceContainer

        delegate: Widgets.ImageGridItem {
            required property string filePath
            required property string fileName

            width: 180 - 8
            height: 180 * 9 / 16 + 8 - 8
            imageSource: "file://" + filePath
            tooltipText: fileName

            onClicked: root.wallpaperSelected(filePath)
            onRightClicked: {
                contextMenu.filePath = filePath
                contextMenu.fileName = fileName
                contextMenu.popup()
            }
        }

        Widgets.EmptyState {
            anchors.centerIn: parent
            visible: root.currentModel.count === 0 && !root.currentLoading
            icon: "󰈙"
            iconSize: 32
            iconOpacity: 0.2
            title: "No wallpapers found"
            subtitle: "Check the directory: " + (root.currentDirHint || "")
            textOpacity: 1.0
        }
    }

    Menu {
        id: contextMenu
        property string filePath: ""
        property string fileName: ""

        MenuItem {
            text: qsTr("Preview")
            onTriggered: root.previewRequested("file://" + contextMenu.filePath, contextMenu.fileName, contextMenu.filePath, contextMenu.fileName, root.currentSubTab === 1)
        }
        MenuItem {
            text: qsTr("Copy path")
            onTriggered: root.copyRequested(contextMenu.filePath)
        }
        MenuItem {
            text: qsTr("Open in file manager")
            onTriggered: root.openRequested(contextMenu.filePath)
        }
        MenuItem {
            text: qsTr("Save to saved folder")
            visible: root.currentSubTab === 1
            onTriggered: root.saveToSavedRequested(contextMenu.filePath)
        }
        MenuItem {
            text: qsTr("Delete")
            onTriggered: root.deleteRequested(contextMenu.filePath, contextMenu.fileName)
        }
    }
}
