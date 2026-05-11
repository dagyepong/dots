import QtQuick 6.10
import QtQuick.Layouts 6.10
import "../Commons" as Commons

Rectangle {
    id: root
    
    property string icon: ""
    property string text: ""
    property int iconSize: 14
    property int textSize: 12
    property color iconColor: Commons.Theme.foregroundMuted
    property color textColor: Commons.Theme.foregroundMuted
    property color baseColor: "transparent"
    property color hoverColor: Qt.rgba(Commons.Theme.foreground.r, Commons.Theme.foreground.g, Commons.Theme.foreground.b, 0.06)
    property color borderColor: Commons.Theme.surfaceBorder
    property int animationDuration: 150
    property bool showBorder: true
    
    signal clicked()
    
    implicitWidth: 200
    implicitHeight: 38
    radius: Commons.Theme.radiusLg
    color: mouseArea.containsMouse ? hoverColor : baseColor
    border.width: showBorder ? 1 : 0
    border.color: borderColor
    
    Behavior on color {
        ColorAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic }
    }
    
    RowLayout {
        anchors.centerIn: parent
        spacing: 6
        
        Text {
            text: root.icon
            font.family: Commons.Theme.fontIcon
            font.pixelSize: root.iconSize
            color: root.iconColor
            visible: root.icon.length > 0
        }
        
        Text {
            text: root.text
            font.family: Commons.Theme.fontUI
            font.pixelSize: root.textSize
            font.weight: Font.Medium
            color: root.textColor
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
