import Quickshell
import Quickshell.Wayland
import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Controls 6.10
import QtQuick.Effects
import "../../Services" as Services
import "../../Commons" as Commons
import "../../Widgets" as Widgets

Widgets.PopupWindow {
    id: popupWindow
    
    property bool isHovered: false
    barPosition: Commons.Config.barPosition
    
    readonly property var player: Services.Players.active
    readonly property real playerPosition: Services.Players.currentPosition
    readonly property real playerLength: Services.Players.trackLength
    readonly property bool playerIsPlaying: Services.Players.isPlaying
    
    initialScale: 0.96
    
    implicitWidth: 340
    implicitHeight: popupWindow.player ? contentColumn.implicitHeight + 40 : 0
    
    visible: shouldShow && popupWindow.player !== null
    
    Item {
        id: contentItem
        anchors.fill: parent
        
        property real progress: 0
        
        Rectangle {
            id: backgroundRect
            anchors.fill: parent
            color: Commons.Theme.background
            radius: Commons.Theme.radiusPanel
            border.color: Commons.Theme.border
            border.width: 1
            
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: popupWindow.isHovered = true
                onExited: popupWindow.isHovered = false
            }
            
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, Commons.Theme.popupShadowOpacity)
                shadowBlur: Commons.Theme.popupShadowBlur
                shadowVerticalOffset: Commons.Theme.popupShadowOffset
                shadowHorizontalOffset: 0
            }
        }
        
        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: Commons.Config.popupContentPadding
            spacing: Commons.Theme.spacingLg
            visible: popupWindow.player !== null
            
            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                
                Text {
                    text: "󰎈"
                    font.family: Commons.Theme.fontIcon
                    font.pixelSize: 18
                    color: Commons.Theme.secondary
                }
                
                Text {
                    text: "Now Playing"
                    font.family: Commons.Theme.fontUI
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Commons.Theme.surfaceText
                }
                
                Item { Layout.fillWidth: true }
                
                Widgets.IconButton {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitWidth: 32
                    implicitHeight: 32
                    icon: "󰅖"
                    iconSize: 16
                    iconColor: Commons.Theme.surfaceTextVariant
                    hoverIconColor: Commons.Theme.surfaceText
                    baseColor: "transparent"
                    hoverColor: Qt.rgba(Commons.Theme.surfaceText.r, Commons.Theme.surfaceText.g, Commons.Theme.surfaceText.b, 0.06)
                    onClicked: popupWindow.shouldShow = false
                }
            }
            
            // Album Art
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 260
                Layout.preferredHeight: 260
                Layout.topMargin: 0
                
                // Glow effect background
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 20
                    height: parent.height - 20
                    radius: Commons.Theme.radiusLg
                    color: Commons.Theme.secondary
                    opacity: (popupWindow.player?.trackArtUrl ?? false) ? 0.08 : 0
                    
                    Behavior on opacity {
                        NumberAnimation { duration: 300 }
                    }
                }
                
                Rectangle {
                    id: albumArtContainer
                    anchors.centerIn: parent
                    width: parent.width - 32
                    height: parent.height - 32
                    radius: Commons.Theme.radius
                    color: Commons.Theme.surfaceContainer
                    clip: true
                    border.width: 1
                    border.color: Qt.rgba(Commons.Theme.surfaceText.r, Commons.Theme.surfaceText.g, Commons.Theme.surfaceText.b, 0.08)
                    
                    Image {
                        id: albumArt
                        anchors.fill: parent
                        source: popupWindow.player?.trackArtUrl ?? ""
                        sourceSize: Qt.size(600, 600)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        visible: popupWindow.player?.trackArtUrl ?? false
                        
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                            maskSource: ShaderEffectSource {
                                sourceItem: Rectangle {
                                    width: albumArt.width
                                    height: albumArt.height
                                    radius: Commons.Theme.radius
                                }
                            }
                        }
                    }
                    
                    // Placeholder icon
                    Text {
                        anchors.centerIn: parent
                        text: "󰎈"
                        font.family: Commons.Theme.fontIcon
                        font.pixelSize: 72
                        color: Commons.Theme.surfaceTextVariant
                        visible: !(popupWindow.player?.trackArtUrl ?? false)
                        opacity: 0.2
                    }
                }
            }
            
            // Track Info
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 0
                spacing: 4
                
                Text {
                    Layout.fillWidth: true
                    text: popupWindow.player?.trackTitle ?? "Unknown Track"
                    color: Commons.Theme.surfaceText
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    font.family: Commons.Theme.fontUI
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }
                
                Text {
                    Layout.fillWidth: true
                    text: popupWindow.player?.trackArtist ?? "Unknown Artist"
                    color: Commons.Theme.secondary
                    font.pixelSize: 12
                    font.family: Commons.Theme.fontUI
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    Layout.fillWidth: true
                    text: popupWindow.player?.trackAlbum ?? ""
                    color: Commons.Theme.surfaceTextVariant
                    font.pixelSize: 11
                    font.family: Commons.Theme.fontUI
                    opacity: 0.7
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    visible: text.length > 0
                }
            }
            
            // Progress Section
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                
                Widgets.CustomSlider {
                    id: progressSlider
                    Layout.fillWidth: true
                    from: 0
                    to: popupWindow.playerLength > 0 ? popupWindow.playerLength : 1
                    enabled: popupWindow.player && popupWindow.player.canSeek && popupWindow.player.positionSupported
                    trackColor: Qt.rgba(Commons.Theme.surfaceText.r, Commons.Theme.surfaceText.g, Commons.Theme.surfaceText.b, 0.12)
                    progressColor: Commons.Theme.secondary
                    handleColor: Commons.Theme.surfaceText
                    handleBorderColor: Commons.Theme.secondary
                    trackHeight: 4
                    handleSize: 16
                    
                    property bool userInteracting: false
                    
                    Binding {
                        target: progressSlider
                        property: "value"
                        value: popupWindow.playerPosition ?? 0
                        when: !progressSlider.userInteracting
                    }
                    
                    onPressedChanged: {
                        userInteracting = pressed
                        if (pressed && popupWindow.player && popupWindow.player.positionSupported) {
                            popupWindow.player.positionChanged()
                        }
                    }
                    
                    onMoved: {
                        if (popupWindow.player && popupWindow.player.canSeek && popupWindow.player.positionSupported) {
                            var newPosition = value
                            var currentPosition = popupWindow.player.position || 0
                            var offset = newPosition - currentPosition
                            if (Math.abs(offset) > 0.05) {
                                popupWindow.player.seek(offset)
                            }
                        }
                    }
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: popupWindow.formatTime(popupWindow.playerPosition ?? 0)
                        color: Commons.Theme.surfaceTextVariant
                        font.pixelSize: 11
                        font.family: Commons.Theme.fontMono
                        font.weight: Font.Medium
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Text {
                        text: popupWindow.formatTime(popupWindow.playerLength ?? 0)
                        color: Commons.Theme.surfaceTextVariant
                        font.pixelSize: 11
                        font.family: Commons.Theme.fontMono
                        font.weight: Font.Medium
                    }
                }
            }
            
            // Controls
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 0
                spacing: 12
                
                Item { Layout.fillWidth: true }
                
                // Previous button
                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: Commons.Theme.radiusLg
                    color: prevMouse.containsMouse ? Qt.rgba(Commons.Theme.surfaceText.r, Commons.Theme.surfaceText.g, Commons.Theme.surfaceText.b, 0.08) : "transparent"
                    
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.family: Commons.Theme.fontIcon
                        font.pixelSize: 20
                        color: Commons.Theme.surfaceText
                    }
                    
                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (popupWindow.player) popupWindow.player.previous()
                        }
                    }
                }
                
                // Play/Pause button
                Rectangle {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    radius: Commons.Theme.radiusLg
                    color: playMouse.pressed ? Qt.darker(Commons.Theme.secondary, 1.1) : 
                           (playMouse.containsMouse ? Qt.lighter(Commons.Theme.secondary, 1.1) : Commons.Theme.secondary)
                    
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    scale: playMouse.pressed ? 0.95 : 1.0
                    
                    Behavior on scale {
                        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: (popupWindow.player?.isPlaying ?? false) ? 0 : 2
                        text: (popupWindow.player?.isPlaying ?? false) ? "󰏤" : "󰐊"
                        font.family: Commons.Theme.fontIcon
                        font.pixelSize: 26
                        color: Commons.Theme.background
                    }
                    
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (popupWindow.player) popupWindow.player.togglePlaying()
                        }
                    }
                }
                
                // Next button
                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: Commons.Theme.radiusLg
                    color: nextMouse.containsMouse ? Qt.rgba(Commons.Theme.surfaceText.r, Commons.Theme.surfaceText.g, Commons.Theme.surfaceText.b, 0.08) : "transparent"
                    
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.family: Commons.Theme.fontIcon
                        font.pixelSize: 20
                        color: Commons.Theme.surfaceText
                    }
                    
                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (popupWindow.player) popupWindow.player.next()
                        }
                    }
                }
                
                Item { Layout.fillWidth: true }
            }
        }
        
        Timer {
            id: progressTimer
            interval: 250
            repeat: true
            running: true
            onTriggered: {
                if (!popupWindow.player || !popupWindow.playerLength || popupWindow.playerLength <= 0) {
                    contentItem.progress = 0
                } else {
                    var p = popupWindow.playerPosition / popupWindow.playerLength
                    if (!isFinite(p) || p < 0) p = 0
                    contentItem.progress = Math.max(0, Math.min(1, p))
                }
                
                if (popupWindow.player && popupWindow.player.positionSupported && popupWindow.player.isPlaying) {
                    popupWindow.player.positionChanged()
                }
            }
        }
    }
    
    readonly property real progress: contentItem.progress
    function formatTime(seconds) {
        if (!seconds || seconds <= 0) return "0:00"
        const mins = Math.floor(seconds / 60)
        const secs = Math.floor(seconds % 60)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }
}

