import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Effects
import Quickshell
import "../../Commons" as Commons
import "../../Widgets" as Widgets

Widgets.PopupWindow {
    id: popupWindow
    
    ipcTarget: "shellmenu"
    initialScale: 0.94
    closeOnClickOutside: true
    barPosition: Commons.Config.barPosition
    
    property var cheatsheetPopup: null
    property var wallpaperSelector: null
    property var displayManager: null
    property var settingsWindow: null
    
    readonly property color cSurface: Commons.Theme.background
    readonly property color cSurfaceContainer: Qt.lighter(Commons.Theme.background, 1.15)
    readonly property color cPrimary: Commons.Theme.secondary
    readonly property color cText: Commons.Theme.foreground
    readonly property color cSubText: Qt.rgba(cText.r, cText.g, cText.b, 0.6)
    readonly property color cBorder: Qt.rgba(cText.r, cText.g, cText.b, 0.08)
    readonly property color cHover: Qt.rgba(cText.r, cText.g, cText.b, 0.06)
    
    implicitWidth: 260
    implicitHeight: contentColumn.implicitHeight + 40
    
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
        
        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: Commons.Config.popupContentPadding
            spacing: Commons.Theme.spacingMd
            
            Widgets.HeaderWithIcon {
                Layout.fillWidth: true
                icon: "\uf219"
                title: "Shell Menu"
                iconColor: cPrimary
            }
            
            Widgets.Divider {
                Layout.fillWidth: true
            }
            
            Widgets.MenuItem {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                icon: "󰌌"
                text: "IPC Cheatsheet"
                iconColor: cPrimary
                textColor: cText
                borderColor: cBorder
                hoverColor: cHover
                onClicked: {
                    popupWindow.shouldShow = false
                    if (cheatsheetPopup) {
                        cheatsheetPopup.shouldShow = true
                    }
                }
            }
            
            Widgets.MenuItem {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                icon: "\uf03e"
                text: "Wallpaper Selector"
                iconColor: cPrimary
                textColor: cText
                borderColor: cBorder
                hoverColor: cHover
                onClicked: {
                    popupWindow.shouldShow = false
                    if (wallpaperSelector) {
                        wallpaperSelector.shouldShow = true
                    }
                }
            }
            
            Widgets.MenuItem {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                icon: "󰍹"
                text: "Display Manager"
                iconColor: cPrimary
                textColor: cText
                borderColor: cBorder
                hoverColor: cHover
                onClicked: {
                    popupWindow.shouldShow = false
                    if (displayManager) {
                        displayManager.shouldShow = true
                    }
                }
            }

            Widgets.MenuItem {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                icon: "\uf013"
                text: "Settings"
                iconColor: cPrimary
                textColor: cText
                borderColor: cBorder
                hoverColor: cHover
                onClicked: {
                    popupWindow.shouldShow = false
                    if (settingsWindow) {
                        settingsWindow.shouldShow = true
                    }
                }
            }

            Widgets.MenuItem {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                icon: "󰑐"
                text: "Reload Quickshell"
                iconColor: cPrimary
                textColor: cText
                borderColor: cBorder
                hoverColor: cHover
                onClicked: Quickshell.reload(true)
            }
        }
    }
}
