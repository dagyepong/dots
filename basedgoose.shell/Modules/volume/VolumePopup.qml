import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Controls 6.10
import QtQuick.Effects
import Quickshell
import "../../Services" as Services
import "../../Commons" as Commons
import "../../Widgets" as Widgets

Widgets.PopupWindow {
    id: popupWindow
    
    ipcTarget: "volume"
    initialScale: 0.85
    barPosition: Commons.Config.barPosition
    
    property bool isHovered: false
    readonly property var audio: Services.Audio
    
    implicitWidth: 320
    implicitHeight: contentColumn.implicitHeight + 32
    
    Rectangle {
        anchors.fill: backgroundRect
        anchors.margins: -6
        radius: backgroundRect.radius + 3
        color: "transparent"
        
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, Commons.Theme.popupShadowOpacity)
            shadowBlur: Commons.Theme.popupShadowBlur
            shadowVerticalOffset: Commons.Theme.popupShadowOffset
        }
    }

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
    }
    
    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: Commons.Config.popupContentPadding
        spacing: Commons.Theme.spacingMd
        
        Text {
            text: "Volume"
            font.family: Commons.Theme.fontUI
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Commons.Theme.foreground
        }
        
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                
                Text {
                    text: audio.muted ? "󰖁" : "󰕾"
                    font.family: Commons.Theme.fontIcon
                    font.pixelSize: 20
                    color: Commons.Theme.foreground
                }
                
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: outputLabel.height
                    
                    Text {
                        id: outputLabel
                        text: "Output"
                        font.family: Commons.Theme.fontUI
                        font.pixelSize: 12
                        color: outputMuteArea.containsMouse ? Commons.Theme.secondary : Commons.Theme.foreground
                        
                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }
                    }
                    
                    MouseArea {
                        id: outputMuteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: audio.toggleMute()
                    }
                }
                
                Text {
                    text: audio.percentage + "%"
                    font.family: Commons.Theme.fontMono
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Commons.Theme.foreground
                }
            }
            
            Widgets.CustomSlider {
                id: volumeSlider
                Layout.fillWidth: true
                from: 0
                to: 100
                value: audio.percentage
                trackColor: Qt.rgba(Commons.Theme.foreground.r, Commons.Theme.foreground.g, Commons.Theme.foreground.b, 0.15)
                progressColor: Commons.Theme.secondary
                handleColor: Commons.Theme.foreground
                handleBorderColor: Commons.Theme.secondaryMuted
                
                onMoved: {
                    audio.setVolume(value / 100)
                }
            }
        }
        
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                
                Text {
                    text: audio.sourceMuted ? "󰍭" : "󰍬"
                    font.family: Commons.Theme.fontIcon
                    font.pixelSize: 20
                    color: Commons.Theme.foreground
                }
                
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: inputLabel.height
                    
                    Text {
                        id: inputLabel
                        text: "Input"
                        font.family: Commons.Theme.fontUI
                        font.pixelSize: 12
                        color: inputMuteArea.containsMouse ? Commons.Theme.secondary : Commons.Theme.foreground
                        
                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }
                    }
                    
                    MouseArea {
                        id: inputMuteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: audio.toggleSourceMute()
                    }
                }
                
                Text {
                    text: audio.sourcePercentage + "%"
                    font.family: Commons.Theme.fontMono
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Commons.Theme.foreground
                }
            }
            
            Widgets.CustomSlider {
                id: inputSlider
                Layout.fillWidth: true
                from: 0
                to: 100
                value: audio.sourcePercentage
                trackColor: Qt.rgba(Commons.Theme.foreground.r, Commons.Theme.foreground.g, Commons.Theme.foreground.b, 0.15)
                progressColor: Commons.Theme.secondary
                handleColor: Commons.Theme.foreground
                handleBorderColor: Commons.Theme.secondaryMuted
                
                onMoved: {
                    audio.setSourceVolume(value / 100)
                }
            }
        }
    }
}

