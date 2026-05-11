import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../Services" as Services
import "../../Commons" as Commons
import "../../Widgets" as Widgets

PanelWindow {
    id: root
    
    readonly property string barPosition: Commons.Config.barPosition
    
    readonly property var notifs: Services.Notifications
    readonly property var activePopups: (
        notifs.notifications
            .filter(n => !n.closed && !n.dismissed)
            .slice(0, Commons.Config.notifications.maxVisible)
    )
    
    screen: Quickshell.screens[0]
    
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    
    anchors {
        top: barPosition === "top"
        bottom: barPosition === "bottom"
        left: barPosition === "left"
        right: barPosition === "right" || barPosition === "top" || barPosition === "bottom"
    }
    
    readonly property int barOffset: (barPosition === "top" || barPosition === "bottom") 
        ? (Commons.Config.barHeight + Commons.Config.barMargin * 2 + Commons.Config.popupMargin)
        : (Commons.Config.barWidth + Commons.Config.barMargin * 2 + Commons.Config.popupMargin)
    
    margins {
        top: barPosition === "top" ? barOffset : Commons.Config.popupMargin
        bottom: barPosition === "bottom" ? barOffset : 0
        right: (barPosition === "right") ? barOffset : Commons.Config.popupMargin
        left: barPosition === "left" ? barOffset : 0
    }
    
    visible: activePopups.length > 0
    color: "transparent"
    
    implicitWidth: Commons.Config.notifications.popupWidth
    implicitHeight: notifColumn.implicitHeight
    
    Column {
        id: notifColumn
        width: parent.width
        spacing: Commons.Config.notifications.spacing
        
        move: Transition {
            NumberAnimation {
                properties: "y"
                duration: 120
                easing.type: Easing.OutQuad
            }
        }
        
        Repeater {
            model: root.activePopups
            
            Item {
                id: notifCard
                
                required property var modelData
                required property int index
                
                width: Commons.Config.notifications.popupWidth
                height: cardWrapper.height
                clip: true
                
                property real entranceScale: 0.7
                property real entranceX: 120
                property real entranceOpacity: 0
                
                Component.onCompleted: {
                    entranceScale = 1.0
                    entranceX = 0
                    entranceOpacity = 1.0
                }
                
                Item {
                    id: cardWrapper
                    width: parent.width
                    height: card.implicitHeight
                    
                    scale: notifCard.entranceScale
                    opacity: notifCard.entranceOpacity
                    transform: Translate {
                        x: notifCard.entranceX
                    }
                    
                    transformOrigin: Item.Right
                    
                    Widgets.NotificationCard {
                        id: card
                        width: parent.width
                        notification: notifCard.modelData
                        isPopup: true
                        
                        onDismissed: {
                            if (modelData && typeof modelData.dismissPopup === 'function') {
                                modelData.dismissPopup()
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
    }
}