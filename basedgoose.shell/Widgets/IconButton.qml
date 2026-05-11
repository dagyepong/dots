import QtQuick 6.10
import "../Commons" as Commons

Rectangle {
    id: root
    
    property string icon: ""
    property int iconSize: 18
    property color iconColor: Commons.Theme.surfaceTextVariant
    property color hoverIconColor: Commons.Theme.surfaceText
    property color baseColor: "transparent"
    property color hoverColor: Qt.rgba(Commons.Theme.surfaceText.r, Commons.Theme.surfaceText.g, Commons.Theme.surfaceText.b, 0.08)
    property color pressedColor: Qt.rgba(Commons.Theme.surfaceText.r, Commons.Theme.surfaceText.g, Commons.Theme.surfaceText.b, 0.12)
    property int animationDuration: 150
    property int borderWidth: 0
    property color borderColor: Commons.Theme.surfaceBorder
    
    signal clicked()
    
    implicitWidth: 36
    implicitHeight: 36
    radius: width / 2
    border.width: root.borderWidth
    border.color: root.borderColor
    
    color: buttonMouse.pressed ? pressedColor : (buttonMouse.containsMouse ? hoverColor : baseColor)
    
    Behavior on color {
        ColorAnimation { duration: root.animationDuration }
    }
    
    Text {
        anchors.centerIn: parent
        text: root.icon
        font.family: Commons.Theme.fontIcon
        font.pixelSize: root.iconSize
        color: buttonMouse.containsMouse ? root.hoverIconColor : root.iconColor
        
        Behavior on color {
            ColorAnimation { duration: root.animationDuration }
        }
    }
    
    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

