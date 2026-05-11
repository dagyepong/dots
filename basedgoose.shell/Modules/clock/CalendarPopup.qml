import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Effects
import Quickshell
import "../../Commons" as Commons
import "../../Widgets" as Widgets

Widgets.PopupWindow {
    id: popupWindow
    
    ipcTarget: "calendar"
    initialScale: 0.85
    barPosition: Commons.Config.barPosition
    
    implicitWidth: 320
    implicitHeight: contentColumn.implicitHeight + 32
    
    property var currentDate: new Date()
    
    Rectangle {
        anchors.fill: backgroundRect
        anchors.margins: -6
        radius: backgroundRect.radius + 4
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
    }
    
    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: Commons.Config.popupContentPadding
        spacing: Commons.Theme.spacingMd
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            Widgets.HeaderWithIcon {
                icon: "󰃭"
                title: Qt.formatDateTime(currentDate, "MMMM yyyy")
                iconColor: Commons.Theme.secondary
            }
            
            Item {
                Layout.fillWidth: true
            }
            
            Widgets.NavButton {
                icon: "󰁍"
                baseColor: "transparent"
                hoverColor: Commons.Theme.secondaryMuted
                iconColor: Commons.Theme.secondary
                hoverIconColor: Commons.Theme.secondary
                onClicked: {
                    var newDate = new Date(currentDate)
                    newDate.setMonth(newDate.getMonth() - 1)
                    currentDate = newDate
                }
            }
            
            Widgets.NavButton {
                icon: "󰁔"
                baseColor: "transparent"
                hoverColor: Commons.Theme.secondaryMuted
                iconColor: Commons.Theme.secondary
                hoverIconColor: Commons.Theme.secondary
                onClicked: {
                    var newDate = new Date(currentDate)
                    newDate.setMonth(newDate.getMonth() + 1)
                    currentDate = newDate
                }
            }
        }
        
        Widgets.Divider {
            Layout.fillWidth: true
        }
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            
            Repeater {
                model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                Text {
                    Layout.fillWidth: true
                    text: modelData
                    font.family: Commons.Theme.fontUI
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Commons.Theme.foregroundMuted
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
        
        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 4
            columnSpacing: 4
            
            Repeater {
                id: calendarRepeater
                
                property int firstDayOfMonth: {
                    var firstDay = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1)
                    return firstDay.getDay()
                }
                
                property int daysInMonth: {
                    return new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0).getDate()
                }
                
                property var today: new Date()
                
                model: 42 // 6 weeks * 7 days
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: Commons.Theme.radiusSm
                    
                    property int dayNum: index - calendarRepeater.firstDayOfMonth + 1
                    property bool isCurrentMonth: dayNum > 0 && dayNum <= calendarRepeater.daysInMonth
                    property bool isToday: {
                        return isCurrentMonth && 
                               dayNum === calendarRepeater.today.getDate() &&
                               currentDate.getMonth() === calendarRepeater.today.getMonth() &&
                               currentDate.getFullYear() === calendarRepeater.today.getFullYear()
                    }
                    
                    color: {
                        if (isToday) {
                            return Commons.Theme.primary
                        } else if (isCurrentMonth) {
                            return mouseArea.containsMouse ? Commons.Theme.surfaceAccent : "transparent"
                        }
                        return "transparent"
                    }
                    
                    border.color: isToday ? Commons.Theme.primary : "transparent"
                    border.width: isToday ? 1 : 0
                    
                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (parent.dayNum > 0 && parent.dayNum <= calendarRepeater.daysInMonth) {
                                return parent.dayNum
                            }
                            if (parent.dayNum <= 0) {
                                var prevMonthDays = new Date(currentDate.getFullYear(), currentDate.getMonth(), 0).getDate()
                                return prevMonthDays + parent.dayNum
                            } else {
                                return parent.dayNum - calendarRepeater.daysInMonth
                            }
                        }
                        font.family: Commons.Theme.fontUI
                        font.pixelSize: 12
                        font.weight: parent.isToday ? Font.DemiBold : Font.Medium
                        color: {
                            if (parent.isToday) {
                                return Commons.Theme.background
                            } else if (parent.isCurrentMonth) {
                                return Commons.Theme.foreground
                            }
                            return Commons.Theme.foregroundMuted
                        }
                    }
                    
                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                    
                    Behavior on color {
                        ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
        
        Widgets.TextButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            text: "Today"
            textColor: Commons.Theme.foreground
            hoverColor: Commons.Theme.surfaceContainer
            onClicked: {
                currentDate = new Date()
            }
        }
    }
}
