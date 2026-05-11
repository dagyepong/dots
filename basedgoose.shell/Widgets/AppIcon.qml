import QtQuick 6.10
import "../Commons" as Commons

Rectangle {
    id: root
    
    property string iconSource: ""
    property string fallbackIcon: "󰂞"
    property int iconSize: 18
    property int size: 32
    property color backgroundColor: Commons.Theme.surfaceAccent
    property color iconColor: Commons.Theme.secondary
    
    implicitWidth: root.size
    implicitHeight: root.size
    radius: width / 2
    color: root.backgroundColor
    
    Image {
        id: iconImage
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: {
            if (!root.iconSource) return ""
            if (root.iconSource.startsWith("/") || root.iconSource.startsWith("file://")) {
                return root.iconSource.startsWith("file://") ? root.iconSource : "file://" + root.iconSource
            }
            return "image://icon/" + root.iconSource
        }
        fillMode: Image.PreserveAspectFit
        smooth: true
        cache: true
        asynchronous: true
        visible: root.iconSource && root.iconSource.length > 0
    }
    
    Text {
        anchors.centerIn: parent
        text: root.fallbackIcon
        font.family: Commons.Theme.fontIcon
        font.pixelSize: root.iconSize - 4
        color: root.iconColor
        visible: !root.iconSource || root.iconSource.length === 0 || iconImage.status === Image.Error
        z: iconImage.visible ? -1 : 1
    }
}

