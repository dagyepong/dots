import QtQuick 6.10
import QtQuick.Controls 6.10
import "../Commons" as Commons
import "../Services" as Services

Rectangle {
    id: root
    
    property string imageSource: ""
    property string tooltipText: ""
    property string overlayText: ""
    property bool showOverlay: overlayText.length > 0
    property color hoverColor: Qt.rgba(Commons.Theme.foreground.r, Commons.Theme.foreground.g, Commons.Theme.foreground.b, 0.06)
    property color primaryColor: Commons.Theme.primary
    property color borderColor: Qt.rgba(Commons.Theme.foreground.r, Commons.Theme.foreground.g, Commons.Theme.foreground.b, 0.08)
    property color surfaceColor: Commons.Theme.background
    property color textColor: Commons.Theme.foreground
    property color subTextColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.6)
    property string cachedImagePath: ""
    
    signal clicked()
    signal rightClicked()
    
    Component.onCompleted: {
        if (!imageSource || imageSource === "") {
            return
        }
        
        var cleanPath = imageSource.replace("file://", "")
        
        if (Services.ImageCacheService.initialized && Services.ImageCacheService.imageMagickAvailable) {
            Services.ImageCacheService.getThumbnail(cleanPath, function(path, success) {
                if (root && path && path !== "") {
                    root.cachedImagePath = path
                }
            })
        } else if (Services.ImageCacheService.initialized) {
            cachedImagePath = cleanPath
        }
    }
    
    Connections {
        target: Services.ImageCacheService
        function onInitializedChanged() {
            if (Services.ImageCacheService.initialized && 
                imageSource && 
                !cachedImagePath) {
                var cleanPath = imageSource.replace("file://", "")
                
                if (Services.ImageCacheService.imageMagickAvailable) {
                    Services.ImageCacheService.getThumbnail(cleanPath, function(path, success) {
                        if (root && path && path !== "") {
                            root.cachedImagePath = path
                        }
                    })
                } else {
                    root.cachedImagePath = cleanPath
                }
            }
        }
    }
    
    radius: Commons.Theme.radius
    color: mouseArea.containsMouse ? hoverColor : "transparent"
    border.width: mouseArea.containsMouse ? 2 : 1
    border.color: mouseArea.containsMouse ? primaryColor : borderColor
    
    Behavior on color {
        ColorAnimation { duration: 100 }
    }
    
    Behavior on border.color {
        ColorAnimation { duration: 100 }
    }
    
    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: Commons.Theme.radiusSm
        color: root.surfaceColor
        clip: true
        
        Image {
            id: image
            anchors.fill: parent
            source: {
                if (!root.cachedImagePath || root.cachedImagePath === "") {
                    return ""
                }
                return root.cachedImagePath.startsWith("/") ? "file://" + root.cachedImagePath : root.cachedImagePath
            }
            sourceSize: Qt.size(Math.min(parent.width * 2, 400), Math.min(parent.height * 2, 300))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            cache: true
            
            onStatusChanged: {
                if (status === Image.Error) {
                    errorIcon.visible = true
                    busyIndicator.visible = false
                } else if (status === Image.Ready) {
                    busyIndicator.visible = false
                } else if (status === Image.Loading) {
                    busyIndicator.visible = true
                }
            }
        }
        
        Rectangle {
            anchors.centerIn: parent
            width: 40
            height: 40
            radius: Commons.Theme.radiusLg
            color: Qt.rgba(0, 0, 0, 0.3)
            visible: busyIndicator.visible || !root.cachedImagePath
            
            Text {
                id: busyIndicator
                anchors.centerIn: parent
                text: "..."
                font.family: Commons.Theme.fontUI
                font.pixelSize: 16
                color: Commons.Theme.foreground
                visible: !root.cachedImagePath || image.status === Image.Loading
                
                SequentialAnimation on opacity {
                    running: busyIndicator.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.3; to: 1.0; duration: 600 }
                    NumberAnimation { from: 1.0; to: 0.3; duration: 600 }
                }
            }
        }
        
        Text {
            id: errorIcon
            anchors.centerIn: parent
            text: "󰈙"
            font.family: Commons.Theme.fontIcon
            font.pixelSize: 24
            color: root.subTextColor
            visible: false
        }
        
        // Tooltip
        Rectangle {
            id: tooltipRect
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 6
            radius: Commons.Theme.radiusSm
            color: Qt.rgba(0, 0, 0, 0.6)
            visible: mouseArea.containsMouse && root.tooltipText.length > 0
            z: 2
            implicitHeight: 22
            implicitWidth: Math.min(parent.width - 12, 220)
            
            Text {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                text: root.tooltipText
                font.family: Commons.Theme.fontUI
                font.pixelSize: 11
                color: "white"
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }
        
        // Overlay text (for resolution, etc.)
        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 4
            text: root.overlayText
            font.family: Commons.Theme.fontUI
            font.pixelSize: 9
            color: root.textColor
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.8)
            visible: root.showOverlay
        }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                root.clicked()
            } else if (mouse.button === Qt.RightButton) {
                root.rightClicked()
            }
        }
    }
}