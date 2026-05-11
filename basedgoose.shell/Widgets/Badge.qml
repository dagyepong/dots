import QtQuick 6.10
import "../Commons" as Commons

Rectangle {
    id: root
    
    property int count: 0
    property int maxCount: 99
    property string icon: ""
    property color badgeColor: Commons.Theme.secondary
    property color textColor: Commons.Theme.background
    property color borderColor: Commons.Theme.surfaceBase
    property int borderWidth: 2
    property int minWidth: 16
    property int badgeHeight: 16
    property int fontSize: 8
    property int iconSize: 7
    
    readonly property string displayText: root.count > root.maxCount ? (root.maxCount + "+") : root.count.toString()
    
    visible: root.count > 0 || root.icon.length > 0
    width: Math.max(root.minWidth, badgeText.implicitWidth + 6)
    height: root.badgeHeight
    radius: root.badgeHeight / 2
    color: root.badgeColor
    border.width: root.borderWidth
    border.color: root.borderColor
    
    Text {
        id: badgeText
        anchors.centerIn: parent
        text: root.icon.length > 0 ? root.icon : root.displayText
        font.pixelSize: root.icon.length > 0 ? root.iconSize : root.fontSize
        font.weight: root.icon.length > 0 ? Font.Normal : Font.Bold
        font.family: root.icon.length > 0 ? Commons.Theme.fontIcon : Commons.Theme.fontUI
        color: root.textColor
    }
}
