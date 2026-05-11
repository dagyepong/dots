import QtQuick 6.10
import "../Commons" as Commons

Rectangle {
    id: root
    
    property string icon: ""
    property int iconSize: 18
    property color iconColor: Commons.Theme.foreground
    property color baseColor: "transparent"
    property color hoverColor: Commons.Theme.secondaryMuted
    property bool scaleOnInteraction: true
    property real hoverScale: 1.05
    property real pressedScale: 0.85
    property int animationDuration: 100
    property int scaleAnimationDuration: 80
    
    signal clicked()
    
    implicitWidth: 40
    implicitHeight: 40
    radius: Commons.Theme.radius
    color: mouseArea.containsMouse ? hoverColor : baseColor
    scale: scaleOnInteraction ? (mouseArea.pressed ? pressedScale : (mouseArea.containsMouse ? hoverScale : 1.0)) : 1.0
    
    Behavior on color {
        ColorAnimation { duration: root.animationDuration }
    }
    
    Behavior on scale {
        NumberAnimation { duration: root.scaleAnimationDuration }
    }
    
    Text {
        anchors.centerIn: parent
        text: root.icon
        font.family: Commons.Theme.fontIcon
        font.pixelSize: root.iconSize
        color: root.iconColor
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
