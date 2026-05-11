import QtQuick 6.10
import "../Commons" as Commons

Rectangle {
    id: root
    
    property string icon: ""
    property int iconSize: 14
    property color iconColor: Commons.Theme.foreground
    property color hoverIconColor: Commons.Theme.background
    property color baseColor: Commons.Theme.surfaceAccent
    property color hoverColor: Commons.Theme.primary
    property int animationDuration: 150
    
    signal clicked()
    
    implicitWidth: 28
    implicitHeight: 28
    radius: Commons.Theme.radiusSm
    color: mouseArea.containsMouse ? hoverColor : baseColor
    
    Behavior on color {
        ColorAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic }
    }
    
    Text {
        anchors.centerIn: parent
        text: root.icon
        font.family: Commons.Theme.fontIcon
        font.pixelSize: root.iconSize
        color: mouseArea.containsMouse ? root.hoverIconColor : root.iconColor
        
        Behavior on color {
            ColorAnimation { duration: root.animationDuration }
        }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
