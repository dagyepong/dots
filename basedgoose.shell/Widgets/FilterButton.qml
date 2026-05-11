import QtQuick 6.10
import "../Commons" as Commons

Rectangle {
    id: root
    
    property string text: ""
    property string value: ""
    property string currentValue: ""
    property color activeColor: Commons.Theme.primary
    property color inactiveColor: Qt.lighter(Commons.Theme.background, 1.15)
    property color textColor: Commons.Theme.foreground
    property color borderColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.08)
    
    signal clicked(string value)
    
    readonly property bool active: currentValue === value
    
    radius: Commons.Theme.radiusSm
    color: active ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.25) : inactiveColor
    border.width: 1
    border.color: active ? activeColor : borderColor
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked(root.value)
    }
    
    Text {
        anchors.centerIn: parent
        text: root.text
        font.family: Commons.Theme.fontUI
        font.pixelSize: root.width < 50 ? 10 : 11
        color: root.textColor
    }
}