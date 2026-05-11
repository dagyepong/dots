import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Controls 6.10
import QtQuick.Effects
import Quickshell
import "../../Services" as Services
import "../../Commons" as Commons
import "../../Widgets" as Widgets

Widgets.PopupWindow {
    id: root
    
    ipcTarget: "notifications"
    initialScale: 0.95
    closeOnClickOutside: true
    barPosition: Commons.Config.barPosition
    
    property alias notifs: root.notifService
    
    readonly property var notifService: Services.Notifications
    readonly property var recentNotifs: notifService.recentNotifications
    readonly property var groupedNotifs: notifService.groupedNotifications
    readonly property bool hasDnd: notifService.dnd
    
    implicitWidth: Commons.Config.notifications.centerWidth
    implicitHeight: Commons.Config.notifications.centerHeight
        
    Rectangle {
        anchors.fill: parent
        radius: Commons.Theme.radiusPanel
        color: Commons.Theme.background
        border.width: 1
        border.color: Commons.Theme.border
        
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
        anchors.fill: parent
        anchors.margins: Commons.Config.popupContentPadding
        spacing: Commons.Theme.spacingLg
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            Widgets.HeaderWithIcon {
                icon: "󰂚"
                title: "Notifications"
                iconColor: Commons.Theme.secondary
                titleSize: Commons.Theme.fontSizeHeading
            }
            
            Item {
                Layout.fillWidth: true
            }
            
            Widgets.ToggleSwitch {
                checked: root.hasDnd
                checkedColor: Commons.Theme.secondary
                uncheckedColor: Commons.Theme.surfaceContainer
                thumbColor: root.hasDnd ? Commons.Theme.background : Commons.Theme.surfaceTextVariant
                icon: root.hasDnd ? "󰂛" : "󰂚"
                iconColor: root.hasDnd ? Commons.Theme.secondary : Commons.Theme.background
                onToggled: root.notifService.toggleDnd()
            }
            
            Widgets.IconButton {
                icon: "\udb80\udf9f"
                iconSize: 18
                iconColor: Commons.Theme.surfaceTextVariant
                hoverIconColor: Commons.Theme.error
                baseColor: Commons.Theme.surfaceContainer
                hoverColor: Qt.rgba(Commons.Theme.error.r, Commons.Theme.error.g, Commons.Theme.error.b, 0.15)
                onClicked: root.notifService.clearAll()
            }
            
            Widgets.IconButton {
                icon: "󰅖"
                iconSize: 18
                iconColor: Commons.Theme.surfaceTextVariant
                onClicked: root.shouldShow = false
            }
        }
        
        Widgets.Divider {
            Layout.fillWidth: true
        }
        
        ListView {
            id: notifListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            clip: true
            spacing: Commons.Config.notifications.itemSpacing
            
            model: root.recentNotifs
            
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            
            Item {
                anchors.centerIn: parent
                width: parent.width
                height: 200
                visible: notifListView.count === 0
                
                Widgets.EmptyState {
                    anchors.centerIn: parent
                    icon: "󰂚"
                    iconSize: 64
                    title: "No notifications"
                    subtitle: "You're all caught up!"
                }
            }
            
            delegate: Widgets.NotificationCard {
                required property var modelData
                required property int index
                
                width: notifListView.width
                notification: modelData
                isPopup: false
                
                onDismissed: {
                    if (root.notifService && typeof root.notifService.deleteNotification === 'function') {
                        root.notifService.deleteNotification(modelData)
                    }
                }
                onActionClicked: action => {
                    if (action && typeof action.invoke === 'function') {
                        action.invoke()
                    }
                }
            }
        }
    }
}


