import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Effects
import "../Commons" as Commons
import "../Widgets" as Widgets

Rectangle {
    id: notificationCard
    
    required property var notification
    required property bool isPopup
    
    property bool isHovered: false
    property bool isExpanded: false
    
    signal dismissed()
    signal actionClicked(var action)
    
    implicitHeight: contentLayout.implicitHeight + (isPopup ? 28 : 24)
    
    readonly property color surfaceBase: Commons.Theme.surfaceBase
    readonly property color surfaceContainer: Commons.Theme.surfaceContainer
    readonly property color secondary: Commons.Theme.secondary
    readonly property color surfaceText: Commons.Theme.surfaceText
    readonly property color surfaceTextVariant: Commons.Theme.surfaceTextVariant
    readonly property color error: Commons.Theme.error
    readonly property color surfaceBorder: Commons.Theme.surfaceBorder
    
    radius: isPopup ? Commons.Theme.radiusPanel : Commons.Theme.radiusLg
    color: isPopup ? surfaceBase : (isHovered ? Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.04) : surfaceContainer)
    
    border.width: 1
    border.color: isPopup ? 
                  (isHovered ? Qt.rgba(secondary.r, secondary.g, secondary.b, 0.15) : Commons.Theme.border) :
                  surfaceBorder
    
    opacity: notification.closed ? 0.85 : 1.0
    
    Behavior on border.color {
        ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    
    layer.enabled: isPopup
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.18)
        shadowBlur: 0.6
        shadowVerticalOffset: 4
        shadowHorizontalOffset: 0
    }
    
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: surfaceText
        opacity: isPopup && isHovered ? 0.03 : 0
        visible: isPopup
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: !isPopup
        z: isPopup ? 0 : -1
        
        onEntered: isHovered = true
        onExited: if (!pressed) isHovered = false
        onReleased: mouse => {
            if (!containsMouse) isHovered = false
        }
        
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                dismissed()
            } else if (isPopup) {
                if (notification.actions && notification.actions.length === 1) {
                    actionClicked(notification.actions[0])
                    dismissed()
                }
            }
        }
    }
    
    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: isPopup ? Commons.Theme.spacingLg : 12
        anchors.leftMargin: isPopup ? (notification.urgency >= 1 ? Commons.Theme.spacingXl : Commons.Theme.spacingLg) : 12
        spacing: isPopup ? Commons.Theme.spacingSm : 6
        
        RowLayout {
            Layout.fillWidth: true
            spacing: isPopup ? 12 : 10
            
            Widgets.AppIcon {
                Layout.preferredWidth: isPopup ? 38 : 32
                Layout.preferredHeight: isPopup ? 38 : 32
                size: isPopup ? 38 : 32
                iconSize: isPopup ? 20 : 18
                iconSource: notification.appIcon || ""
                fallbackIcon: "󰂞"
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                
                Text {
                    text: notification.appName || "Notification"
                    font.pixelSize: isPopup ? 12 : 11
                    font.weight: Font.Medium
                    font.family: Commons.Theme.fontUI
                    font.letterSpacing: isPopup ? 0.3 : 0
                    color: surfaceTextVariant
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                
                Text {
                    text: notification.timeString || "now"
                    font.pixelSize: isPopup ? 10 : 9
                    font.family: Commons.Theme.fontUI
                    font.letterSpacing: isPopup ? 0.2 : 0
                    color: Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.35)
                }
            }
            
            Widgets.IconButton {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                icon: "󰅖"
                iconSize: 14
                iconColor: isPopup ? Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.4) : surfaceTextVariant
                hoverIconColor: error
                hoverColor: isPopup ? Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.06) : Qt.rgba(error.r, error.g, error.b, 0.1)
                pressedColor: isPopup ? Qt.rgba(error.r, error.g, error.b, 0.15) : Qt.rgba(error.r, error.g, error.b, 0.2)
                onClicked: dismissed()
            }
            
            Widgets.IconButton {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                icon: isExpanded ? "󰅀" : "󰅂"
                iconSize: 14
                iconColor: isPopup ? Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.4) : surfaceTextVariant
                hoverIconColor: secondary
                hoverColor: isPopup ? Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.06) : Qt.rgba(secondary.r, secondary.g, secondary.b, 0.1)
                pressedColor: isPopup ? Qt.rgba(secondary.r, secondary.g, secondary.b, 0.15) : Qt.rgba(secondary.r, secondary.g, secondary.b, 0.2)
                visible: !isPopup && ((notification.appImage && notification.appImage.length > 0 && notification.appImage !== "") || (notification.body && notification.body.length > 150))
                onClicked: isExpanded = !isExpanded
            }
        }
        
        Text {
            Layout.fillWidth: true
            Layout.topMargin: isPopup ? 2 : 0
            text: notification.summary || ""
            font.pixelSize: Commons.Theme.fontSizeSubheading
            font.weight: Font.DemiBold
            font.family: Commons.Theme.fontUI
            font.letterSpacing: isPopup ? -0.1 : 0
            color: surfaceText
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeight: isPopup ? 1.25 : 1.0
            visible: text.length > 0
        }
        
        Text {
            Layout.fillWidth: true
            text: notification.body || ""
            font.pixelSize: isPopup ? 12 : 11
            font.family: Commons.Theme.fontUI
            font.letterSpacing: isPopup ? 0.1 : 0
            color: surfaceTextVariant
            wrapMode: Text.Wrap
            maximumLineCount: isExpanded ? 10 : 3
            elide: Text.ElideRight
            lineHeight: isPopup ? 1.35 : 1.0
            visible: text.length > 0
            
            Behavior on maximumLineCount {
                NumberAnimation { duration: 200 }
            }
        }
        
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 90 : 0
            Layout.topMargin: visible ? 4 : 0
            visible: (isPopup || isExpanded) && notification.appImage && notification.appImage.length > 0 && notification.appImage !== ""
            
            Rectangle {
                anchors.fill: parent
                radius: Commons.Theme.radius
                color: surfaceContainer
                border.width: 1
                border.color: surfaceBorder
                clip: true
                
                Image {
                    id: notifImage
                    anchors.fill: parent
                    source: {
                        if (!notification.appImage) return ""
                        if (notification.appImage.startsWith("image://") || 
                            notification.appImage.startsWith("file://") || 
                            notification.appImage.startsWith("/")) {
                            return notification.appImage
                        }
                        return "image://icon/" + notification.appImage
                    }
                    fillMode: Image.PreserveAspectFit
                    horizontalAlignment: Image.AlignHCenter
                    verticalAlignment: Image.AlignVCenter
                    smooth: true
                    cache: true
                    asynchronous: true
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "Image: " + notifImage.status
                    color: "white"
                    visible: notifImage.status !== Image.Ready
                }
            }
        }
        
        Flow {
            id: actionsFlow
            Layout.fillWidth: true
            Layout.topMargin: visible ? (isPopup ? 6 : 4) : 0
            Layout.preferredHeight: visible ? implicitHeight : 0
            Layout.maximumHeight: visible ? -1 : 0
            spacing: 6
            visible: notification.actions && notification.actions.length > 0 && repeater.count > 0
            clip: true
            
            Repeater {
                id: repeater
                model: {
                    if (!notification.actions || notification.actions.length === 0) return null
                    return notification.actions.filter(a => {
                        const text = a.text || a.identifier || ""
                        return text.trim().length > 0
                    })
                }
                
                Widgets.ActionButton {
                    required property var modelData
                    
                    text: modelData.text || modelData.identifier || ""
                    fontSize: isPopup ? 11 : 10
                    horizontalPadding: isPopup ? 20 : 16
                    implicitHeight: isPopup ? 30 : 28
                    onClicked: {
                        actionClicked(modelData)
                        dismissed()
                    }
                }
            }
        }
    }
}
