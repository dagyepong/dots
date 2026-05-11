import QtQuick 6.10
import "../Commons" as Commons

Rectangle {
    id: root
    
    property bool checked: false
    property color checkedColor: Commons.Theme.primary
    property color uncheckedColor: Qt.rgba(Commons.Theme.surfaceText.r, Commons.Theme.surfaceText.g, Commons.Theme.surfaceText.b, 0.15)
    property color thumbColor: "#ffffff"
    property string icon: ""
    property color iconColor: Commons.Theme.primary
    property int animationDuration: 200
    
    signal toggled()
    
    implicitWidth: 48
    implicitHeight: 32
    radius: Commons.Theme.radiusLg
    color: root.checked ? checkedColor : uncheckedColor
    border.width: 1
    border.color: Commons.Theme.surfaceBorder
    
    Behavior on color {
        ColorAnimation { duration: root.animationDuration }
    }
    
    Rectangle {
        width: 24
        height: 24
        radius: Commons.Theme.radiusLg
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 4 : 4
        color: root.thumbColor
        
        Behavior on x {
            NumberAnimation { 
                duration: root.animationDuration
                easing.type: Easing.OutCubic
            }
        }
        
        Behavior on color {
            ColorAnimation { duration: root.animationDuration }
        }
        
        Text {
            anchors.centerIn: parent
            text: root.icon || ""
            font.family: Commons.Theme.fontIcon
            font.pixelSize: 14
            color: root.iconColor
            visible: root.icon.length > 0
        }
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked
            root.toggled()
        }
    }
}

