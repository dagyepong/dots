import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../Services" as Services
import "../../Commons" as Commons
import "../../Widgets" as Widgets

Widgets.PopupWindow {
    id: powerMenu
    
    ipcTarget: "power"
    initialScale: 0.85
    closeOnClickOutside: true
    barPosition: Commons.Config.barPosition
    
    readonly property color cPrimary: Commons.Theme.secondary
    readonly property color cText: Commons.Theme.foreground
    readonly property color cBorder: Qt.rgba(cText.r, cText.g, cText.b, 0.08)
    readonly property color cHover: Qt.rgba(cText.r, cText.g, cText.b, 0.06)

    implicitWidth: 280
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
                icon: "\udb81\udc25"
                title: "Power Menu"
                iconColor: Commons.Theme.secondary
            }
            
            Widgets.Divider {
                Layout.fillWidth: true
            }

            Widgets.MenuItem {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                icon: "\udb81\udc25"
                text: "Shutdown"
                iconColor: cPrimary
                textColor: cText
                borderColor: cBorder
                hoverColor: cHover
                onClicked: {
                    powerMenu.shouldShow = false
                    processComponent.createObject(powerMenu, { cmd: ["systemctl", "poweroff"] })
                }
            }

            Widgets.MenuItem {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                icon: "\udb81\udf09"
                text: "Reboot"
                iconColor: cPrimary
                textColor: cText
                borderColor: cBorder
                hoverColor: cHover
                onClicked: {
                    powerMenu.shouldShow = false
                    processComponent.createObject(powerMenu, { cmd: ["systemctl", "reboot"] })
                }
            }

            Widgets.MenuItem {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                icon: "\udb81\uddfd"
                text: "Logout"
                iconColor: cPrimary
                textColor: cText
                borderColor: cBorder
                hoverColor: cHover
                onClicked: {
                    powerMenu.shouldShow = false
                    processComponent.createObject(powerMenu, { cmd: ["hyprctl", "dispatch", "exit"] })
                }
            }
        }
        
        Component {
            id: processComponent
            Process {
                property var cmd: []
                running: true
                command: cmd
            }
        }
    }
}

