import QtQuick 6.10
import "../Commons" as Commons

Rectangle {
    id: root
    
    property string text: ""
    property color textColor: Commons.Theme.primary
    property color baseColor: Commons.Theme.primaryMuted
    property color hoverColor: Qt.rgba(Commons.Theme.primary.r, Commons.Theme.primary.g, Commons.Theme.primary.b, 0.15)
    property color pressedColor: Qt.rgba(Commons.Theme.primary.r, Commons.Theme.primary.g, Commons.Theme.primary.b, 0.25)
    property int fontSize: 10
    property int horizontalPadding: 16
    property int animationDuration: 150
    
    signal clicked()
    
    implicitHeight: 26
    implicitWidth: actionText.width + root.horizontalPadding
    radius: height / 2
    
    color: actionMouse.pressed ? pressedColor : (actionMouse.containsMouse ? hoverColor : baseColor)
    
    Behavior on color {
        ColorAnimation { duration: root.animationDuration }
    }
    
    Text {
        id: actionText
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: root.fontSize
        font.weight: Font.Medium
        font.family: Commons.Theme.fontUI
        color: root.textColor
    }
    
    MouseArea {
        id: actionMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

