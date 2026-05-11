import QtQuick 6.10
import "../Commons" as Commons

Rectangle {
    id: root
    
    property string text: ""
    property bool active: false
    property color activeColor: Commons.Theme.primary
    property color inactiveColor: Qt.lighter(Commons.Theme.background, 1.15)
    property color textColor: Commons.Theme.foreground
    property color borderColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.08)
    
    signal clicked()
    
    width: 100
    height: 32
    radius: Commons.Theme.radius
    color: active ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.2) : inactiveColor
    border.width: 1
    border.color: active ? activeColor : borderColor
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
    
    Text {
        anchors.centerIn: parent
        text: root.text
        font.family: Commons.Theme.fontUI
        font.pixelSize: 12
        color: root.textColor
    }
}