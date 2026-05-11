import QtQuick 6.10
import "../Commons" as Commons

Rectangle {
    id: root
    
    property string icon: ""
    property string text: ""
    property int iconSize: 16
    property int textSize: 12
    property color iconColor: Commons.Theme.foreground
    property color textColor: Commons.Theme.foreground
    property color hoverIconColor: Commons.Theme.secondary
    property color hoverTextColor: Commons.Theme.secondary
    property color baseColor: "transparent"
    property color hoverColor: Qt.rgba(Commons.Theme.foreground.r, Commons.Theme.foreground.g, Commons.Theme.foreground.b, 0.06)
    property color pressedColor: Qt.rgba(Commons.Theme.foreground.r, Commons.Theme.foreground.g, Commons.Theme.foreground.b, 0.12)
    property int animationDuration: 150
    property bool scaleOnHover: false
    property real hoverScale: 1.05
    property real pressedScale: 0.85
    
    signal clicked()
    
    implicitWidth: icon && text ? 100 : (icon ? 36 : 80)
    implicitHeight: 36
    radius: Commons.Theme.radius
    
    color: buttonArea.pressed ? pressedColor : (buttonArea.containsMouse ? hoverColor : baseColor)
    scale: scaleOnHover ? (buttonArea.pressed ? pressedScale : (buttonArea.containsMouse ? hoverScale : 1.0)) : 1.0
    
    Behavior on color {
        ColorAnimation { duration: root.animationDuration }
    }
    
    Behavior on scale {
        NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
    }
    
    Row {
        anchors.centerIn: parent
        spacing: 6
        
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font.family: Commons.Theme.fontIcon
            font.pixelSize: root.iconSize
            color: buttonArea.containsMouse ? root.hoverIconColor : root.iconColor
            visible: root.icon.length > 0
            
            Behavior on color {
                ColorAnimation { duration: root.animationDuration }
            }
        }
        
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.family: Commons.Theme.fontUI
            font.pixelSize: root.textSize
            font.weight: Font.Medium
            color: buttonArea.containsMouse ? root.hoverTextColor : root.textColor
            visible: root.text.length > 0
            
            Behavior on color {
                ColorAnimation { duration: root.animationDuration }
            }
        }
    }
    
    MouseArea {
        id: buttonArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
