import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Controls 6.10
import "../../Widgets" as Widgets
import "../../Services" as Services
import "../../Commons" as Commons
import "." as Wallpaper

ColumnLayout {
    id: root
    
    property string sorting: "date_added"
    property string topRange: "1M"
    property int currentPage: 1
    property string searchQuery: ""
    
    signal sortingRequested(string newSorting)
    signal topRangeRequested(string newRange)
    signal pageRequested(int newPage)
    signal refreshRequested()
    signal wallpaperSelected(string id, string fullUrl)
    signal searchRequested(string query)
    signal previewRequested(string imageSource, string tooltipText, string wallhavenId, string wallhavenFullUrl)
    signal saveToSavedRequested(string id, string fullUrl)
    
    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 8

    Menu {
        id: wallhavenContextMenu
        property string whId: ""
        property string fullUrl: ""
        property string resolution: ""

        MenuItem {
            text: qsTr("Preview")
            onTriggered: root.previewRequested(wallhavenContextMenu.fullUrl, wallhavenContextMenu.resolution, wallhavenContextMenu.whId, wallhavenContextMenu.fullUrl)
        }
        MenuItem {
            text: qsTr("Save to saved folder")
            onTriggered: root.saveToSavedRequested(wallhavenContextMenu.whId, wallhavenContextMenu.fullUrl)
        }
    }
    
    // Search input
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        color: Wallpaper.WallpaperColors.surfaceContainer
        radius: Commons.Theme.radiusSm
        border.width: searchQueryInput.activeFocus ? 1 : 0
        border.color: Wallpaper.WallpaperColors.primary
        
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 6
            
            Text {
                text: "\uf002"
                font.family: Commons.Theme.fontIcon
                font.pixelSize: 12
                color: Wallpaper.WallpaperColors.subText
            }
            
            TextInput {
                id: searchQueryInput
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: TextInput.AlignVCenter
                font.family: Commons.Theme.fontUI
                font.pixelSize: 12
                color: Wallpaper.WallpaperColors.text
                selectionColor: Wallpaper.WallpaperColors.primary
                selectedTextColor: Wallpaper.WallpaperColors.text
                text: root.searchQuery
                
                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Search wallpapers..."
                    font: parent.font
                    color: Wallpaper.WallpaperColors.subText
                    visible: !parent.text && !parent.activeFocus
                }
                
                onAccepted: {
                    root.searchQuery = text
                    root.searchRequested(text)
                }
            }
            
            Widgets.IconButton {
                visible: searchQueryInput.text.length > 0
                width: 20
                height: 20
                icon: "\uf00d"
                iconSize: 10
                iconColor: Wallpaper.WallpaperColors.subText
                hoverIconColor: Wallpaper.WallpaperColors.text
                baseColor: "transparent"
                hoverColor: "transparent"
                onClicked: {
                    searchQueryInput.text = ""
                    root.searchQuery = ""
                    root.searchRequested("")
                }
            }
        }
    }
    
    // Sorting buttons
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        
        Repeater {
            model: [
                { key: "date_added", label: "Latest" },
                { key: "hot", label: "Hot" },
                { key: "toplist", label: "Top" },
                { key: "random", label: "Random" }
            ]
            
            Widgets.FilterButton {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 28
                text: modelData.label
                value: modelData.key
                currentValue: root.sorting
                onClicked: function(value) {
                    root.sortingRequested(value)
                }
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
            onClicked: root.refreshRequested()
        }
    }
    
    // Top range selector (visible only for toplist)
    Row {
        Layout.fillWidth: true
        visible: root.sorting === "toplist"
        spacing: 4
        
        Repeater {
            model: ["1d", "3d", "1w", "1M", "3M", "6M", "1y"]
            
            Widgets.FilterButton {
                width: 36
                height: 24
                text: modelData
                value: modelData
                currentValue: root.topRange
                onClicked: function(value) {
                    root.topRangeRequested(value)
                }
            }
        }
    }
    
    // Image grid
    Widgets.ImageGrid {
        Layout.fillWidth: true
        Layout.fillHeight: true
        model: Services.WallhavenAPIService.wallhavenList
        backgroundColor: Wallpaper.WallpaperColors.surfaceContainer
        
        delegate: Widgets.ImageGridItem {
            required property string id
            required property string thumbUrl
            required property string fullUrl
            required property string resolution

            width: 180 - 8
            height: 180 * 9 / 16 + 8 - 8
            imageSource: thumbUrl
            overlayText: resolution
            showOverlay: true

            onClicked: root.wallpaperSelected(id, fullUrl)
            onRightClicked: {
                wallhavenContextMenu.whId = id
                wallhavenContextMenu.fullUrl = fullUrl
                wallhavenContextMenu.resolution = resolution
                wallhavenContextMenu.popup()
            }
        }
        
        Widgets.EmptyState {
            anchors.centerIn: parent
            visible: Services.WallhavenAPIService.wallhavenList.count === 0 && !Services.WallhavenAPIService.running
            icon: "󰈙"
            iconSize: 32
            iconOpacity: 0.2
            title: Services.WallhavenAPIService.wallhavenList.count === 0 && !Services.WallhavenAPIService.running && Services.WallhavenAPIService.loadedOnce ? "Failed to load" : "Choose a category to load"
            subtitle: ""
            textOpacity: 1.0
        }
    }
    
    // Pagination
    Row {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        spacing: 8
        
        Widgets.IconButton {
            width: 32
            height: 32
            icon: "\uf060"
            iconSize: 12
            iconColor: root.currentPage <= 1 ? Wallpaper.WallpaperColors.subText : Wallpaper.WallpaperColors.text
            hoverIconColor: Wallpaper.WallpaperColors.primary
            baseColor: "transparent"
            hoverColor: Qt.rgba(Wallpaper.WallpaperColors.primary.r, Wallpaper.WallpaperColors.primary.g, Wallpaper.WallpaperColors.primary.b, 0.15)
            onClicked: {
                if (root.currentPage > 1) {
                    root.pageRequested(root.currentPage - 1)
                }
            }
        }
        
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Page " + root.currentPage + " of " + Services.WallhavenAPIService.lastPage
            font.family: Commons.Theme.fontUI
            font.pixelSize: 11
            color: Wallpaper.WallpaperColors.subText
        }
        
        Widgets.IconButton {
            width: 32
            height: 32
            icon: "\uf061"
            iconSize: 12
            iconColor: root.currentPage >= Services.WallhavenAPIService.lastPage ? Wallpaper.WallpaperColors.subText : Wallpaper.WallpaperColors.text
            hoverIconColor: Wallpaper.WallpaperColors.primary
            baseColor: "transparent"
            hoverColor: Qt.rgba(Wallpaper.WallpaperColors.primary.r, Wallpaper.WallpaperColors.primary.g, Wallpaper.WallpaperColors.primary.b, 0.15)
            onClicked: {
                if (root.currentPage < Services.WallhavenAPIService.lastPage) {
                    root.pageRequested(root.currentPage + 1)
                }
            }
        }
    }
}